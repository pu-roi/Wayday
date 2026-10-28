import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:wayday/core/data/local_repositories.dart';
import 'package:wayday/core/data/wayday_database.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/recurring/domain/errand_group.dart';
import 'package:wayday/features/today/domain/day.dart';

void main() {
  test('upgrades Roi version 1 without losing saved rows', () async {
    final dir = await Directory.systemTemp.createTemp('wayday-v1-');
    final file = File('${dir.path}/legacy.sqlite');
    final legacy = sqlite.sqlite3.open(file.path);
    legacy.execute(
      'CREATE TABLE day_settings (id INTEGER PRIMARY KEY, from_place TEXT NOT NULL, to_place TEXT NOT NULL, departure INTEGER NOT NULL, deadline INTEGER NOT NULL, profile TEXT NOT NULL)',
    );
    legacy.execute(
      'CREATE TABLE day_errands (id TEXT PRIMARY KEY, position INTEGER NOT NULL, title TEXT NOT NULL, place TEXT NOT NULL, notes TEXT NOT NULL, timing TEXT NOT NULL, minute INTEGER, optional INTEGER NOT NULL, source_group_id TEXT, source_item_id TEXT)',
    );
    legacy.execute(
      'CREATE TABLE recurring_groups (id TEXT PRIMARY KEY, position INTEGER NOT NULL, name TEXT NOT NULL, repeat TEXT NOT NULL, day INTEGER NOT NULL)',
    );
    legacy.execute(
      'CREATE TABLE group_errands (id TEXT PRIMARY KEY, group_id TEXT NOT NULL, position INTEGER NOT NULL, title TEXT NOT NULL, place TEXT NOT NULL, notes TEXT NOT NULL, timing TEXT NOT NULL, minute INTEGER, optional INTEGER NOT NULL)',
    );
    legacy.execute(
      "INSERT INTO day_settings VALUES (1, 'Home', 'Office', 510, 1080, 'motor')",
    );
    legacy.execute(
      "INSERT INTO day_errands VALUES ('a', 0, 'Buy', 'Shop', 'Notes', 'anytime', NULL, 0, NULL, NULL)",
    );
    legacy.execute('PRAGMA user_version = 1');
    legacy.close();
    final db = WaydayDatabase(NativeDatabase(file));
    try {
      final repositories = await LocalRepositories.open(database: db);
      expect(repositories.today.read().from, 'Home');
      expect(repositories.today.read().errands.single.notes, 'Notes');
      expect(
        repositories.today.read().errands.single.placeIntent.hasCoordinates,
        isFalse,
      );
      await repositories.today.save(repositories.today.read());
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });
  test(
    'place coordinates and errand details survive a database restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('wayday-places-');
      final file = File('${dir.path}/places.sqlite');
      var db = WaydayDatabase(NativeDatabase(file));
      try {
        final repositories = await LocalRepositories.open(database: db);
        const place = PlaceIntent(
          kind: PlaceKind.specific,
          label: 'Cebu',
          latitude: 10.3,
          longitude: 123.9,
          source: 'osm/node/1',
        );
        const errand = Errand(
          id: 'e1',
          title: 'Buy food',
          place: 'Cebu',
          notes: 'Bring bag',
          placeIntent: place,
          durationMinutes: 30,
          durationConfirmed: true,
        );
        await repositories.today.save(
          DayPlan(errands: const [errand], from: 'Cebu', fromPlace: place),
        );
        await repositories.recurring.save([
          ErrandGroup(id: 'g1', name: 'Weekly', items: const [errand]),
        ]);
        await db.close();
        db = WaydayDatabase(NativeDatabase(file));
        final reopened = await LocalRepositories.open(database: db);
        expect(reopened.today.read().fromPlace.latitude, 10.3);
        expect(
          reopened.today.read().errands.single.placeIntent.longitude,
          123.9,
        );
        expect(reopened.today.read().errands.single.notes, 'Bring bag');
        expect(
          reopened.recurring.read().single.items.single.durationMinutes,
          30,
        );
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
