import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/core/data/local_repositories.dart';
import 'package:wayday/core/data/wayday_database.dart';
import 'package:wayday/features/planning/data/review_trip_repository.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/data/interpretation_request.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  test(
    'restart restores only manually confirmed source-errand clocks',
    () async {
      final dir = await Directory.systemTemp.createTemp('wayday-review-times-');
      final file = File('${dir.path}/times.sqlite');
      var db = WaydayDatabase(NativeDatabase(file));
      final source = fixture();
      final manual = source.errands.first.copyWith(
        timing: TimingRule.arriveBy,
        minute: 840,
        confirmedFields: {'timing'},
        notes: 'not retained',
        durationMinutes: 99,
      );
      final draft = source.copyWith(
        errands: [
          manual,
          source.errands.last.copyWith(timing: TimingRule.at, minute: 900),
          const Errand(
            id: 'extra',
            title: 'Not a source errand',
            timing: TimingRule.at,
            minute: 950,
            confirmedFields: {'timing'},
          ),
        ],
      );
      await SqliteReviewTripRepository(db).save(source, draft);
      await db.close();
      db = WaydayDatabase(NativeDatabase(file));
      try {
        final saved = (await SqliteReviewTripRepository(db).read(source))!;
        final restored = saved.apply(source);
        expect(restored.errands.first.minute, 840);
        expect(restored.errands.first.confirmedFields, contains('timing'));
        expect(restored.errands.first.notes, source.errands.first.notes);
        expect(
          restored.errands.first.durationMinutes,
          source.errands.first.durationMinutes,
        );
        expect(restored.errands.last.minute, isNull);
        expect(saved.timingEdits.keys, ['a']);
        expect(
          interpretationRequest(saved.applyTripSettings(source)),
          interpretationRequest(source),
        );
        expect(
          () => saved.apply(source.copyWith(errands: [source.errands.last])),
          throwsFormatException,
        );
        expect(
          await SqliteReviewTripRepository(
            db,
          ).read(source.copyWith(revision: 1)),
          isNull,
        );
        await SqliteReviewTripRepository(db).save(source, source);
        expect(
          (await SqliteReviewTripRepository(db).read(source))!.timingEdits,
          isEmpty,
        );
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'malformed saved clocks fail visibly and legacy trip payloads remain valid',
    () {
      for (final minute in [null, -1, 1440, '900']) {
        expect(
          () => ReviewTrip.fromJson({
            'date': '2026-12-01',
            'departure': 510,
            'deadline': 1080,
            'errandTimes': {
              'a': {'timing': 'at', 'minute': minute},
            },
          }),
          throwsFormatException,
        );
      }
      expect(
        ReviewTrip.fromJson({
          'date': '2026-12-01',
          'departure': 510,
          'deadline': 1080,
        }).timingEdits,
        isEmpty,
      );
    },
  );
  test(
    'v3 upgrade and restart retain trip edits, Today and accepted progress separately',
    () async {
      final dir = await Directory.systemTemp.createTemp('wayday-review-trip-');
      final file = File('${dir.path}/test.sqlite');
      var db = WaydayDatabase(NativeDatabase(file));
      final source = fixture();
      final local = await LocalRepositories.open(database: db);
      await local.today.save(source);
      final accepted = AcceptedItinerary(
        day: source,
        stops: [
          const ItineraryStop(pin, ['a', 'b']),
        ],
        acceptedAt: DateTime.now(),
      ).complete('a');
      await SqliteItineraryRepository(
        db,
        (_) => GooglePinLease(),
      ).save(accepted);
      await db.customStatement('DROP TABLE review_trips');
      await db.customStatement('DROP TABLE clarification_sessions');
      await db.customStatement('DROP TABLE IF EXISTS recommendation_drafts');
      await db.customStatement('PRAGMA user_version=3');
      await db.close();
      db = WaydayDatabase(NativeDatabase(file));
      final draft = source.copyWith(
        date: '2026-12-01',
        departure: 720,
        deadline: 1200,
      );
      await SqliteReviewTripRepository(db).save(source, draft);
      await db.close();
      db = WaydayDatabase(NativeDatabase(file));
      try {
        final restored = await SqliteReviewTripRepository(db).read(source);
        expect(restored!.apply(source).date, '2026-12-01');
        expect(restored.departure, 720);
        expect(restored.deadline, 1200);
        final reopened = await LocalRepositories.open(database: db);
        expect(reopened.today.read().toJson(), source.toJson());
        expect(
          (await SqliteItineraryRepository(
            db,
            (_) => GooglePinLease(),
          ).read())!.completed,
          {'a'},
        );
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
            'user_version',
          ),
          6,
        );
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .data
              .values
              .single,
          'ok',
        );
        final row = await db.select(db.reviewTrips).getSingle();
        expect((jsonDecode(row.payload) as Map).keys.toSet(), {
          'date',
          'departure',
          'deadline',
        });
        expect(
          interpretationRequest(restored.apply(source)),
          interpretationRequest(source),
        );
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'source changes invalidate stale settings and writes preserve latest edit',
    () async {
      final db = WaydayDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = SqliteReviewTripRepository(db), source = fixture();
      final writes = Future.wait([
        repo.save(source, source.copyWith(departure: 600)),
        repo.save(source, source.copyWith(departure: 720)),
      ]);
      expect((await repo.read(source))!.departure, 720);
      await writes;
      expect(await repo.read(source.copyWith(revision: 1)), isNull);
      expect(await repo.read(source.copyWith(date: '2026-12-31')), isNull);
      expect(
        await repo.read(source.copyWith(errands: [source.errands.first])),
        isNull,
      );
      expect(await db.select(db.reviewTrips).get(), hasLength(1));
    },
  );

  test(
    'malformed settings are surfaced instead of silently restored',
    () async {
      final db = WaydayDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = SqliteReviewTripRepository(db), source = fixture();
      await repo.save(source, source);
      await db.customStatement("UPDATE review_trips SET payload='bad'");
      await expectLater(repo.read(source), throwsFormatException);
      await repo.save(source, source.copyWith(departure: 800));
      expect((await repo.read(source))!.departure, 800);
    },
  );
}
