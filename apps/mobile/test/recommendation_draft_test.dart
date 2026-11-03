import 'package:drift/native.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/core/data/wayday_database.dart';
import 'package:wayday/features/planning/data/recommendation_draft_repository.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  test(
    'legacy drafts stay readable and malformed pending groups are rejected',
    () {
      final legacy = RecommendationDraft(
        context: 'x',
        choices: const {},
      ).toJson()..remove('manualPlaces');
      expect(
        RecommendationDraft.fromJson(
          Map<String, dynamic>.from(legacy),
        ).manualPlaces,
        isEmpty,
      );
      expect(
        () => RecommendationDraft.fromJson({
          ...legacy,
          'manualPlaces': ['a'],
        }),
        throwsFormatException,
      );
      expect(
        RecommendationDraft.fromJson(
          Map<String, dynamic>.from(legacy),
        ).pendingCandidates,
        isEmpty,
      );
      for (final pending in [
        {'a': <Object?>[]},
        {
          'a': [pin.toJson(), pin.toJson(), pin.toJson(), pin.toJson()],
        },
      ]) {
        expect(
          () => RecommendationDraft.fromJson({
            ...legacy,
            'pendingCandidates': pending,
          }),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'v5 upgrade and SQLite reopen retain choices and existing accepted data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'wayday-recommendation-test-',
      );
      final file = File('${directory.path}/draft.sqlite');
      var db = WaydayDatabase(NativeDatabase(file));
      await db.customStatement(
        'INSERT INTO accepted_itineraries(id,payload) VALUES(1,?)',
        ['preserved-existing-payload'],
      );
      await db.customStatement('DROP TABLE recommendation_drafts');
      await db.customStatement('PRAGMA user_version=5');
      await db.close();
      db = WaydayDatabase(NativeDatabase(file));
      await SqliteRecommendationDraftRepository(db).save(
        'source',
        RecommendationDraft(
          context: 'context',
          choices: {'a': pin},
          pendingCandidates: {
            'b': [pin],
          },
          overrides: {'a'},
          manualPlaces: {'a'},
          selectedErrand: 'a',
          scrollOffset: 64,
        ),
      );
      await db.close();
      db = WaydayDatabase(NativeDatabase(file));
      try {
        final restored = await SqliteRecommendationDraftRepository(
          db,
        ).read('source', 'context');
        expect(restored!.selectedErrand, 'a');
        expect(restored.overrides, {'a'});
        expect(restored.manualPlaces, {'a'});
        expect(restored.choices['a']!.toJson(), pin.toJson());
        expect(restored.pendingCandidates['b']!.single.toJson(), pin.toJson());
        expect(restored.scrollOffset, 64);
        expect(
          (await db
                  .customSelect(
                    'SELECT payload FROM accepted_itineraries WHERE id=1',
                  )
                  .getSingle())
              .read<String>('payload'),
          'preserved-existing-payload',
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
        if (directory.parent.absolute.path !=
            Directory.systemTemp.absolute.path) {
          throw StateError('Unexpected test directory');
        }
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'drafts are source and context bound, separate from accepted progress',
    () async {
      final db = WaydayDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = SqliteRecommendationDraftRepository(db);
      final draft = RecommendationDraft(
        context: 'route-one',
        choices: {'a': pin},
        overrides: {'a'},
        selectedErrand: 'a',
        scrollOffset: 42,
      );
      await repository.save('today-one', draft);
      expect(
        (await repository.read('today-one', 'route-one'))!.selectedErrand,
        'a',
      );
      expect(
        (await repository.read('today-one', 'route-one'))!.scrollOffset,
        42,
      );
      expect(await repository.read('today-two', 'route-one'), isNull);
      expect(await repository.read('today-one', 'route-two'), isNull);
      expect(await db.select(db.acceptedItineraries).get(), isEmpty);
      expect(db.schemaVersion, 7);
    },
  );
  test('corrupt draft positions and unassigned overrides are rejected', () {
    expect(
      () => RecommendationDraft.fromJson({
        'version': 1,
        'context': 'x',
        'choices': <String, dynamic>{},
        'overrides': ['missing'],
        'offset': -1,
      }),
      throwsFormatException,
    );
  });
}
