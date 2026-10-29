import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/data/local_repositories.dart';
import '../../errands/domain/errand_order.dart';
import '../../places/data/google_pin_cache.dart';
import '../../places/domain/place_intent.dart';
import '../../today/domain/day.dart';
import '../data/gemini_interpreter.dart';
import '../data/itinerary_repository.dart';
import '../data/planning_budget.dart';
import '../data/road_estimates.dart';
import '../domain/day_scheduler.dart';
import '../domain/planning_models.dart';
import '../domain/errand_location_review.dart';

final planningBudgetProvider = Provider((ref) => PlanningBudget());
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
  (ref) => GeminiInterpreter(ref.read(planningBudgetProvider)),
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
  }) {
    _reviewItems.addEntries(day.errands.map((e) => MapEntry(e.id, e)));
    _originalIds.addAll(_reviewItems.keys);
  }
  final _reviewItems = <String, Errand>{};
  final _originalIds = <String>{};

  /// The user's draft, before selected suggestions are applied for calculation.
  Errand reviewInput(Errand errand) => _reviewItems[errand.id] ?? errand;
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
  final clarified = <String>{};
  RefinedPlan? result;
  String? error;
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
    _epoch++;
    super.dispose();
  }

  Future<void> understand({bool retry = false}) async {
    final epoch = ++_epoch;
    error = null;
    stage = PreparationStage.understanding;
    _emit();
    try {
      final service = interpreter;
      final value = await (retry && service is ConfirmedRetryInterpreter
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
      clarified.clear();
      candidates.clear();
      overrides.clear();
      result = null;
      needs
        ..clear()
        ..addEntries(value.needs.map((e) => MapEntry(e.id, e)));
      stage = PreparationStage.review;
    } catch (e) {
      if (_closed || epoch != _epoch) return;
      error = e is PlanningFailure
          ? e.message
          : 'Understanding is unavailable. Your text is kept; try again.';
      stage = PreparationStage.failed;
    }
    _emit();
  }

  void edit(Errand value) {
    final previous = _reviewItems[value.id];
    if (previous != null &&
        (previous.title != value.title || previous.notes != value.notes)) {
      interpretationStale = true;
    }
    _reviewItems[value.id] = value;
    day = day.copyWith(
      errands: ErrandOrder.reconcile([
        for (final e in day.errands) e.id == value.id ? value : e,
      ]).items,
    );
    clarified.add(value.id);
    candidates.remove(value.id);
    overrides.remove(value.id);
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
    final items = <Errand>[
      for (final e in _reviewItems.values)
        if (_originalIds.contains(e.id) || additions.contains(e.id))
          approved.contains(e.id) && !clarified.contains(e.id)
              ? needs[e.id]!.apply(e)
              : e,
      for (final n in proposed.additions)
        if (additions.contains(n.id) && !_reviewItems.containsKey(n.id))
          n.apply(Errand(id: n.id, title: n.proposedTitle!, place: '')),
    ];
    for (final n in proposed.additions) {
      if (additions.contains(n.id)) needs[n.id] = n;
    }
    final order = ErrandOrder.reconcile(items);
    if (order.issue != null) {
      throw PlanningFailure(order.issue!, kind: 'invalid_input');
    }
    final reviewedDay = day.copyWith(errands: order.items);
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final departure = DateTime.parse(
      '${day.date}T00:00:00',
    ).add(Duration(minutes: day.departure));
    if (departure.isBefore(
      DateTime(now.year, now.month, now.day, now.hour, now.minute),
    )) {
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
      final need = needs[e.id]!;
      final question = outstandingQuestion(
        need,
        clarified: clarified.contains(e.id),
      );
      if (question != null) {
        throw PlanningFailure(
          'Please resolve “${e.title}”: $question',
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
    day = reviewedDay;
    result = null;
    candidates.removeWhere((id, _) => !day.errands.any((e) => e.id == id));
    error = null;
    stage = PreparationStage.discovery;
    _emit();
  }

  List<Errand> get unresolved =>
      day.errands.where((e) => !candidates.containsKey(e.id)).toList();
  int get candidateLimit =>
      day.errands.isEmpty ? 1 : (12 ~/ day.errands.length).clamp(1, 3);
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
    for (final entries in candidates.entries) {
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
      final selected = points;
      final matrix = await roads.matrix(
        day,
        selected,
        cancelled: () => _closed || epoch != _epoch,
      );
      if (_closed || epoch != _epoch) return;
      progress = 'Comparing places and stop order…';
      _emit();
      final input = <String, dynamic>{
        'errands': day.errands.map((e) => e.toJson()).toList(),
        'keys': selected.map((p) => p.key).toList(),
        'matrix': matrix['matrix'],
        'departure': day.departure * 60,
        'deadline': day.deadline * 60,
        'start': '@start',
        'end': '@end',
        'options': {
          for (final e in day.errands)
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
      progress = 'Checking the selected route at each departure…';
      _emit();
      final refined = await roads.refine(
        day,
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
      day: day,
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
            for (final e in day.errands)
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
        lightPickupConfirmed: lightPickupConfirmed,
      );
    }
    await repository.save(value);
    return value;
  }
}
