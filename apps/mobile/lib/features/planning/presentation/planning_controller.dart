import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/data/local_repositories.dart';
import '../../errands/domain/errand_order.dart';
import '../../places/data/google_pin_cache.dart';
import '../../places/domain/place_intent.dart';
import '../../today/domain/day.dart';
import '../data/gemini_interpreter.dart';
import '../data/clarification_repository.dart';
import '../data/clarification_resolver.dart';
import '../domain/clarification.dart';
import 'clarification_coordinator.dart';
import '../data/itinerary_repository.dart';
import '../data/review_trip_repository.dart';
import '../data/planning_budget.dart';
import '../data/road_estimates.dart';
import '../domain/day_scheduler.dart';
import '../domain/planning_models.dart';
import '../domain/errand_location_review.dart';
import '../domain/trip_departure.dart';
import '../domain/planning_input_checks.dart';

final planningBudgetProvider = Provider((ref) => PlanningBudget());
final reviewTripRepositoryProvider = Provider<ReviewTripRepository>((ref) {
  final local = ref.watch(localRepositoriesProvider);
  return local == null
      ? MemoryReviewTripRepository()
      : SqliteReviewTripRepository(local.database);
});
final clarificationRepositoryProvider = Provider<ClarificationRepository>((
  ref,
) {
  final local = ref.watch(localRepositoriesProvider);
  return local == null
      ? MemoryClarificationRepository()
      : SqliteClarificationRepository(local.database);
});
final clarificationResolverProvider = Provider<ClarificationResolver>(
  (ref) => GeminiClarificationResolver(),
);
typedef PlanningSolver =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> input);
Future<Map<String, dynamic>> solveInWorker(Map<String, dynamic> input) =>
    compute(solveDay, input);
final planningSolverProvider = Provider<PlanningSolver>((ref) => solveInWorker);
final itineraryRepositoryProvider = Provider<ItineraryRepository>((ref) {
  final local = ref.watch(localRepositoriesProvider);
  return local == null
      ? MemoryItineraryRepository()
      : SqliteItineraryRepository(
          local.database,
          ref.read(googlePinCacheProvider).lease,
        );
});
final interpreterProvider = Provider<ErrandInterpreter>(
  (ref) => GeminiInterpreter(),
);
final planningRoadsProvider = Provider((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return PlanningRoads(client, ref.read(planningBudgetProvider));
});

enum PreparationStage {
  failed,
  understanding,
  review,
  discovery,
  calculating,
  recommendations,
  result,
}

class PlanningController extends ChangeNotifier {
  PlanningController(
    this.day,
    this.interpreter,
    this.roads,
    this.repository, {
    this.solver = solveInWorker,
    ClarificationRepository? clarificationRepository,
    ClarificationResolver? clarificationResolver,
    this.resolveGooglePin,
  }) {
    _reviewItems.addEntries(day.errands.map((e) => MapEntry(e.id, e)));
    _sourcePlaces.addAll({
      for (final e in day.errands)
        e.id: clarificationHash(e.placeIntent.toJson()),
    });
    _originalIds.addAll(_reviewItems.keys);
    clarifications = ClarificationCoordinator(
      clarificationRepository ?? MemoryClarificationRepository(),
      clarificationResolver ?? GeminiClarificationResolver(),
    );
    clarifications.addListener(_clarificationChanged);
  }
  late final ClarificationCoordinator clarifications;
  Map<String, String> _answerEffects = {};
  final _reviewItems = <String, Errand>{};
  final _originalIds = <String>{};
  final _sourcePlaces = <String, String>{};
  final GooglePinResolver? resolveGooglePin;

  /// The user's draft, before selected suggestions are applied for calculation.
  Errand reviewInput(Errand errand) {
    if (_reviewItems.containsKey(errand.id)) return _reviewItems[errand.id]!;
    final extra = interpretation?.additions
        .where((n) => n.id == errand.id)
        .firstOrNull;
    return extra?.apply(Errand(id: errand.id, title: extra.proposedTitle!)) ??
        errand;
  }

