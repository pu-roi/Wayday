import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/place_picker.dart';
import '../../../core/widgets/time_entry_sheet.dart';
import '../../errands/presentation/errand_editor.dart';
import '../../places/presentation/search_attribution.dart';
import '../../today/domain/day.dart';
import '../../today/presentation/today_controller.dart';
import '../data/itinerary_repository.dart';
import '../data/review_trip_repository.dart';
import '../domain/planning_models.dart';
import '../domain/clarification.dart';
import '../domain/trip_departure.dart';
import '../domain/planning_input_checks.dart';
import '../domain/review_timing_edit.dart';
import 'candidate_search_view.dart';
import 'clarification_sheet.dart';
import '../../places/data/google_pin_cache.dart';
import 'planning_controller.dart';
import 'understanding_failure_view.dart';
import 'planning_review.dart';
import 'review_feedback.dart';
import 'review_trip_details.dart';
import 'plan_map.dart';
import 'saved_plan_view.dart';

class PlanningView extends ConsumerStatefulWidget {
  const PlanningView({this.initial, this.history, super.key});
  final DayPlan? initial;
  final AcceptedItinerary? history;
  @override
  ConsumerState<PlanningView> createState() => _PlanningViewState();
}

class _PlanningViewState extends ConsumerState<PlanningView>
    with WidgetsBindingObserver {
  late final PlanningController model;
  late final int sourceRevision;
  late final DayPlan sourceDay;
  ReviewTripRepository? tripRepository;
  String? tripStorageError;
  Map<String, ReviewTimingEdit> pendingTimingEdits = {};
  bool truckConfirmed = false, saving = false;
  int? selected;
  String? localError;
  void back() {
    if (model.stage == PreparationStage.understanding) {
      Navigator.pop(context);
      return;
    }
    if (model.busy) {
      model.cancel();
      return;
    }
    switch (model.stage) {
      case PreparationStage.failed || PreparationStage.review:
        Navigator.pop(context);
      case PreparationStage.discovery:
        model.review();
      case PreparationStage.recommendations:
        setState(() => model.stage = PreparationStage.discovery);
      case PreparationStage.result:
        setState(() => model.stage = PreparationStage.recommendations);
      case PreparationStage.understanding || PreparationStage.calculating:
        model.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    sourceRevision = ref.read(todayProvider).revision;
    sourceDay = widget.initial ?? ref.read(todayProvider);
    if (widget.initial == null && widget.history == null) {
      tripRepository = ref.read(reviewTripRepositoryProvider);
    }
    model = PlanningController(
      sourceDay,
      ref.read(interpreterProvider),
      ref.read(planningRoadsProvider),
      ref.read(itineraryRepositoryProvider),
      solver: ref.read(planningSolverProvider),
      resolveGooglePin: ref.read(googlePinCacheProvider).lease,
      clarificationRepository: ref.read(clarificationRepositoryProvider),
      clarificationResolver: ref.read(clarificationResolverProvider),
    );
    model.addListener(changed);
    truckConfirmed = widget.history?.lightPickupConfirmed ?? false;
    model.lightPickupConfirmed = truckConfirmed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) startUnderstanding();
    });
  }

  Future<void> startUnderstanding() async {
    try {
      final saved = await tripRepository?.read(sourceDay);
      if (!mounted) return;
      if (saved != null) {
        saved.apply(
          model.day,
        ); // Validate references before starting interpretation.
        model.day = saved.applyTripSettings(model.day);
        pendingTimingEdits = saved.timingEdits;
      }
    } catch (_) {
      if (!mounted) return;
      tripStorageError =
          'Saved review settings could not be restored. Today’s settings are shown.';
    }
    if (mounted) await understand();
  }

  Future<void> understand({bool retry = false, bool savedOnly = false}) async {
    await model.understand(retry: retry, savedOnly: savedOnly);
    if (mounted && model.interpretation != null) {
      await model.restoreHistoryAnswers(widget.history);
    }
    if (!mounted || model.stage != PreparationStage.review) return;
    final edits = pendingTimingEdits;
    pendingTimingEdits = {};
    for (final e in model.day.errands) {
      final edit = edits[e.id];
      if (edit != null) model.edit(edit.apply(e));
    }
    if (mounted && model.interpretation != null) {
      await model.clarifications.resumeSaved(
        model.reviewErrands.map(model.questionContext),
      );
    }
  }

  Future<void> saveTripSettings() async {
    try {
      await tripRepository?.save(
        sourceDay,
        model.manualReviewDay.copyWith(
          errands: model.manualReviewDay.errands
              .where(
                (e) => sourceDay.errands.any((source) => source.id == e.id),
              )
              .toList(),
        ),
      );
      if (mounted) setState(() => tripStorageError = null);
    } catch (_) {
      if (mounted) {
        setState(
          () => tripStorageError =
              'Your review changes could not be saved. Retry saving before closing.',
        );
      }
    }
  }

  void changed() {
    if (mounted) setState(() => localError = null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    model.removeListener(changed);
    model.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Keep interpretation in flight; road estimates become stale on background.
      if (model.stage != PreparationStage.understanding) model.cancel();
    }
  }

  void attempt(VoidCallback action) {
    setState(() => localError = null);
    try {
      action();
    } catch (e) {
      setState(() => localError = e.toString());
    }
  }

  Future<void> location({Errand? errand, bool? start}) async {
    final old =
        errand?.placeIntent ??
        (start == true ? model.day.fromPlace : model.day.toPlace);
    final p = await choosePlace(
      context,
      title: errand == null
          ? (start == true
                ? 'Where will you start?'
                : 'Where will your day end?')
          : 'Location for ${errand.title}',
      initial: old.label,
      initialPlace: old,
    );
    if (!mounted || p == null) return;
    if (errand != null) {
      await model.confirmPlace(errand, p);
    } else {
      model.setEndpoint(start!, p);
    }
  }

  Future<void> edit(Errand e) async {
    final result = await editErrand(
      context,
      e,
      errands: model.reviewOrder.items,
      allowRemoval: false,
    );
    if (!mounted) return;
    if (result case SavedErrand(:final errand)) {
      final oldPlace = clarificationHash(
        model.reviewInput(e).placeIntent.toJson(),
      );
      model.edit(errand);
      if (oldPlace != clarificationHash(errand.placeIntent.toJson())) {
        await model.confirmPlace(errand, errand.placeIntent);
      }
      await saveTripSettings();
    }
  }

  Future<void> date() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(model.day.date) ?? now;
    final first = DateTime(now.year, now.month, now.day);
    final last = DateTime(now.year + 1, 12, 31);
    final value = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first)
          ? first
          : (initial.isAfter(last) ? last : initial),
      firstDate: first,
      lastDate: last,
    );
    if (value != null && mounted) {
      setState(() {
        model.day = model.day.copyWith(date: calendarDate(value));
        localError = null;
      });
      await saveTripSettings();
    }
  }

  void resolveInput(PlanningInputIssue issue) {
    switch (issue.field) {
      case PlanningInputField.date:
        date();
      case PlanningInputField.departure:
        time(true);
      case PlanningInputField.deadline:
        time(false);
      case PlanningInputField.errand:
        edit(issue.errand!);
      case PlanningInputField.input:
        back();
    }
  }

  Future<void> time(bool departure) async {
    final value = await chooseTime(
      context,
      title: departure ? 'Leave at' : 'Finish the day by',
      initialMinute: departure ? model.day.departure : model.day.deadline,
    );
    if (value != null && mounted) {
      setState(() {
        model.day = departure
            ? model.day.copyWith(departure: value)
            : model.day.copyWith(deadline: value);
        localError = null;
      });
      await saveTripSettings();
    }
  }

  Widget button(String text, VoidCallback? action) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    child: SizedBox(
      width: double.infinity,
      child: FilledButton(onPressed: action, child: Text(text)),
    ),
  );
  Widget notice(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Text(text),
  );
  Future<void> clarify(Errand e, {bool deferOnly = false}) async {
    final action = await showClarificationSheet(
      context,
      model,
      e,
      deferOnly: deferOnly,
    );
    if (!mounted) return;
    if (action == 'location') {
      final scope =
          model.effectiveNeed(e)?.questionKind ??
          model.answerFor(e)?.resolution?.kind;
      await location(errand: e);
      if (mounted) {
        final current = model.reviewOrder.items.firstWhere((x) => x.id == e.id);
        if (current.placeIntent.hasCoordinates && scope == 'location') {
          await model.clarifications.applyStructured(
            model.questionContext(current),
            const ClarificationResolution(
              outcome: 'resolved',
              kind: 'location',
              summary: 'Location selected',
            ),
            'Selected a location',
          );
        }
      }
    }
    if (action == 'time') {
      if (!mounted) return;
      final minute = await chooseTime(
        context,
        title: 'Time for ${e.title}',
        initialMinute: e.minute ?? model.day.departure,
      );
      if (!mounted || minute == null) return;
      final value = model
          .reviewInput(e)
          .copyWith(
            timing: e.timing == TimingRule.anytime ? TimingRule.at : e.timing,
            minute: minute,
            confirmedFields: {...e.confirmedFields, 'timing'},
          );
      model.edit(value);
      await saveTripSettings();
      await model.clarifications.applyStructured(
        model.questionContext(value),
        ClarificationResolution(
          outcome: 'resolved',
          kind: 'timing',
          summary: '${formatMinute(minute)} confirmed',
        ),
        'Selected a time',
      );
    }
  }

  Widget get review => PlanningReview(
    model: model,
    onEdit: edit,
    onClarify: clarify,
    onDefer: (e) => clarify(e, deferOnly: true),
    onLocation: (e) => location(errand: e),
    onChanged: changed,
    tripDetails: ReviewTripDetails(
      day: model.day,
      initiallyExpanded:
          tripDepartureHasPassed(model.day) ||
          !model.day.fromPlace.hasCoordinates ||
          !model.day.toPlace.hasCoordinates ||
          (model.day.profile == TravelProfile.truck && !truckConfirmed),
      onDate: date,
      onDeparture: () => time(true),
      onDeadline: () => time(false),
      onFrom: () => location(start: true),
      onTo: () => location(start: false),
      vehicleConfirmation: model.day.profile == TravelProfile.truck
          ? CheckboxListTile(
              title: const Text('I am using a compatible light pickup'),
              subtitle: const Text(
                'Ordinary driving estimates. No truck restriction, clearance, weight or access verification. Heavy delivery vehicles are unavailable.',
              ),
              value: truckConfirmed,
              onChanged: (v) => setState(() {
                truckConfirmed = v == true;
                model.lightPickupConfirmed = truckConfirmed;
                localError = null;
              }),
            )
          : null,
    ),
    footer: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReviewFeedback(
          day: model.day,
          error: localError,
          orderIssue: model.reviewOrder.issue,
          storageError: tripStorageError,
          onDate: date,
          onDeparture: () => time(true),
          onRetrySave: saveTripSettings,
          issues: model.inputIssues
              .where((i) => i.kind != 'no_active_errands')
              .toList(),
          onIssue: resolveInput,
        ),
        if (model.activeErrands.isEmpty)
          notice('Include at least one errand to plan this day.'),
        button(
          'Next: find suitable places',
          tripDepartureHasPassed(model.day) ||
                  model.reviewOrder.issue != null ||
                  model.inputIssues.isNotEmpty ||
                  model.clarifications.storageError != null
              ? null
              : () => attempt(() {
                  if (model.day.profile == TravelProfile.bike) {
                    throw const PlanningFailure(
                      'Bicycle routing and in-app guidance are not qualified for the Philippines yet. Return to Today to choose another travel mode.',
                    );
                  }
                  if (model.day.profile == TravelProfile.truck &&
                      !truckConfirmed) {
                    throw const PlanningFailure(
                      'Confirm a compatible light pickup. Heavy delivery vehicles are unavailable.',
                    );
                  }
                  if (model.day.departure >= model.day.deadline) {
                    throw const PlanningFailure(
                      'The final deadline must follow departure.',
                    );
                  }
                  model.applyReview();
                }),
        ),
      ],
    ),
  );

  Future<void> alternative(Errand e) async {
    final place = await choosePlace(
      context,
      title: 'Change place for ${e.title}',
      initial: e.title,
    );
    if (!mounted || place == null) return;
    if (!place.hasCoordinates) {
      setState(
        () => localError = 'Choose a map location for this alternative.',
      );
      return;
    }
    model.overridePlace(e.id, place);
    await model.calculate();
  }

  Future<void> manualCandidate(Errand e) async {
    final p = await choosePlace(
      context,
      title: 'Location for ${e.title}',
      initial: e.title,
    );
    if (!mounted || p == null) return;
    if (!p.hasCoordinates) {
      setState(() => localError = 'Choose a place with a map pin.');
      return;
    }
    model.overridePlace(e.id, p);
  }

  Widget recommendations() {
    final plan = model.result!;
    final lookup = {for (final p in model.points) p.key: p};
    return ListView(
      children: [
        notice(
          'Wayday compared the available places and road times. Check each chosen branch; stock, menu items and opening hours are unconfirmed.',
        ),
        for (final stop in plan.schedule.stops) ...[
          for (final task in stop.tasks)
            ListTile(
              title: Text(
                model.reviewOrder.items
                    .firstWhere((e) => e.id == task.errandId)
                    .title,
              ),
              subtitle: Text(
                '${lookup[stop.placeKey]!.place.label}\n${stop.tasks.length > 1 ? 'Shared visit · ' : ''}${lookup[stop.placeKey]!.reason}',
              ),
              trailing: TextButton(
                onPressed: () => alternative(
                  model.reviewOrder.items.firstWhere(
                    (e) => e.id == task.errandId,
                  ),
                ),
                child: const Text('Change'),
              ),
            ),
          if (lookup[stop.placeKey]!.place.isGoogle)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Selected place')),
                      body: CandidateSearchView(
                        query: lookup[stop.placeKey]!.place.label,
                        anchor: model.day.fromPlace,
                        limit: model.candidateLimit,
                        reference: lookup[stop.placeKey]!.place,
                        onFound: (_) {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                ),
                child: const Text('View Google place details'),
              ),
            ),
        ],
        if (localError != null) notice(localError!),
        button('Next: see my day', model.showResult),
      ],
    );
  }

  Future<void> accept() async {
    setState(() {
      saving = true;
      localError = null;
    });
    try {
      final accepted = await model.accept(
        ref.read(todayProvider).revision,
        sourceRevision,
        history: widget.history,
      );
      if (!mounted) return;
      ref.invalidate(savedItineraryProvider);
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SavedPlanView(initial: accepted),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => localError = e is PlanningFailure
              ? e.message
              : 'Your plan could not be saved. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget result() {
    final plan = model.result!;
    final lookup = {for (final p in model.points) p.key: p};
    final places = plan.schedule.stops
        .map((s) => lookup[s.placeKey]!.place)
        .toList();
    return ListView(
      children: [
        SizedBox(
          height: 300,
          child: PlanMap(
            places: [...places, model.day.toPlace],
            geometry: plan.geometry,
            selected: selected,
            onSelect: (i) => setState(() => selected = i),
          ),
        ),
        notice(
          '${model.day.date} · ${model.day.profile.label}\nEstimated road travel: ${(plan.schedule.travelSeconds / 60).ceil()} min. Hours and item availability need checking. Includes a 5-minute buffer per visit.',
        ),
        if (model.day.profile == TravelProfile.truck)
          notice(
            'Light pickup · ordinary driving estimate. Truck restrictions and clearance are not verified.',
          ),
        if (plan.fallback)
          notice(
            'Google used fallback estimates for part of this route. Traffic information may be limited.',
          ),
        for (final warning in plan.warnings) notice(warning),
        if (plan.schedule.timeLimited)
          notice(
            'A feasible plan was found within the calculation limit. Other plans may be better.',
          ),
        for (var i = 0; i < plan.schedule.stops.length; i++)
          ListTile(
            selected: selected == i,
            leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
            title: Text(places[i].label),
            subtitle: Text(
              'Arrive ${formatMinute((plan.schedule.stops[i].arrival / 60).ceil())} · Leave ${formatMinute((plan.schedule.stops[i].departure / 60).ceil())}\n${plan.schedule.stops[i].tasks.map((t) => '${model.reviewOrder.items.firstWhere((e) => e.id == t.errandId).title}: ${formatMinute((t.start / 60).ceil())}–${formatMinute((t.finish / 60).ceil())}').join('\n')}',
            ),
            onTap: () => setState(() => selected = i),
          ),
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: Text(model.day.toPlace.label),
          subtitle: Text(
            'Estimated arrival ${formatMinute((plan.schedule.endArrival / 60).ceil())} · Deadline ${formatMinute(model.day.deadline)}',
          ),
        ),
        for (final e in model.deferred.entries)
          ListTile(
            leading: const Icon(Icons.pause_circle_outline),
            title: Text(
              '${model.reviewOrder.items.firstWhere((x) => x.id == e.key).title} · Left out',
            ),
            subtitle: Text(e.value),
          ),
        for (final e in plan.schedule.omitted.entries)
          ListTile(
            leading: const Icon(Icons.event_busy_outlined),
            title: Text(
              '${model.reviewOrder.items.firstWhere((x) => x.id == e.key).title} · Not included',
            ),
            subtitle: Text(e.value),
          ),
        SearchAttribution(
          credits: [
            for (final p in [...places, model.day.fromPlace, model.day.toPlace])
              ...p.attributions.where((credit) => credit != 'Google Maps'),
          ],
        ),
        if (localError != null) notice(localError!),
        button(saving ? 'Saving…' : 'Use this plan', saving ? null : accept),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (model.stage) {
      PreparationStage.failed ||
      PreparationStage.understanding => 'Plan my day',
      PreparationStage.review => 'Review errands',
      PreparationStage.discovery => 'Find suitable places',
      PreparationStage.calculating => 'Building your day',
      PreparationStage.recommendations => 'Recommended places',
      PreparationStage.result => 'Your day',
    };
    final unresolved = model.unresolved;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: back,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(title),
          actions: [
            if (model.interpretation != null &&
                !model.busy &&
                model.stage != PreparationStage.review)
              TextButton(onPressed: model.review, child: const Text('Review')),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
        body: SafeArea(
          child: switch (model.stage) {
            PreparationStage.failed => UnderstandingFailureView(
              failure: model.understandingFailure,
              error: model.error,
              onSaved: () => understand(savedOnly: true),
              onRetry: () => understand(retry: true),
            ),
            PreparationStage.understanding ||
            PreparationStage.calculating => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      model.stage == PreparationStage.understanding
                          ? 'Understanding your errands…'
                          : model.progress,
                    ),
                    TextButton(
                      onPressed: () {
                        model.cancel();
                        Navigator.pop(context);
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
            PreparationStage.review => review,
            PreparationStage.discovery =>
              model.error != null
                  ? ListView(
                      children: [
                        notice(model.error!),
                        button('Review errands', model.review),
                        button('Retry calculation', model.calculate),
                      ],
                    )
                  : unresolved.isEmpty
                  ? ListView(
                      children: [
                        notice(
                          'All errands have candidate locations. Next, Wayday will compare branches, stop order and road times.',
                        ),
                        button(
                          model.result == null
                              ? 'Build my day'
                              : 'Review recommendation',
                          model.result == null
                              ? model.calculate
                              : () {
                                  setState(
                                    () => model.stage =
                                        PreparationStage.recommendations,
                                  );
                                },
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        notice(
                          'Finding places for “${unresolved.first.title}” (${model.candidates.length + 1} of ${model.activeErrands.length}). Compare a few choices together, or tap one place to fix that choice.',
                        ),
                        Expanded(
                          child: CandidateSearchView(
                            key: ValueKey(unresolved.first.id),
                            query: model.effectiveNeed(unresolved.first)!.query,
                            anchor: model.day.fromPlace,
                            onMap: () => manualCandidate(unresolved.first),
                            onFound: (values) =>
                                model.found(unresolved.first.id, values),
                          ),
                        ),
                        if (unresolved.first.optional)
                          TextButton(
                            onPressed: () =>
                                model.found(unresolved.first.id, []),
                            child: const Text('Leave this optional errand out'),
                          ),
                      ],
                    ),
            PreparationStage.recommendations => recommendations(),
            PreparationStage.result => result(),
          },
        ),
      ),
    );
  }
}
