import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../core/data/wayday_database.dart';
import '../../../core/data/serial_write_queue.dart';
import '../../today/data/day_repository.dart';
import '../../today/domain/day.dart';
import '../../places/domain/place_intent.dart';
import '../domain/planning_models.dart';
import '../domain/clarification.dart';
import 'reusable_trip_repository.dart' show newTripIdentity;

/// Durable task-owned choices/progress only: no Google response text, ETAs,
/// road geometry, matrices or copied coordinates bypassing provider retention.
class AcceptedItinerary {
  AcceptedItinerary({
    required this.day,
    required List<ItineraryStop> stops,
    required this.acceptedAt,
    Set<String> completed = const {},
    Map<String, String> omitted = const {},
    this.lightPickupConfirmed = false,
    String? runId,
    Map<String, String> deferred = const {},
    Map<String, Map<String, dynamic>> clarifications = const {},
  }) : runId = runId ?? newTripIdentity(),
       stops = List.unmodifiable(
         stops.map(
           (s) => ItineraryStop(s.place, List.unmodifiable(s.errandIds)),
         ),
       ),
       completed = Set.unmodifiable(completed),
       omitted = Map.unmodifiable(omitted),
       deferred = Map.unmodifiable(deferred),
       clarifications = Map.unmodifiable(clarifications);
  final DayPlan day;
  final List<ItineraryStop> stops;
  final DateTime acceptedAt;
  final Set<String> completed;
  final Map<String, String> omitted, deferred;
  final Map<String, Map<String, dynamic>> clarifications;
  final bool lightPickupConfirmed;
  final String runId;
  AcceptedItinerary complete(String id) {
    if (!stops.any((s) => s.errandIds.contains(id))) {
      throw const FormatException('Unknown task');
    }
    final e = day.errands.firstWhere((e) => e.id == id);
    if (!e.afterErrandIds.every(completed.contains)) {
      throw const PlanningFailure(
        'Complete this errand’s prerequisites first.',
        kind: 'ordering',
      );
    }
    return AcceptedItinerary(
      day: day,
      stops: stops,
      acceptedAt: acceptedAt,
      completed: {...completed, id},
      omitted: omitted,
      deferred: deferred,
      clarifications: clarifications,
      lightPickupConfirmed: lightPickupConfirmed,
      runId: runId,
    );
  }

  Map<String, Object> toJson() => {
    'version': 2,
    'runId': runId,
    'day': day.toJson(),
    'stops': stops.map((s) => s.toJson()).toList(),
    'acceptedAt': acceptedAt.toUtc().toIso8601String(),
    'completed': completed.toList(),
    'omitted': omitted,
    'deferred': deferred,
    'clarifications': clarifications,
    'lightPickupConfirmed': lightPickupConfirmed,
  };
  factory AcceptedItinerary.fromJson(
    Map<String, dynamic> json,
    GooglePinResolver resolver,
  ) {
    if (json['version'] != 1 && json['version'] != 2) {
      throw const FormatException('Unsupported itinerary version');
    }
    final day = DayPlan.fromJson(
      json['day'] as Map<String, dynamic>,
      resolveGooglePin: resolver,
    );
    final stops = (json['stops'] as List)
        .map(
          (s) => ItineraryStop.fromJson(
            Map<String, dynamic>.from(s as Map),
            resolver,
          ),
        )
        .toList();
    final completed = (json['completed'] as List).cast<String>().toSet();
    final omitted = Map<String, String>.from(json['omitted'] as Map);
    final deferred = json['version'] == 1
        ? <String, String>{}
        : Map<String, String>.from(json['deferred'] as Map);
    final clarifications = json['version'] == 1
        ? <String, Map<String, dynamic>>{}
        : (json['clarifications'] as Map).map(
            (k, v) =>
                MapEntry(k as String, Map<String, dynamic>.from(v as Map)),
          );
    final result = AcceptedItinerary(
      day: day,
      stops: stops,
      acceptedAt: DateTime.parse(json['acceptedAt'] as String),
      completed: completed,
      omitted: omitted,
      deferred: deferred,
      clarifications: clarifications,
      lightPickupConfirmed: json['lightPickupConfirmed'] == true,
      runId: json['runId'] as String? ?? 'legacy-${json['acceptedAt']}',
    );
    result.validateAssignments();
    return result;
  }
  void validateAssignments() {
    final ids = day.errands.map((e) => e.id).toSet();
    final assigned = stops.expand((s) => s.errandIds).toList();
    if (assigned.isEmpty ||
        ids.length != day.errands.length ||
        stops.any((s) => s.errandIds.isEmpty) ||
        deferred.entries.any(
          (e) =>
              !ids.contains(e.key) ||
              assigned.contains(e.key) ||
              omitted.containsKey(e.key) ||
              e.value.trim().isEmpty ||
              e.value.length > 240,
        ) ||
        clarifications.entries.any(
          (e) =>
              !ids.contains(e.key) ||
              ClarificationRecord.fromJson(e.value).context.id != e.key,
        ) ||
        omitted.keys.any(
          (id) => !day.errands.any((e) => e.id == id && e.optional),
        ) ||
        day.errands.any(
          (e) =>
              completed.contains(e.id) &&
              !e.afterErrandIds.every(completed.contains),
        ) ||
        assigned.toSet().length != assigned.length ||
        assigned.any((id) => !ids.contains(id)) ||
        completed.any((id) => !assigned.contains(id)) ||
        omitted.keys.any((id) => !ids.contains(id) || assigned.contains(id)) ||
        day.errands.any(
          (e) =>
              !assigned.contains(e.id) &&
              !deferred.containsKey(e.id) &&
              (!e.optional || !omitted.containsKey(e.id)),
        )) {
      throw const FormatException('Invalid itinerary assignments');
    }
    final seen = <String>{};
    for (final id in assigned) {
      final e = day.errands.firstWhere((e) => e.id == id);
      if (!e.afterErrandIds.every(seen.contains)) {
        throw const FormatException('Invalid itinerary ordering');
      }
      seen.add(id);
    }
  }
}

