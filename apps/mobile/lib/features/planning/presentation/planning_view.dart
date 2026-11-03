import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/place_picker.dart';
import '../../../core/widgets/time_entry_sheet.dart';
import '../../errands/presentation/errand_editor.dart';
import '../../today/domain/day.dart';
import '../../today/presentation/today_controller.dart';
import '../data/itinerary_repository.dart';
import '../data/review_trip_repository.dart';
import '../domain/planning_models.dart';
import '../domain/clarification.dart';
import '../domain/trip_departure.dart';
import '../domain/planning_input_checks.dart';
import '../domain/review_errand_edit.dart';
import 'clarification_sheet.dart';
import '../../places/data/google_pin_cache.dart';
import 'planning_controller.dart';
import 'clarification_coordinator.dart';
import 'understanding_failure_view.dart';
import 'planning_review.dart';
import 'review_feedback.dart';
import 'review_trip_details.dart';
import 'saved_plan_view.dart';
import 'finish_trip.dart';
import '../data/recommendation_discovery.dart';
import '../data/recommendation_draft_repository.dart';
import 'recommendation_page.dart';
import 'place_alternatives_page.dart';
import '../data/reusable_trip_repository.dart';
import 'reusable_trip_controls.dart';
import '../../sharing/share_models.dart';
import '../../sharing/share_repository.dart';
import '../../sharing/share_views.dart';