  DayPlan get manualReviewDay =>
      day.copyWith(errands: _reviewItems.values.toList());

  /// Preview selected proposals independently of date/location validation.
  /// The same projection is committed by applyReview; the baseline stays intact.
  Errand _baseReview(Errand e) =>
      approved.contains(e.id) ? needs[e.id]!.apply(e) : e;
  ClarificationContext questionContext(Errand e) =>
      ClarificationContext.create(_baseReview(reviewInput(e)), needs[e.id]!, [
        for (final x in _reviewItems.values)
          if (_originalIds.contains(x.id) || additions.contains(x.id))
            _baseReview(x),
        for (final n in interpretation?.additions ?? <ErrandNeed>[])
          if (additions.contains(n.id) && !_reviewItems.containsKey(n.id))
            n.apply(Errand(id: n.id, title: n.proposedTitle!)),
      ]);
  ClarificationRecord? answerFor(Errand e) =>
      needs[e.id] == null ? null : clarifications.record(questionContext(e));
  ErrandNeed? effectiveNeed(Errand e) {
    final n = needs[e.id], r = answerFor(e);
    if (n == null) return null;
    if (r?.applied == true) {
      final refined = r!.resolution!.refine(n),
          preference = reviewInput(e).placeIntent;
      if (preference.kind == PlaceKind.search &&
          (preference.label.trim().isNotEmpty ||
              preference.brand?.trim().isNotEmpty == true)) {
        return refined.copyWith(
          query: [
            if (preference.brand?.isNotEmpty == true) preference.brand!,
            preference.label,
          ].join(' ').trim(),
        );
      }
      return refined;
    }
    if (r?.resolution?.kind == 'location') {
      return n.copyWith(requiresSpecificLocation: true);
    }
    return n;
  }

  bool questionResolved(Errand e) {
    final kind = needs[e.id]?.questionKind ?? answerFor(e)?.resolution?.kind;
    if (kind == 'location' && e.placeIntent.hasCoordinates) return true;
    return answerFor(e)?.applied == true;
  }

  String? questionFor(Errand e) {
    final q = outstandingQuestion(
      effectiveNeed(e),
      clarified: questionResolved(e),
    );
    return q != null && durationOnlyQuestion(q) ? null : q;
  }

  bool questionBlocks(Errand e) {
    final n = effectiveNeed(e), r = answerFor(e);
    if (n?.questionRequired != false &&
        r?.applied == true &&
        r!.proposesRules &&
        !r.rulesApproved &&
        {'timing', 'dependency'}.contains(n?.questionKind)) {
      return true;
    }
    return questionFor(e) != null && n?.questionRequired != false;
  }

  Map<String, String> get deferred => {
    for (final e in clarifications.deferred(day.date).entries)
      if (_originalIds.contains(e.key) || additions.contains(e.key))
        e.key: e.value,
  };
  ErrandOrder get reviewOrder => ErrandOrder.reconcile([
    for (final e in _reviewItems.values)
      if (_originalIds.contains(e.id) || additions.contains(e.id))
        _applyAnswerRules(_baseReview(e)),
    for (final n in interpretation?.additions ?? <ErrandNeed>[])
      if (additions.contains(n.id) && !_reviewItems.containsKey(n.id))
        _applyAnswerRules(
          n.apply(Errand(id: n.id, title: n.proposedTitle!, place: '')),
        ),
  ]);
  Errand _applyAnswerRules(Errand e) {
    final r = answerFor(e);
    return r?.applied == true && r!.proposesRules && r.rulesApproved
        ? r.resolution!.applyRules(e)
        : e;
  }

