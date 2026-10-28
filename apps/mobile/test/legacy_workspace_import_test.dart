import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/core/data/legacy_workspace_import.dart';
import 'package:wayday/core/data/local_repositories.dart';
import 'package:wayday/core/data/wayday_database.dart' hide SavedPlace;
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/recurring/domain/errand_group.dart';
import 'package:wayday/features/today/domain/day.dart';

void main() {
  test('failed legacy import rolls back every destination section', () async {
    final day = DayPlan(errands: const [Errand(id: 'e', title: 'Keep')]);
    const place = PlaceIntent(kind: PlaceKind.specific, label: 'Cebu', latitude: 10.3, longitude: 123.9);
    final saved = SavedPlace(id: 'same', place: place);
    final docs = {
      'day': jsonEncode({'format': 1, 'value': day.toJson()}),
      'groups': jsonEncode({'format': 1, 'value': <Object>[]}),
      'places': jsonEncode({'format': 1, 'value': [saved.toJson(), saved.toJson()]}),
    };
    final db = WaydayDatabase(NativeDatabase.memory());
    try {
      await expectLater(LegacyWorkspace.decode(docs).importInto(db), throwsA(anything));
      expect(await db.select(db.daySettings).get(), isEmpty);
      expect(await db.select(db.dayErrands).get(), isEmpty);
      expect(await db.select(db.savedPlaces).get(), isEmpty);
    } finally {
      await db.close();
    }
  });
  test(
    'imports Rudy workspace without touching source or overwriting a destination',
    () async {
      final place = const PlaceIntent(
        kind: PlaceKind.specific,
        label: 'Cebu',
        latitude: 10.3,
        longitude: 123.9,
      );
      final day = DayPlan(
        errands: const [Errand(id: 'e', title: 'Buy', notes: 'Keep this')],
        from: 'Cebu',
        fromPlace: place,
      );
      final group = ErrandGroup(
        id: 'g',
        name: 'List',
        items: const [Errand(id: 'item', title: 'Milk')],
      );
      final docs = <String, String>{
        'day': jsonEncode({'format': 1, 'value': day.toJson()}),
        'groups': jsonEncode({
          'format': 1,
          'value': [group.toJson()],
        }),
        'places': jsonEncode({
          'format': 1,
          'value': [SavedPlace(id: 'p', place: place).toJson()],
        }),
      };
      final source = Map<String, String>.of(docs);
      final workspace = LegacyWorkspace.decode(docs);
      final db = WaydayDatabase(NativeDatabase.memory());
      try {
        await workspace.importInto(db);
        final repos = await LocalRepositories.open(database: db);
        expect(repos.today.read().fromPlace.latitude, 10.3);
        expect(repos.today.read().errands.single.notes, 'Keep this');
        expect(repos.recurring.read().single.name, 'List');
        expect(await db.select(db.savedPlaces).get(), hasLength(1));
        expect(docs, source);
        await expectLater(workspace.importInto(db), throwsStateError);
      } finally {
        await db.close();
      }
    },
  );

  test('rejects incomplete workspace before importing', () {
    expect(() => LegacyWorkspace.decode({'day': '{}'}), throwsFormatException);
  });
}