class PlanningView extends ConsumerStatefulWidget {
  const PlanningView({this.initial, this.history, this.reusable, super.key});
  final DayPlan? initial;
  final AcceptedItinerary? history;
  final ReusableTrip? reusable;
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
  ReviewTrip? pendingReview;
  late DayPlan manualDraft;
  int tripSaveRevision = 0;
  bool tripSavePending = false;
  bool tripSaveFailed = false;
  bool get tripSaveBlocked => tripSavePending || tripSaveFailed;
  bool truckConfirmed = false, saving = false;
  int? selected;
  String? localError;
  Future<void> back() async {
    if (tripSaveBlocked) return;
    if (model.stage == PreparationStage.understanding) {
      Navigator.pop(context);
      return;
    }
    if (model.keepPlanVisible) {
      model.review();
      return;
    }
    if (model.busy) {
      model.cancel();
      return;
    }
    switch (model.stage) {
      case PreparationStage.failed || PreparationStage.review:
        if (await model.saveRecommendationDraft() &&
            mounted &&
            !tripSaveBlocked) {
          Navigator.pop(context);
        }
      case PreparationStage.discovery:
        model.review();
      case PreparationStage.recommendations:
        model.review();
      case PreparationStage.result:
        model.review();
      case PreparationStage.understanding || PreparationStage.calculating:
        model.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    sourceRevision = ref.read(todayProvider).revision;
    sourceDay =
        widget.reusable?.day ?? widget.initial ?? ref.read(todayProvider);
    manualDraft = sourceDay;
    if (widget.initial == null &&
        widget.history == null &&
        widget.reusable == null) {
      tripRepository = ref.read(reviewTripRepositoryProvider);
    }
    model = PlanningController(
      sourceDay,
      ref.read(interpreterProvider),
      ref.read(planningRoadsProvider),
      ref.read(itineraryRepositoryProvider),
      solver: ref.read(planningSolverProvider),
      discovery: ref.read(recommendationDiscoveryProvider),
      drafts: ref.read(recommendationDraftRepositoryProvider),
      resolveGooglePin: ref.read(googlePinCacheProvider).lease,
      clarificationRepository: ref.read(clarificationRepositoryProvider),
      clarificationResolver: ref.read(clarificationResolverProvider),
      locationResolver: ref.read(locationIntentResolverProvider),
    );
    model.addListener(changed);
    truckConfirmed = widget.history?.lightPickupConfirmed ?? false;
    model.lightPickupConfirmed = truckConfirmed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) startUnderstanding();
    });
  }

  Future<void> startUnderstanding() async {
    if (widget.reusable != null) {
      await model.restoreReusable(widget.reusable!);
      return;
    }
    try {
      final saved = await tripRepository?.read(sourceDay);
      if (!mounted) return;
      if (saved != null) {
        manualDraft = saved.apply(sourceDay);
        model.day = saved.applyTripSettings(model.day);
        pendingReview = saved;
      }
    } catch (_) {
      if (!mounted) return;
      tripStorageError =
          'Saved review settings could not be restored. Today’s settings are shown.';
    }
    if (mounted) await understand();
  }

  Future<void> understand({bool retry = false, bool savedOnly = false}) async {
    await model.understand(
      retry: retry,
      savedOnly: savedOnly,
      restoredReview: pendingReview,
    );
    if (mounted && model.interpretation != null) {
      await model.restoreHistoryAnswers(widget.history);
    }
    if (!mounted || model.stage != PreparationStage.review) return;
    pendingReview = null;
    if (mounted && model.interpretation != null) {
      await model.clarifications.resumeSaved(
        model.reviewErrands.map(model.questionContext),
      );
      await model.restoreRecommendationDraft();
      await model.clarifications.resumeLocationAssessments(
        model.reviewErrands.map(model.locationContext),
      );
    }
  }

  Future<void> saveTripSettings() async {
    final repository = tripRepository;
    if (repository == null) return;
    final revision = ++tripSaveRevision;
    setState(() => tripSavePending = true);
    try {
      await repository.save(
        sourceDay,
        manualDraft.copyWith(
          date: model.day.date,
          departure: model.day.departure,
          deadline: model.day.deadline,
        ),
      );
      if (mounted && revision == tripSaveRevision) {
        setState(() {
          tripStorageError = null;
          tripSaveFailed = false;
        });
      }
    } catch (_) {
      if (mounted && revision == tripSaveRevision) {
        setState(() {
          tripSaveFailed = true;
          tripStorageError =
              'Your review changes could not be saved. Retry saving before continuing.';
        });
      }
    } finally {
      if (mounted && revision == tripSaveRevision) {
        setState(() => tripSavePending = false);
      }
    }
  }

  void recordManualEdit(String id, ReviewErrandEdit edit) {
    manualDraft = manualDraft.copyWith(
      errands: [
        for (final e in manualDraft.errands) e.id == id ? edit.apply(e) : e,
      ],
    );
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
      forPlanning: true,
    );
    if (!mounted || p == null) return;
    if (errand != null) {
      await model.confirmPlace(errand, p);
    } else {
      model.setEndpoint(start!, p);
    }
    await model.saveRecommendationDraft();
  }

  Future<void> edit(Errand e) async {
    final result = await editErrand(
      context,
      e,
      errands: model.reviewOrder.items,
      allowRemoval: false,
    );
    if (!mounted) return;
    if (result case SavedErrand(:final errand, :final touchedFields)) {
      final edit = ReviewErrandEdit.between(e, errand, touched: touchedFields);
      recordManualEdit(errand.id, edit);
      final oldPlace = clarificationHash(
        model.reviewInput(e).placeIntent.toJson(),
      );
      final baseline = model.reviewInput(e);
      model.edit(
        edit
            .apply(baseline)
            .copyWith(
              title: errand.title,
              place: errand.place,
              placeIntent: errand.placeIntent,
              confirmedFields: {
                ...baseline.confirmedFields,
                ...errand.confirmedFields.difference(e.confirmedFields),
              },
            ),
      );
      final savingEdits = saveTripSettings();
      if (oldPlace != clarificationHash(errand.placeIntent.toJson())) {
        await model.confirmPlace(errand, errand.placeIntent);
      }
      await savingEdits;
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
      recordManualEdit(
        e.id,
        ReviewErrandEdit.between(
          model.reviewInput(e),
          value,
          touched: {'timing'},
        ),
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
    onReadUpdatedNotes: tripSaveBlocked ? null : model.understand,
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
          storageError: tripStorageError ?? model.recommendationStorageError,
          onDate: date,
          onDeparture: () => time(true),
          onRetrySave: tripStorageError != null
              ? saveTripSettings
              : model.restoreRecommendationDraft,
          issues: model.inputIssues
              .where((i) => i.kind != 'no_active_errands')
              .toList(),
          onIssue: resolveInput,
        ),
        if (model.activeErrands.isEmpty)
          notice('Include at least one errand to plan this day.'),
        button(
          'Build recommendations',
          tripSaveBlocked ||
                  model.interpretationStale ||
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
                  model.buildRecommendations();
                }),
        ),
      ],
    ),
  );

  Future<void> alternative(Errand e) async {
    final choice = await showModalBottomSheet<AlternativeChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (_) => PlaceAlternativesPage(model: model, errandId: e.id),
    );
    if (!mounted || choice == null) return;
    model.selectedErrand = choice.errandId;
    await model.replaceAndRefresh(choice.errandId, choice.place);
  }

  Future<void> manualCandidate(Errand e) async {
    final p = await choosePlace(
      context,
      title: 'Choose place',
      initial: e.title,
      forPlanning: true,
    );
    if (!mounted || p == null) return;
    if (!p.hasCoordinates) {
      setState(() => localError = 'Choose a place with a map pin.');
      return;
    }
    await model.replaceAndRefresh(e.id, p);
  }

  Widget recommendations() => RecommendationPage(
    model: model,
    onChange: alternative,
    onContinue: accept,
    onSave: saveReusable,
    saving: saving,
    actionError: localError,
  );

  Future<void> saveReusable() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const TripNameDialog(),
    );
    if (!mounted || name == null) return;
    setState(() => saving = true);
    try {
      await ref
          .read(reusableTripRepositoryProvider)
          .save(model.reusableTrip(name));
      ref.invalidate(reusableTripsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved in Recurring → Trips')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => localError = e is PlanningFailure
              ? e.message
              : 'The trip could not be saved. Your choices are kept.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String sharingSourceId() {
    try {
      return SharedSnapshot.fromPlan(model).sourceId;
    } catch (_) {
      return '';
    }
  }

  Future<void> accept() async {
    setState(() {
      saving = true;
      localError = null;
    });
    try {
      if (sharingEnabled) {
        try {
          await ShareRepository.shared.prepareReplacement(
            SharedSnapshot.fromPlan(model),
          );
        } catch (_) {
          /* Sharing failure cannot undo a valid local trip. */
          try {
            await ShareRepository.shared.invalidateCandidate(endSharing: true);
          } catch (_) {}
        }
      }
      final accepted = await model.accept(
        ref.read(todayProvider).revision,
        sourceRevision,
        history: widget.history,
      );
      if (sharingEnabled) {
        try {
          await ShareRepository.shared.bind(accepted);
        } catch (_) {
          /* The share sheet reports an unavailable retained route. */
        }
      }
      if (!mounted) return;
      ref.invalidate(savedItineraryProvider);
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<TripExit>(
          builder: (_) => TripView(initial: accepted),
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

  @override
  Widget build(BuildContext context) {
    final title = model.keepPlanVisible
        ? 'Your plan'
        : switch (model.stage) {
            PreparationStage.failed ||
            PreparationStage.understanding => 'Plan my day',
            PreparationStage.review => 'Review errands',
            PreparationStage.discovery => 'Your plan',
            PreparationStage.calculating => 'Building your day',
            PreparationStage.recommendations => 'Your plan',
            PreparationStage.result => 'Your plan',
          };
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
            if (sharingEnabled && title == 'Your plan')
              ShareToolbarAction(
                label: 'Share plan',
                sourceId: sharingSourceId(),
                enabled:
                    model.proposalReady &&
                    !model.busy &&
                    !saving &&
                    !tripSaveBlocked &&
                    model.recommendationStorageError == null &&
                    !model.recommendationSavePending,
                snapshot: () async {
                  final snapshot = SharedSnapshot.fromPlan(model);
                  await ShareRepository.shared.cacheCandidate(snapshot);
                  return snapshot;
                },
              ),
            TextButton(
              onPressed: tripSaveBlocked
                  ? null
                  : () async {
                      if (await model.saveRecommendationDraft() &&
                          context.mounted &&
                          !tripSaveBlocked) {
                        Navigator.pop(context);
                      }
                    },
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
            PreparationStage.calculating when model.keepPlanVisible =>
              recommendations(),
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
            PreparationStage.discovery => recommendations(),
            PreparationStage.recommendations => recommendations(),
            PreparationStage.result => recommendations(),
          },
        ),
      ),
    );
  }
}