class ItineraryStop {
  const ItineraryStop(this.place, this.errandIds);
  final PlaceIntent place;
  final List<String> errandIds;
  Map<String, Object> toJson() => {
    'place': place.toJson(),
    'errands': errandIds,
  };
  factory ItineraryStop.fromJson(
    Map<String, dynamic> json,
    GooglePinResolver resolver,
  ) => ItineraryStop(
    PlaceIntent.fromJson(
      json['place'] as Map<String, dynamic>,
      resolveGooglePin: resolver,
    ),
    (json['errands'] as List).cast<String>(),
  );
}

abstract interface class ItineraryRepository {
  Future<AcceptedItinerary?> read();
  Future<void> save(AcceptedItinerary value);
  Future<void> updateProgress(AcceptedItinerary value);
  Future<DayPlan> finish(
    String runId, {
    required DayRepository today,
    required int expectedRevision,
    required bool Function() stillCurrent,
    required DateTime now,
  });
}

class MemoryItineraryRepository implements ItineraryRepository {
  AcceptedItinerary? value;
  @override
  Future<AcceptedItinerary?> read() async => value;
  @override
  Future<void> save(AcceptedItinerary value) async {
    value.validateAssignments();
    this.value = value;
  }

  @override
  Future<void> updateProgress(AcceptedItinerary value) async {
    _checkProgress(this.value, value);
    this.value = value;
  }

  @override
  Future<DayPlan> finish(
    String runId, {
    required DayRepository today,
    required int expectedRevision,
    required bool Function() stillCurrent,
    required DateTime now,
  }) async {
    if (today is! MemoryDayRepository) {
      throw StateError('Mismatched trip storage');
    }
    _checkFinished(value, runId);
    if (today.read().revision != expectedRevision || !stillCurrent()) {
      throw const TodayChangedDuringFinish();
    }
    final reset = DayPlan(
      errands: const [],
      date: pilotToday(now),
      revision: expectedRevision + 1,
    );
    today.applyFinishedReset(reset);
    value = null;
    return reset;
  }
}

class SqliteItineraryRepository implements ItineraryRepository {
  SqliteItineraryRepository(this.database, this.resolver);
  final WaydayDatabase database;
  final GooglePinResolver resolver;
  @override
  Future<AcceptedItinerary?> read() async {
    final row = await (database.select(
      database.acceptedItineraries,
    )..where((r) => r.id.equals(1))).getSingleOrNull();
    return row == null
        ? null
        : AcceptedItinerary.fromJson(
            jsonDecode(row.payload) as Map<String, dynamic>,
            resolver,
          );
  }

  @override
  Future<void> save(AcceptedItinerary value) =>
      SerialWriteQueue.forOwner(database).enqueue(() => _save(value));
  Future<void> _save(AcceptedItinerary value) => database.transaction(() async {
    value.validateAssignments();
    await database
        .into(database.acceptedItineraries)
        .insertOnConflictUpdate(
          AcceptedItinerariesCompanion.insert(
            id: const Value(1),
            payload: jsonEncode(value.toJson()),
          ),
        );
  });
  @override
  Future<void> updateProgress(AcceptedItinerary value) =>
      SerialWriteQueue.forOwner(database).enqueue(() async {
        _checkProgress(await read(), value);
        await _save(value);
      });
  @override
  Future<DayPlan> finish(
    String runId, {
    required DayRepository today,
    required int expectedRevision,
    required bool Function() stillCurrent,
    required DateTime now,
  }) {
    if (today is! SqliteDayRepository || !today.usesDatabase(database)) {
      throw StateError('Mismatched trip storage');
    }
    return today.finishTrip(
      expectedRevision: expectedRevision,
      stillCurrent: stillCurrent,
      now: now,
      removeTrip: () async {
        _checkFinished(await read(), runId);
        await (database.delete(
          database.acceptedItineraries,
        )..where((row) => row.id.equals(1))).go();
      },
    );
  }
}

bool allTripErrandsComplete(AcceptedItinerary value) =>
    value.stops.expand((s) => s.errandIds).every(value.completed.contains);

void _checkFinished(AcceptedItinerary? value, String runId) {
  if (value == null || value.runId != runId) {
    throw const PlanningFailure(
      'The current trip changed. Open the current trip before finishing.',
      kind: 'trip_changed',
    );
  }
  if (!allTripErrandsComplete(value)) {
    throw const PlanningFailure(
      'Complete the current trip errands before finishing.',
      kind: 'trip_incomplete',
    );
  }
}

void _checkProgress(AcceptedItinerary? current, AcceptedItinerary next) {
  if (current == null ||
      current.runId != next.runId ||
      !next.completed.containsAll(current.completed)) {
    throw const PlanningFailure(
      'This trip changed or has finished. Your newer progress is kept.',
      kind: 'trip_changed',
    );
  }
  next.validateAssignments();
}