  List<Errand> get reviewErrands => reviewOrder.items;
  List<Errand> get activeErrands =>
      reviewOrder.items.where((e) => !deferred.containsKey(e.id)).toList();
  List<PlanningInputIssue> get inputIssues => activeErrands.isEmpty
      ? [
          const PlanningInputIssue(
            PlanningInputField.input,
            'Include at least one errand to plan this day.',
            kind: 'no_active_errands',
          ),
        ]
      : planningInputChecks(day, activeErrands);
  void _clarificationChanged() {
    final effects = <String, String>{
      for (final e in reviewErrands)
        e.id: clarificationHash({
          'answer': answerFor(e)?.applied == true
              ? answerFor(e)!.resolution!.toJson()
              : null,
          'rules': answerFor(e)?.rulesApproved ?? false,
          'deferred': deferred[e.id],
        }),
    };
    var changed = false;
    for (final id in {..._answerEffects.keys, ...effects.keys}) {
      if (_answerEffects[id] != effects[id]) {
        if (!overrides.containsKey(id)) candidates.remove(id);
        result = null;
        changed = true;
      }
    }
    if (changed &&
        {
          PreparationStage.calculating,
          PreparationStage.recommendations,
          PreparationStage.result,
          PreparationStage.discovery,
        }.contains(stage)) {
      _epoch++;
      stage = PreparationStage.review;
    }
    if (changed) error = null;
    _answerEffects = effects;
    _emit();
  }

  DayPlan day;
  final ErrandInterpreter interpreter;
  final PlanningRoads roads;
  final ItineraryRepository repository;
  final PlanningSolver solver;
  PreparationStage stage = PreparationStage.understanding;
  Interpretation? interpretation;
  bool interpretationStale = false;
  final needs = <String, ErrandNeed>{};
  final candidates = <String, List<PlanCandidate>>{};
  final overrides = <String, String>{};
  final approved = <String>{};
  final additions = <String>{};
  RefinedPlan? result;
  String? error;
  PlanningFailure? understandingFailure;
  bool lightPickupConfirmed = false;
  String progress = '';
  int _epoch = 0;
  bool _closed = false;
  void _emit() {
    if (!_closed) notifyListeners();
  }

  void cancel() {
    _epoch++;
    result = null;
    if (stage != PreparationStage.discovery) {
      stage = interpretation == null
          ? PreparationStage.failed
          : PreparationStage.review;
    }
    _emit();
  }

  bool get busy =>
      stage == PreparationStage.understanding ||
      stage == PreparationStage.calculating;
  @override
  void dispose() {
    _closed = true;
    clarifications.removeListener(_clarificationChanged);
    clarifications.dispose();
    _epoch++;
    super.dispose();
  }

  Future<void> understand({bool retry = false, bool savedOnly = false}) async {
    final epoch = ++_epoch;
    error = null;
    understandingFailure = null;
    stage = PreparationStage.understanding;
    _emit();
    try {
      final fields = errandFieldChecks(day.errands);
      if (fields.isNotEmpty) {
        throw PlanningFailure(fields.first.message, kind: fields.first.kind);
      }
      final graphIssue = ErrandOrder.reconcile(day.errands).issue;
      if (graphIssue != null) {
        throw PlanningFailure(graphIssue, kind: 'invalid_input');
      }
      if (interpretationStale) day = day.copyWith(errands: reviewOrder.items);
      _sourcePlaces
        ..clear()
        ..addAll({
          for (final e in day.errands)
            e.id: clarificationHash(e.placeIntent.toJson()),
        });
      await clarifications.bind(clarificationSourceKey(day));
      final service = interpreter;
      if (savedOnly && service is! SavedErrandInterpreter) {
        throw const PlanningFailure(
          'Saved understanding is unavailable.',
          kind: 'cache_miss',
        );
      }
      final value = await (savedOnly
          ? (service as SavedErrandInterpreter).saved(day)
          : retry && service is ConfirmedRetryInterpreter
          ? service.retry(day)
          : service.interpret(day));
      if (_closed || epoch != _epoch) return;
      interpretation = value;
      interpretationStale = false;
      _reviewItems
        ..clear()
        ..addEntries(day.errands.map((e) => MapEntry(e.id, e)));
      _originalIds
        ..clear()
        ..addAll(_reviewItems.keys);
      approved.clear();
      additions.clear();
      candidates.clear();
      overrides.clear();
      result = null;
      needs
        ..clear()
        ..addEntries(
          [...value.needs, ...value.additions].map((e) => MapEntry(e.id, e)),
        );
      await _restorePlaces();
      stage = PreparationStage.review;
      await clarifications.resumeSaved(
        reviewErrands.where((e) => needs[e.id] != null).map(questionContext),
      );
    } catch (e) {
      if (_closed || epoch != _epoch) return;
      understandingFailure = e is PlanningFailure ? e : null;
      error = e is PlanningFailure
          ? e.message
          : 'Understanding is unavailable. Your text is kept; try again.';
      stage = PreparationStage.failed;
    }
    _emit();
  }

