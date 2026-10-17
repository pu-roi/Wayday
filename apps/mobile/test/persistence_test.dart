import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/core/database/app_database.dart';
import 'package:wayday/core/database/local_workspace.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/places/presentation/saved_places_controller.dart';
import 'package:wayday/features/recurring/domain/errand_group.dart';
import 'package:wayday/features/recurring/presentation/recurring_controller.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'generated_migrations/schema.dart';

class FailableDatabase extends AppDatabase {
  FailableDatabase() : super(NativeDatabase.memory());
  bool failWrites = false;
  @override
  Future<void> writeDocuments(Map<String, String> documents) {
    if (failWrites) return Future.error(const FileSystemException('Disk full'));
    return super.writeDocuments(documents);
  }
}

void main() {
  test(
    'endpoints are session-only while errands and saved places survive restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'wayday-endpoints-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/personal.sqlite');
      var workspace = await LocalWorkspace.open(
        AppDatabase(NativeDatabase(file)),
      );
      final container = ProviderContainer(
        overrides: [localWorkspaceProvider.overrideWithValue(workspace)],
      );
      final today = container.read(todayProvider.notifier);
      const place = PlaceIntent(
        kind: PlaceKind.specific,
        label: 'Synthetic campus',
        latitude: 14.56,
        longitude: 121.075,
      );
      today.setEndpoint(start: true, value: place.label, place: place);
      today.setEndpoint(start: false, value: 'Synthetic home');
      today.add('Keep this errand');
      container.read(savedPlacesProvider.notifier).save(place);
      expect(container.read(todayProvider).from, place.label);
      await workspace.flush();
      final stored = jsonDecode(
        (await workspace.database.readDocuments())['day']!,
      )['value'];
      expect(stored['from'], isEmpty);
      expect(stored['to'], isEmpty);
      expect(stored['fromPlace']['latitude'], isNull);
      // Also verify older versions' persisted endpoints are ignored on hydration.
      final documents = await workspace.database.readDocuments();
      documents['day'] = jsonEncode({
        'format': 1,
        'value': container.read(todayProvider).toJson(),
      });
      await workspace.database.writeDocuments(documents);
      container.dispose();
      await workspace.close();
      workspace = await LocalWorkspace.open(AppDatabase(NativeDatabase(file)));
      expect(workspace.day.from, isEmpty);
      expect(workspace.day.to, isEmpty);
      expect(workspace.day.fromPlace.hasCoordinates, isFalse);
      expect(workspace.day.toPlace.hasCoordinates, isFalse);
      expect(workspace.day.errands.single.title, 'Keep this errand');
      expect(workspace.places.single.place.label, place.label);
      await workspace.close();
    },
  );
  test(
    'manual labels retain unresolved intent without invented coordinates',
    () {
      const errand = Errand(id: 'e', title: 'Visit', place: 'Office');
      expect(errand.placeIntent.label, 'Office');
      expect(errand.placeIntent.hasCoordinates, isFalse);
      final day = DayPlan(errands: [errand], from: 'Campus', to: 'Apartment');
      final restored = DayPlan.fromJson(day.toJson());
      expect(restored.fromPlace.label, 'Campus');
      expect(restored.toPlace.label, 'Apartment');
      expect(restored.errands.single.placeIntent.label, 'Office');
      final earlyDraft = errand.toJson();
      earlyDraft['placeIntent'] = const PlaceIntent().toJson();
      expect(Errand.fromJson(earlyDraft).placeIntent.label, 'Office');
    },
  );
  test('schema version 1 matches the committed migration snapshot', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(1);
    final database = AppDatabase(connection);
    await verifier.migrateAndValidate(database, 1);
    final workspace = await LocalWorkspace.open(database);
    expect(workspace.day.errands, isEmpty);
    await workspace.close();
  });

  test(
    'a failed section update rolls back the entire workspace transaction',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final workspace = await LocalWorkspace.open(database);
      final before = await database.readDocuments();
      await database.customStatement('''
      CREATE TRIGGER reject_groups BEFORE UPDATE ON workspace_documents
      WHEN NEW.key = 'groups' BEGIN SELECT RAISE(ABORT, 'test failure'); END
    ''');
      await expectLater(
        database.writeDocuments({'day': 'changed', 'groups': 'changed'}),
        throwsA(anything),
      );
      expect(await database.readDocuments(), before);
      await workspace.close();
    },
  );

  test(
    'a database from a newer app is rejected without resetting it',
    () async {
      final directory = await Directory.systemTemp.createTemp('wayday-future-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/personal.sqlite');
      final database = AppDatabase(NativeDatabase(file));
      final workspace = await LocalWorkspace.open(database);
      await database.customStatement('PRAGMA user_version = 99');
      await workspace.close();
      final olderApp = AppDatabase(NativeDatabase(file));
      await expectLater(LocalWorkspace.open(olderApp), throwsA(anything));
      await olderApp.close();
      expect(file.lengthSync(), greaterThan(0));
    },
  );
  test('pilot date follows Manila across a UTC date boundary', () {
    expect(pilotToday(DateTime.utc(2026, 10, 16, 17)), '2026-10-17');
  });
  test(
    'fresh schema seeds once; rapid edits, copies, dates and places survive reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp('wayday-test-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/personal.sqlite');
      var workspace = await LocalWorkspace.open(
        AppDatabase(NativeDatabase(file)),
      );
      var container = ProviderContainer(
        overrides: [localWorkspaceProvider.overrideWithValue(workspace)],
      );
      final today = container.read(todayProvider.notifier);
      today.clear();
      for (var i = 0; i < 25; i++) {
        today.add('Errand $i');
      }
      final firstId = container.read(todayProvider).errands.first.id;
      today.update(
        container
            .read(todayProvider)
            .errands
            .first
            .copyWith(
              notes: 'Vegetables\nFruit',
              durationMinutes: 35,
              durationConfirmed: true,
              confirmedFields: {'duration'},
              place: 'Home',
              placeIntent: const PlaceIntent(
                kind: PlaceKind.specific,
                label: 'Home',
                latitude: 14.57,
                longitude: 121.08,
              ),
            ),
      );
      today.setDate(DateTime(2026, 10, 20));
      today.setProfile(TravelProfile.bike);
      final recurring = container.read(recurringProvider.notifier);
      final group = ErrandGroup(
        id: recurring.reserveGroupId(),
        name: 'Test routine',
        items: [
          const Errand(id: 'a', title: 'A', notes: 'Private notes'),
          const Errand(id: 'b', title: 'B', afterErrandIds: ['a']),
        ],
      );
      recurring.save(group);
      expect(today.addGroup(groupId: group.id, errands: group.items), 2);
      final copies = container
          .read(todayProvider)
          .errands
          .where((e) => e.sourceGroupId == group.id)
          .toList();
      expect(copies[1].afterErrandIds, [copies[0].id]);
      today.update(copies.first.copyWith(notes: 'Independent copy'));
      container
          .read(savedPlacesProvider.notifier)
          .save(const PlaceIntent(label: 'Office'));
      final revision = container.read(todayProvider).revision;
      await workspace.flush();
      container.dispose();
      await workspace.close();

      workspace = await LocalWorkspace.open(AppDatabase(NativeDatabase(file)));
      container = ProviderContainer(
        overrides: [localWorkspaceProvider.overrideWithValue(workspace)],
      );
      final restored = container.read(todayProvider);
      expect(restored.errands.length, 27);
      expect(restored.errands.first.id, firstId);
      expect(restored.errands.first.notes, 'Vegetables\nFruit');
      expect(restored.errands.first.durationMinutes, 35);
      expect(restored.errands.first.placeIntent.latitude, 14.57);
      expect(restored.errands.first.inputText, 'Errand 0');
      expect(restored.date, '2026-10-20');
      expect(restored.timeZone, 'Asia/Manila');
      expect(restored.profile, TravelProfile.bike);
      expect(restored.revision, revision);
      expect(
        container.read(recurringProvider).last.items.first.notes,
        'Private notes',
      );
      expect(restored.errands[25].notes, 'Independent copy');
      expect(container.read(savedPlacesProvider).single.place.label, 'Office');
      expect(
        container
            .read(todayProvider.notifier)
            .addGroup(groupId: group.id, errands: group.items),
        0,
      );
      container.read(todayProvider.notifier).add('After restart');
      final ids = container.read(todayProvider).errands.map((e) => e.id);
      expect(ids.toSet().length, ids.length);
      container.read(todayProvider.notifier).clear();
      container.read(recurringProvider.notifier).restore([]);
      container
          .read(savedPlacesProvider.notifier)
          .remove(container.read(savedPlacesProvider).single.id);
      await workspace.flush();
      container.dispose();
      await workspace.close();

      workspace = await LocalWorkspace.open(AppDatabase(NativeDatabase(file)));
      expect(workspace.day.errands, isEmpty);
      expect(workspace.groups, isEmpty);
      expect(workspace.places, isEmpty);
      await workspace.close();
    },
  );

  test(
    'failed writes remain visible; retry saves the newest whole workspace',
    () async {
      final database = FailableDatabase();
      final workspace = await LocalWorkspace.open(database);
      database.failWrites = true;
      workspace.saveDay(workspace.day.copyWith(errands: []));
      workspace.saveGroups([]);
      await expectLater(workspace.flush(), throwsStateError);
      expect(workspace.lastError, isNotNull);
      expect(workspace.day.errands, isEmpty);
      database.failWrites = false;
      workspace.retry();
      await workspace.flush();
      expect(workspace.lastError, isNull);
      final documents = await database.readDocuments();
      expect(
        (jsonDecode(documents['day']!)['value']['errands'] as List),
        isEmpty,
      );
      expect((jsonDecode(documents['groups']!)['value'] as List), isEmpty);
      await workspace.close();
    },
  );

  test(
    'corrupt or incomplete data is preserved instead of replaced with examples',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      await database.writeDocuments({'day': '{broken'});
      await expectLater(
        LocalWorkspace.open(database),
        throwsA(isA<FormatException>()),
      );
      expect((await database.readDocuments())['day'], '{broken');
      await database.close();
    },
  );

  test('unknown document formats fail closed without data loss', () async {
    final database = AppDatabase(NativeDatabase.memory());
    await database.writeDocuments({'day': '{"format":99,"value":{}}'});
    await expectLater(
      LocalWorkspace.open(database),
      throwsA(isA<FormatException>()),
    );
    expect((await database.readDocuments()).length, 1);
    await database.close();
  });

  test('invalid coordinates and impossible persisted times are rejected', () {
    expect(
      () => PlaceIntent.fromJson({
        'kind': 'specific',
        'label': 'X',
        'latitude': 181,
        'longitude': 14,
      }),
      throwsFormatException,
    );
    final json = DayPlan(errands: []).toJson();
    json['date'] = '2026-02-30';
    expect(() => DayPlan.fromJson(json), throwsFormatException);
  });
}
