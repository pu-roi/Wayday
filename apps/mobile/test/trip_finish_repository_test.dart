import 'package:drift/native.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/core/data/wayday_database.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/places/data/google_pin_cache.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  test(
    'finished cleanup remains empty after closing and reopening SQLite',
    () async {
      final directory = await Directory.systemTemp.createTemp('wayday-finish-');
      final file = File('${directory.path}/trip.sqlite');
      var db = WaydayDatabase(NativeDatabase(file));
      try {
        final today = await SqliteDayRepository.open(db);
        final trips = SqliteItineraryRepository(db, GooglePinCache().lease);
        await today.save(fixture().copyWith(revision: 4));
        final trip = AcceptedItinerary(
          day: fixture(),
          stops: [
            ItineraryStop(pin, ['a', 'b']),
          ],
          acceptedAt: DateTime.now(),
        ).complete('a').complete('b');
        await trips.save(trip);
        await trips.finish(
          trip.runId,
          today: today,
          expectedRevision: 4,
          stillCurrent: () => true,
          now: DateTime.now(),
        );
        await db.close();
        db = WaydayDatabase(NativeDatabase(file));
        expect((await SqliteDayRepository.open(db)).read().errands, isEmpty);
        expect(
          await SqliteItineraryRepository(db, GooglePinCache().lease).read(),
          isNull,
        );
        expect(db.schemaVersion, 7);
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
  Future<(SqliteDayRepository, SqliteItineraryRepository, AcceptedItinerary)>
  setup(WaydayDatabase db) async {
    final today = await SqliteDayRepository.open(db);
    await today.save(fixture().copyWith(revision: 5));
    final trips = SqliteItineraryRepository(db, GooglePinCache().lease);
    final trip = AcceptedItinerary(
      day: fixture(),
      stops: [
        ItineraryStop(pin, ['a', 'b']),
      ],
      acceptedAt: DateTime.now(),
    ).complete('a').complete('b');
    await trips.save(trip);
    return (today, trips, trip);
  }

  test(
    'failure halfway through finish rolls back both Today and trip deletion',
    () async {
      final db = WaydayDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final (today, trips, trip) = await setup(db);
      await db.customStatement(
        "CREATE TRIGGER fail_today_clear BEFORE DELETE ON day_errands BEGIN SELECT RAISE(ABORT, 'fixture save failure'); END",
      );
      await expectLater(
        trips.finish(
          trip.runId,
          today: today,
          expectedRevision: 5,
          stillCurrent: () => true,
          now: DateTime.now(),
        ),
        throwsA(anything),
      );
      expect(today.read().errands.length, 2);
      expect((await trips.read())!.completed, {'a', 'b'});
      expect((await SqliteDayRepository.open(db)).read().revision, 5);
      await db.customStatement('DROP TRIGGER fail_today_clear');
      await trips.finish(
        trip.runId,
        today: today,
        expectedRevision: 5,
        stillCurrent: () => true,
        now: DateTime.now(),
      );
      expect(await trips.read(), isNull);
    },
  );
  test('wrong trip or changed Today cannot clear a newer snapshot', () async {
    final db = WaydayDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final (today, trips, trip) = await setup(db);
    final newer = AcceptedItinerary(
      day: trip.day,
      stops: trip.stops,
      completed: trip.completed,
      acceptedAt: DateTime.now(),
      runId: 'new-trip',
    );
    await trips.save(newer);
    await expectLater(
      trips.finish(
        trip.runId,
        today: today,
        expectedRevision: 5,
        stillCurrent: () => true,
        now: DateTime.now(),
      ),
      throwsA(anything),
    );
    final write = today.save(today.read().copyWith(revision: 6));
    final finish = trips.finish(
      newer.runId,
      today: today,
      expectedRevision: 5,
      stillCurrent: () => true,
      now: DateTime.now(),
    );
    await write;
    await expectLater(finish, throwsA(isA<TodayChangedDuringFinish>()));
    expect((await trips.read())!.runId, 'new-trip');
    expect(today.read().revision, 6);
  });
  test(
    'changed UI revision during transaction rolls back and unrelated stores survive',
    () async {
      final db = WaydayDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final (today, trips, trip) = await setup(db);
      await db.customStatement(
        "INSERT INTO reusable_trips (id,name,payload) VALUES ('saved','Explicit template','{}')",
      );
      await db.customStatement(
        "INSERT INTO recurring_groups (id,position,name,repeat,day) VALUES ('routine',0,'My list','weekly',1)",
      );
      await db.customStatement(
        "INSERT INTO saved_places (id,payload) VALUES ('home','{}')",
      );
      var checks = 0;
      await expectLater(
        trips.finish(
          trip.runId,
          today: today,
          expectedRevision: 5,
          stillCurrent: () => ++checks == 1,
          now: DateTime.now(),
        ),
        throwsA(isA<TodayChangedDuringFinish>()),
      );
      expect(await trips.read(), isNotNull);
      expect(today.read().errands.length, 2);
      await trips.finish(
        trip.runId,
        today: today,
        expectedRevision: 5,
        stillCurrent: () => true,
        now: DateTime.now(),
      );
      expect((await db.select(db.reusableTrips).get()).single.id, 'saved');
      expect((await db.select(db.recurringGroups).get()).single.id, 'routine');
      expect((await db.select(db.savedPlaces).get()).single.id, 'home');
    },
  );
  test(
    'finish atomically clears Today and current trip; stale progress cannot resurrect it',
    () async {
      final database = WaydayDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final today = await SqliteDayRepository.open(database);
      final trips = SqliteItineraryRepository(database, GooglePinCache().lease);
      final day = fixture().copyWith(revision: 8);
      await today.save(day);
      final trip = AcceptedItinerary(
        day: day,
        stops: [
          ItineraryStop(pin, ['a', 'b']),
        ],
        acceptedAt: DateTime.now(),
      );
      final completed = trip.complete('a').complete('b');
      await trips.save(completed);
      final reset = await trips.finish(
        trip.runId,
        today: today,
        expectedRevision: 8,
        stillCurrent: () => true,
        now: DateTime.utc(2026, 10, 31, 17),
      );
      expect(reset.date, '2026-11-01');
      expect(reset.errands, isEmpty);
      expect(reset.fromPlace.hasCoordinates, isFalse);
      expect(reset.departure, 510);
      expect(await trips.read(), isNull);
      await expectLater(trips.updateProgress(completed), throwsA(anything));
      await today.save(day);
      final reopened = await SqliteDayRepository.open(database);
      expect(reopened.read().errands, isEmpty);
      expect(await trips.read(), isNull);
    },
  );
}
