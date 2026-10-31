import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/core/data/wayday_database.dart';
import 'package:wayday/features/planning/data/reusable_trip_repository.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'helpers/planning_fixtures.dart' as fixtures;

class NoGeneration implements ErrandInterpreter {
  @override
  Future<Interpretation> interpret(DayPlan day) =>
      throw StateError('Reuse must not generate');
}

void main() {
  for (final mode in [TravelProfile.bike, TravelProfile.truck]) {
    test(
      'reuse preserves the ${mode.name} qualification gate without generation',
      () async {
        final source = fixtures.fixture().copyWith(profile: mode);
        final trip = ReusableTrip(
          id: 'unqualified',
          name: 'Unqualified mode',
          day: source,
          meaning: [
            for (final e in source.errands)
              ErrandNeed(
                id: e.id,
                query: e.title,
                locationIntent: LocationIntent.specific,
              ),
          ],
          choices: {for (final e in source.errands) e.id: e.placeIntent},
        );
        final roads = fixtures.Roads();
        addTearDown(roads.client.close);
        final model = PlanningController(
          source,
          NoGeneration(),
          roads,
          MemoryItineraryRepository(),
          solver: (input) async => solveDay(input),
        );
        addTearDown(model.dispose);
        await model.restoreReusable(trip);
        expect(model.result, isNull);
        expect(model.recommendationFailure?.kind, 'unsupported_profile');
        expect(roads.finished.isCompleted, isFalse);
      },
    );
  }
  test(
    'v6 upgrade and reopen preserve the accepted trip and create template storage',
    () async {
      final directory = await Directory.systemTemp.createTemp('wayday-reuse-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/test.sqlite');
      var database = WaydayDatabase(NativeDatabase(file));
      final accepted = AcceptedItinerary(
        day: fixtures.fixture(),
        stops: [
          ItineraryStop(fixtures.pin, ['a', 'b']),
        ],
        acceptedAt: DateTime.now(),
      );
      await SqliteItineraryRepository(
        database,
        (_) => GooglePinLease(),
      ).save(accepted);
      await database.customStatement('DROP TABLE reusable_trips');
      await database.customStatement('PRAGMA user_version = 6');
      await database.close();
      database = WaydayDatabase(NativeDatabase(file));
      addTearDown(() => database.close());
      final restored = await SqliteItineraryRepository(
        database,
        (_) => GooglePinLease(),
      ).read();
      expect(restored!.runId, accepted.runId);
      expect(restored.stops.single.errandIds, ['a', 'b']);
      expect(
        await SqliteReusableTripRepository(
          database,
          (_) => GooglePinLease(),
        ).read(),
        isEmpty,
      );
      expect(database.schemaVersion, 7);
    },
  );
  test(
    'saved understanding reuses without Gemini and creates fresh active progress',
    () async {
      final source = fixtures.fixture();
      final trip = ReusableTrip(
        id: 'saved',
        name: 'My errands',
        day: source,
        meaning: [
          for (final e in source.errands)
            ErrandNeed(
              id: e.id,
              query: e.title,
              locationIntent: LocationIntent.flexible,
            ),
        ],
        choices: {for (final e in source.errands) e.id: e.placeIntent},
      );
      final run = trip.copyForRun(
        date: source.date,
        departure: source.departure,
        deadline: source.deadline,
      );
      final active = MemoryItineraryRepository(), roads = fixtures.Roads();
      addTearDown(roads.client.close);
      final model = PlanningController(
        run.day,
        NoGeneration(),
        roads,
        active,
        solver: (input) async => solveDay(input),
      );
      addTearDown(model.dispose);
      await model.restoreReusable(run);
      expect(model.proposalReady, isTrue);
      expect(model.displayChoices.length, 2);
      final result = await model.accept(0, 0);
      expect(result.completed, isEmpty);
      expect(result.day.errands.first.id, isNot(source.errands.first.id));
      expect(result.runId, isNotEmpty);
      final firstRun = result.runId;
      expect(
        result.complete(result.stops.first.errandIds.first).runId,
        firstRun,
      );
    },
  );
  test(
    'reusable trips remap dependencies and meaning and never persist Google coordinates',
    () async {
      final lease = GooglePinLease()
        ..latitude = 14.58
        ..longitude = 121.06
        ..acquiredAt = DateTime.now();
      final place = PlaceIntent(
        kind: PlaceKind.providerReference,
        provider: 'google_places_sdk',
        providerPlaceId: 'gym',
        label: 'My gym errand',
        googlePin: lease,
      );
      final trip = ReusableTrip(
        id: 'template',
        name: 'Weekend errands',
        day: DayPlan(
          errands: [
            Errand(id: 'a', title: 'Gym'),
            Errand(id: 'b', title: 'Coffee', afterErrandIds: ['a']),
          ],
        ),
        meaning: [
          const ErrandNeed(
            id: 'a',
            query: 'gym',
            locationIntent: LocationIntent.flexible,
          ),
          const ErrandNeed(
            id: 'b',
            query: 'coffee',
            locationIntent: LocationIntent.flexible,
            after: ['a'],
          ),
        ],
        choices: {'a': place, 'b': place},
      );
      final encoded = jsonEncode(trip.toJson());
      expect(encoded, isNot(contains('14.58')));
      expect(encoded, isNot(contains('121.06')));
      expect(encoded, isNot(contains('polyline')));
      final database = WaydayDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repo = SqliteReusableTripRepository(database, (_) => lease);
      await repo.save(trip);
      final restored = (await repo.read()).single;
      final run = restored.copyForRun(
        date: '2030-03-03',
        departure: 600,
        deadline: 1000,
        runId: 'new',
      );
      expect(run.day.errands.last.afterErrandIds, ['new:a']);
      expect(run.meaning.last.after, ['new:a']);
      expect(run.choices.keys, ['new:a', 'new:b']);
      expect(restored.day.errands.first.id, 'a');
      expect(run.day.date, '2030-03-03');
      await repo.delete(trip.id);
      expect(await repo.read(), isEmpty);
    },
  );
}