  Errand _withSavedPlace(Errand e) {
    final choice = clarifications.session.places[e.id];
    if (choice == null ||
        choice['source'] != _sourcePlaces[e.id] ||
        choice['text'] !=
            clarificationHash({'title': e.title, 'notes': e.notes})) {
      return e;
    }
    final place = PlaceIntent.fromJson(
      Map<String, dynamic>.from(choice['place'] as Map),
      resolveGooglePin: resolveGooglePin,
    );
    return e.copyWith(
      place: place.label,
      placeIntent: place,
      confirmedFields: {...e.confirmedFields, 'place'},
    );
  }

  Future<void> _restorePlaces() async {
    try {
      for (final e in _reviewItems.values.toList()) {
        _reviewItems[e.id] = _withSavedPlace(e);
      }
      day = day.copyWith(
        errands: [for (final e in day.errands) _reviewItems[e.id] ?? e],
      );
    } catch (_) {
      clarifications.storageError =
          'A saved location choice could not be restored. Choose it again.';
    }
  }

  void addAddition(ErrandNeed need) {
    final e = need.apply(Errand(id: need.id, title: need.proposedTitle!));
    _sourcePlaces.putIfAbsent(
      e.id,
      () => clarificationHash(e.placeIntent.toJson()),
    );
    additions.add(e.id);
    try {
      _reviewItems[e.id] = _withSavedPlace(e);
    } catch (_) {
      clarifications.storageError =
          'A saved location choice could not be restored. Choose it again.';
    }
    _emit();
  }

  Future<void> confirmPlace(Errand e, PlaceIntent place) async {
    final original = reviewInput(e);
    _sourcePlaces.putIfAbsent(
      e.id,
      () => clarificationHash(original.placeIntent.toJson()),
    );
    edit(
      original.copyWith(
        place: place.label,
        placeIntent: place,
        confirmedFields: {...original.confirmedFields, 'place'},
      ),
    );
    final previous =
        clarifications.session.places[e.id]?['revision'] as int? ?? 0;
    final now = DateTime.now().microsecondsSinceEpoch;
    clarifications.session.places[e.id] = {
      'source': _sourcePlaces[e.id],
      'text': clarificationHash({'title': e.title, 'notes': e.notes}),
      'place': place.toJson(),
      'revision': now > previous ? now : previous + 1,
    };
    try {
      await clarifications.retrySave();
    } catch (_) {}
  }

  Future<void> restoreHistoryAnswers(AcceptedItinerary? history) async {
    if (history == null) return;
    final session = clarifications.session;
    for (final payload in history.clarifications.values) {
      final r = ClarificationRecord.fromJson(payload);
      if (_reviewItems.containsKey(r.context.id)) {
        session.records.putIfAbsent(r.context.key, () => r);
      }
    }
    if (history.day.date == day.date &&
        !session.deferrals.containsKey(day.date)) {
      session.deferrals[day.date] = {
        for (final e in history.deferred.entries)
          if (_reviewItems.containsKey(e.key)) e.key: e.value,
      };
      session.deferralRevisions[day.date] =
          DateTime.now().microsecondsSinceEpoch;
    }
    try {
      await clarifications.retrySave();
    } catch (_) {}
    _emit();
  }

