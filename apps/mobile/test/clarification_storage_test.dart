import 'dart:io';
import 'dart:convert';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/core/data/wayday_database.dart';
import 'package:wayday/core/data/local_repositories.dart';
import 'package:wayday/features/planning/data/clarification_repository.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  test(
    'v4 upgrade and restart preserve source data, answer drafts and dated deferrals',
    () async {
      final dir = await Directory.systemTemp.createTemp('wayday-answers-');
      final file = File('${dir.path}/app.sqlite');
      var db = WaydayDatabase(NativeDatabase(file));
      final source = fixture();
      final local = await LocalRepositories.open(database: db);
      await local.today.save(source);
      final accepted = AcceptedItinerary(
        day: source,
        stops: const [
          ItineraryStop(pin, ['a', 'b']),
        ],
        acceptedAt: DateTime.now(),
        completed: const {'a'},
      ).toJson();
      accepted['version'] = 1;
      accepted.remove('deferred');
      accepted.remove('clarifications');
      final acceptedPayload = jsonEncode(accepted);
      await db.customStatement(
        'INSERT INTO accepted_itineraries (id,payload) VALUES (?,?)',
        [1, acceptedPayload],
      );
      await db.customStatement('DROP TABLE clarification_sessions');
      await db.customStatement('PRAGMA user_version=4');
      await db.close();
      db = WaydayDatabase(NativeDatabase(file));
      final c = ClarificationContext.create(
        source.errands.first,
        const ErrandNeed(id: 'a', query: 'grocery', question: 'What items?'),
        source.errands,
      );
      final session = ClarificationSession(
        records: {
          c.key: ClarificationRecord(
            context: c,
            answer: 'Di ko pa alam',
            status: 'processing',
          ),
        },
        deferrals: {
          source.date: {'b': 'Meeting point needed'},
        },
      );
      final repo = SqliteClarificationRepository(db);
      await repo.save(clarificationSourceKey(source), session);
      await db.close();
      db = WaydayDatabase(NativeDatabase(file));
      try {
        final restored = await SqliteClarificationRepository(
          db,
        ).read(clarificationSourceKey(source.copyWith(departure: 720)));
        expect(restored.records[c.key]!.answer, 'Di ko pa alam');
        expect(restored.records[c.key]!.status, 'processing');
        expect(restored.deferrals[source.date], {'b': 'Meeting point needed'});
        expect(
          (await LocalRepositories.open(database: db)).today.read().toJson(),
          source.toJson(),
        );
        expect(
          (await db
                  .customSelect(
                    'SELECT payload FROM accepted_itineraries WHERE id=1',
                  )
                  .getSingle())
              .read<String>('payload'),
          acceptedPayload,
        );
        expect(
          (await SqliteItineraryRepository(
            db,
            (_) => GooglePinLease(),
          ).read())!.completed,
          {'a'},
        );
        expect(
          clarificationSourceKey(
            source.copyWith(errands: [source.errands.first]),
          ),
          isNot(clarificationSourceKey(source)),
        );
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .data
              .values
              .single,
          'ok',
        );
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
