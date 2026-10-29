import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/place_picker.dart';
import '../../../core/widgets/time_entry_sheet.dart';
import '../../errands/presentation/errand_editor.dart';
import '../../places/presentation/search_attribution.dart';
import '../../today/domain/day.dart';
import '../../today/presentation/today_controller.dart';
import '../data/itinerary_repository.dart';
import '../domain/planning_models.dart';
import 'candidate_search_view.dart';
import 'planning_controller.dart';
import 'planning_review.dart';
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
    model = PlanningController(
      widget.initial ?? ref.read(todayProvider),
      ref.read(interpreterProvider),
      ref.read(planningRoadsProvider),
      ref.read(itineraryRepositoryProvider),
      solver: ref.read(planningSolverProvider),
    );
    model.addListener(changed);
    truckConfirmed = widget.history?.lightPickupConfirmed ?? false;
    model.lightPickupConfirmed = truckConfirmed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) model.understand();
    });
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
      model.edit(
        errand.copyWith(
          place: p.label,
          placeIntent: p,
          confirmedFields: {...errand.confirmedFields, 'place'},
        ),
      );
    } else {
      model.setEndpoint(start!, p);
    }
  }

  Future<void> edit(Errand e) async {
    final result = await editErrand(context, e, errands: model.day.errands);
    if (!mounted) return;
    if (result case SavedErrand(:final errand)) {
      model.edit(errand);
    }
  }

  Future<void> date() async {
    final now = DateTime.now();
    final initial = DateTime.parse(model.day.date);
    final value = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime(now.year, now.month, now.day))
          ? now
          : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (value != null && mounted) {
      setState(() {
        model.day = model.day.copyWith(date: calendarDate(value));
        localError = null;
      });
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
  Widget get review => PlanningReview(
    model: model,
    onEdit: edit,
    onLocation: (e) => location(errand: e),
    onChanged: changed,
    tripDetails: ExpansionTile(
      key: const PageStorageKey('planning-trip-details'),
      expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      initiallyExpanded:
          !model.day.fromPlace.hasCoordinates ||
          !model.day.toPlace.hasCoordinates ||
          (model.day.profile == TravelProfile.truck && !truckConfirmed),
      title: const Text('Trip details'),
      subtitle: Text(
        '${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(model.day.date))} · ${model.day.profile.label}\n${formatMinute(model.day.departure)} – ${formatMinute(model.day.deadline)}',
      ),
      children: [
        ListTile(
          leading: const Icon(Icons.calendar_today_outlined),
          title: Text(model.day.date),
          trailing: const Icon(Icons.chevron_right),
          onTap: date,
        ),
        ListTile(
          title: const Text('Departure'),
          trailing: Text(formatMinute(model.day.departure)),
          onTap: () => time(true),
        ),
        ListTile(
          title: const Text('Finish the day by'),
          trailing: Text(formatMinute(model.day.deadline)),
          onTap: () => time(false),
        ),
        ListTile(
          leading: const Icon(Icons.trip_origin),
          title: Text('From: ${model.day.fromPlace.label}'),
          subtitle: Text(
            model.day.fromPlace.hasCoordinates
                ? 'Location ready'
                : 'Choose a map location',
          ),
          onTap: () => location(start: true),
        ),
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text('To: ${model.day.toPlace.label}'),
          subtitle: Text(
            model.day.toPlace.hasCoordinates
                ? 'Location ready'
                : 'Choose a map location',
          ),
          onTap: () => location(start: false),
        ),
        if (model.day.profile == TravelProfile.truck)
          CheckboxListTile(
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
          ),
      ],
    ),
    footer: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (localError != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: Semantics(liveRegion: true, child: notice(localError!)),
            ),
          ),
        button(
          'Next: find suitable places',
          () => attempt(() {
            if (model.day.profile == TravelProfile.bike) {
              throw const PlanningFailure(
                'Bicycle routing and in-app guidance are not qualified for the Philippines yet. Return to Today to choose another travel mode.',
              );
            }
            if (model.day.profile == TravelProfile.truck && !truckConfirmed) {
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
                model.day.errands
                    .firstWhere((e) => e.id == task.errandId)
                    .title,
              ),
              subtitle: Text(
                '${lookup[stop.placeKey]!.place.label}\n${stop.tasks.length > 1 ? 'Shared visit · ' : ''}${lookup[stop.placeKey]!.reason}',
              ),
              trailing: TextButton(
                onPressed: () => alternative(
                  model.day.errands.firstWhere((e) => e.id == task.errandId),
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
              'Arrive ${formatMinute((plan.schedule.stops[i].arrival / 60).ceil())} · Leave ${formatMinute((plan.schedule.stops[i].departure / 60).ceil())}\n${plan.schedule.stops[i].tasks.map((t) => '${model.day.errands.firstWhere((e) => e.id == t.errandId).title}: ${formatMinute((t.start / 60).ceil())}–${formatMinute((t.finish / 60).ceil())}').join('\n')}',
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
        for (final e in plan.schedule.omitted.entries)
          ListTile(
            leading: const Icon(Icons.event_busy_outlined),
            title: Text(
              '${model.day.errands.firstWhere((x) => x.id == e.key).title} · Not included',
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
            PreparationStage.failed => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(Icons.info_outline, size: 36),
                const SizedBox(height: 16),
                Text(
                  model.error ??
                      'Understanding was interrupted. Your errands are kept.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Check for a saved answer first. A new request is sent only when no saved result exists, or when you explicitly retry a failed or interrupted attempt.',
                ),
                button('Check saved understanding', () => model.understand()),
                OutlinedButton(
                  onPressed: () => model.understand(retry: true),
                  child: const Text('Retry Gemini (uses a request)'),
                ),
              ],
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
                          'Finding places for “${unresolved.first.title}” (${model.candidates.length + 1} of ${model.day.errands.length}). Compare a few choices together, or tap one place to fix that choice.',
                        ),
                        Expanded(
                          child: CandidateSearchView(
                            key: ValueKey(unresolved.first.id),
                            query: model.needs[unresolved.first.id]!.query,
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