  void edit(Errand value) {
    final previous = reviewInput(value);
    if (previous.title != value.title || previous.notes != value.notes) {
      interpretationStale = true;
    }
    _reviewItems[value.id] = value;
    day = day.copyWith(
      errands: ErrandOrder.reconcile([
        for (final e in day.errands) e.id == value.id ? value : e,
      ]).items,
    );
    candidates.remove(value.id);
    overrides.remove(value.id);
    result = null;
    _emit();
  }

  void removeAddition(String id) {
    additions.remove(id);
    approved.remove(id);
    _reviewItems.remove(id);
    day = day.copyWith(errands: day.errands.where((e) => e.id != id).toList());
    candidates.remove(id);
    overrides.remove(id);
    result = null;
    _emit();
  }

  void setEndpoint(bool start, PlaceIntent place) {
    day = start
        ? day.copyWith(from: place.label, fromPlace: place)
        : day.copyWith(to: place.label, toPlace: place);
    if (start) {
      candidates.removeWhere(
        (id, _) =>
            !overrides.containsKey(id) &&
            day.errands.any((e) => e.id == id && !e.placeIntent.hasCoordinates),
      );
    }
    result = null;
    _emit();
  }

  void applyReview() {
    if (interpretationStale) {
      throw const PlanningFailure(
        'Titles or notes changed. Read the updated notes with Gemini before finding places.',
      );
    }
    if (day.profile == TravelProfile.bike) {
      throw const PlanningFailure(
        'Bicycle routing and guidance have not been qualified for the Philippines.',
        kind: 'unsupported_profile',
      );
    }
    if (day.profile == TravelProfile.truck && !lightPickupConfirmed) {
      throw const PlanningFailure(
        'Identify a compatible light pickup before using ordinary driving estimates.',
        kind: 'unsupported_profile',
      );
    }
    final proposed = interpretation;
    if (proposed == null) {
      throw const PlanningFailure('Understand your errands first.');
    }
    for (final n in proposed.additions) {
      if (additions.contains(n.id)) needs[n.id] = n;
    }
    final order = reviewOrder;
    if (order.issue != null) {
      throw PlanningFailure(order.issue!, kind: 'invalid_input');
    }
    final reviewedDay = day.copyWith(errands: activeErrands);
    final issues = inputIssues;
    if (issues.isNotEmpty) {
      throw PlanningFailure(issues.first.message, kind: issues.first.kind);
    }
    if (tripDepartureHasPassed(day)) {
      throw const PlanningFailure(
        'The departure is in the past. Choose a new date and departure time.',
        kind: 'invalid_input',
      );
    }
    if (!day.fromPlace.hasCoordinates || !day.toPlace.hasCoordinates) {
      throw const PlanningFailure(
        'Choose a map location for both From and To.',
        kind: 'missing_location',
      );
    }
    for (final e in reviewedDay.errands) {
      final need = effectiveNeed(e)!;
      final question = questionFor(e);
      if (questionBlocks(e)) {
        throw PlanningFailure(
          question == null
              ? 'Review the proposed rules for “${e.title}” before continuing.'
              : 'Please resolve “${e.title}”: $question',
          kind: 'clarification',
        );
      }
      if (needsActualLocation(e, need)) {
        throw PlanningFailure(
          'Choose the actual location for “${e.title}”.',
          kind: 'missing_location',
        );
      }
      if (e.placeIntent.hasCoordinates && !overrides.containsKey(e.id)) {
        final place = e.placeIntent;
        candidates[e.id] = [
          PlanCandidate(
            key: placeKey(place),
            place: place,
            errandIds: {e.id},
            reason: 'Your selected location.',
          ),
        ];
      }
    }
    day = day.copyWith(errands: order.items);
    result = null;
    candidates.removeWhere((id, _) => !activeErrands.any((e) => e.id == id));
    error = null;
    stage = PreparationStage.discovery;
    _emit();
  }

  List<Errand> get unresolved =>
      activeErrands.where((e) => !candidates.containsKey(e.id)).toList();
  int get candidateLimit => day.errands.isEmpty
      ? 1
      : (12 ~/ activeErrands.length.clamp(1, 12)).clamp(1, 3);
  void found(String id, List<PlanCandidate> values) {
    candidates[id] = values.take(candidateLimit).toList();
    _emit();
  }

  void overridePlace(String id, PlaceIntent place) {
    final key = placeKey(place);
    candidates[id] = [
      PlanCandidate(
        key: key,
        place: place,
        errandIds: {id},
        reason: 'Your selected alternative.',
      ),
    ];
    overrides[id] = key;
    result = null;
    _emit();
  }

  void chooseAlternative(String id, String key) {
    overrides[id] = key;
    result = null;
    _emit();
  }

  List<PlanCandidate> get points {
    final merged = <String, PlanCandidate>{};
    for (final entries in candidates.entries.where(
      (entry) => activeErrands.any((e) => e.id == entry.key),
    )) {
      for (final candidate in entries.value) {
        if (overrides[entries.key] != null &&
            overrides[entries.key] != candidate.key) {
          continue;
        }
        final old = merged[candidate.key];
        merged[candidate.key] = PlanCandidate(
          key: candidate.key,
          place: candidate.place,
          errandIds: {...?old?.errandIds, entries.key},
          reason: candidate.reason,
        );
      }
    }
    return [
      PlanCandidate(key: '@start', place: day.fromPlace, errandIds: {}),
      ...merged.values,
      PlanCandidate(key: '@end', place: day.toPlace, errandIds: {}),
    ];
  }

  Future<void> calculate() async {
    final epoch = ++_epoch;
    result = null;
    error = null;
    stage = PreparationStage.calculating;
    progress = 'Checking road travel times…';
    _emit();
    try {
      // Guard the current calculation input as well as the review projection.
      // Direct source replacement must not hide a new clock/graph conflict.
      final currentTasks = day.errands
          .where((e) => !deferred.containsKey(e.id))
          .toList();
      final currentGraph = ErrandOrder.reconcile(currentTasks).issue;
      if (currentGraph != null) {
        throw PlanningFailure(currentGraph, kind: 'invalid_input');
      }
      final currentIssues = planningInputChecks(day, currentTasks);
      if (currentIssues.isNotEmpty) {
        throw PlanningFailure(
          currentIssues.first.message,
          kind: currentIssues.first.kind,
        );
      }

      final graphIssue = ErrandOrder.reconcile(activeErrands).issue;
      if (graphIssue != null) {
        throw PlanningFailure(graphIssue, kind: 'invalid_input');
      }
      final issues = inputIssues;
      if (issues.isNotEmpty) {
        throw PlanningFailure(issues.first.message, kind: issues.first.kind);
      }
      if (tripDepartureHasPassed(day)) {
        throw const PlanningFailure(
          'The departure is in the past. Choose a new date and departure time.',
          kind: 'invalid_input',
        );
      }
      final selected = points;
      final matrix = await roads.matrix(
        day.copyWith(errands: activeErrands),
        selected,
        cancelled: () => _closed || epoch != _epoch,
      );
      if (_closed || epoch != _epoch) return;
      progress = 'Comparing places and stop order…';
      _emit();
      final input = <String, dynamic>{
        'errands': activeErrands.map((e) => e.toJson()).toList(),
        'keys': selected.map((p) => p.key).toList(),
        'matrix': matrix['matrix'],
        'departure': day.departure * 60,
        'deadline': day.deadline * 60,
        'start': '@start',
        'end': '@end',
        'options': {
          for (final e in activeErrands)
            e.id: selected
                .where((p) => p.errandIds.contains(e.id))
                .map((p) => p.key)
                .toList(),
        },
      };
      final solved = await solver(input);
      if (_closed || epoch != _epoch) return;
      if (solved['error'] != null) {
        throw PlanningFailure(
          solved['message'] as String,
          kind: solved['error'] as String,
        );
      }
      final schedule = DaySchedule.fromJson(
        solved['schedule'] as Map<String, dynamic>,
      );
      if (schedule.stops.isEmpty) {
        throw const PlanningFailure(
          'No errands fit this plan. Adjust the trip window or include another errand.',
        );
      }
      progress = 'Checking the selected route at each departure…';
      _emit();
      final refined = await roads.refine(
        day.copyWith(errands: activeErrands),
        schedule,
        selected,
        cancelled: () => _closed || epoch != _epoch,
      );
      if (_closed || epoch != _epoch) return;
      result = RefinedPlan(
        refined.schedule,
        refined.geometry,
        refined.fallback || matrix['fallback'] == true,
        warnings: refined.warnings,
      );
      stage = PreparationStage.recommendations;
    } catch (e) {
      if (_closed || epoch != _epoch) return;
      error = e is PlanningFailure
          ? e.message
          : 'Planning is unavailable. Your errands and previous plan are kept.';
      stage = PreparationStage.discovery;
    }
    _emit();
  }

  void showResult() {
    stage = PreparationStage.result;
    _emit();
  }

  void review() {
    _epoch++;
    stage = PreparationStage.review;
    error = null;
    _emit();
  }

  Future<AcceptedItinerary> accept(
    int currentRevision,
    int sourceRevision, {
    AcceptedItinerary? history,
  }) async {
    final route = result;
    if (currentRevision != sourceRevision || route == null) {
      throw const PlanningFailure(
        'Today changed. Close this draft and plan again with your latest errands.',
        kind: 'stale',
      );
    }
    final lookup = {for (final p in points) p.key: p.place};
    if (points.any((p) => !p.place.hasCoordinates)) {
      throw const PlanningFailure(
        'A temporary location expired. Refresh it and recalculate.',
      );
    }
    var value = AcceptedItinerary(
      day: day.copyWith(errands: reviewOrder.items),
      deferred: deferred,
      clarifications: {
        for (final e in reviewErrands)
          if (answerFor(e)?.applied == true) e.id: answerFor(e)!.toJson(),
      },
      acceptedAt: DateTime.now(),
      stops: route.schedule.stops
          .map(
            (s) => ItineraryStop(
              lookup[s.placeKey]!,
              s.tasks.map((t) => t.errandId).toList(),
            ),
          )
          .toList(),
      omitted: route.schedule.omitted,
      lightPickupConfirmed: lightPickupConfirmed,
    );
    if (history != null) {
      final done = history.completed;
      final originals = {for (final e in history.day.errands) e.id: e};
      if (day.errands.any((e) => done.contains(e.id))) {
        throw const PlanningFailure(
          'An interpreted task conflicts with completed history. Review the added errands.',
        );
      }
      value = AcceptedItinerary(
        day: day.copyWith(
          errands: [
            ...history.day.errands.where((e) => done.contains(e.id)),
            for (final e in value.day.errands)
              e.copyWith(
                afterErrandIds: {
                  ...e.afterErrandIds,
                  ...?originals[e.id]?.afterErrandIds.where(done.contains),
                }.toList(),
              ),
          ],
        ),
        stops: [
          for (final s in history.stops)
            if (s.errandIds.any(done.contains))
              ItineraryStop(s.place, s.errandIds.where(done.contains).toList()),
          ...value.stops,
        ],
        acceptedAt: value.acceptedAt,
        completed: done,
        omitted: value.omitted,
        deferred: value.deferred,
        clarifications: {...history.clarifications, ...value.clarifications},
        lightPickupConfirmed: lightPickupConfirmed,
      );
    }
    value.validateAssignments();
    await repository.save(value);
    return value;
  }
}
