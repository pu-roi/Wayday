import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/core/data/local_repositories.dart';
import 'package:wayday/core/data/wayday_database.dart' hide SavedPlace;
import 'package:wayday/core/widgets/place_picker.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/places/data/saved_place_repository.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/profile/presentation/profile_view.dart';
import 'package:wayday/features/today/domain/day.dart';

const original = SavedPlace(
  id: 'one',
  place: PlaceIntent(
    kind: PlaceKind.specific,
    label: 'Home',
    latitude: 14,
    longitude: 121,
    address: 'Old address',
    source: 'osm/1',
  ),
);
const other = SavedPlace(
  id: 'two',
  place: PlaceIntent(
    kind: PlaceKind.specific,
    label: 'Shop',
    latitude: 15,
    longitude: 121,
  ),
);

class FailingRepository implements SavedPlaceRepository {
  bool failRead = true;
  final inner = MemorySavedPlaceRepository();
  @override
  Future<List<SavedPlace>> read() async {
    if (failRead) throw StateError('read');
    return inner.read();
  }

  @override
  Future<void> add(SavedPlace place) => inner.add(place);
  @override
  Future<void> update(SavedPlace place) async => throw StateError('save');
  @override
  Future<void> delete(String id) async => throw StateError('delete');
}

Widget app(SavedPlaceRepository? repository, {double scale = 1}) =>
    ProviderScope(
      overrides: [
        savedPlaceRepositoryProvider.overrideWithValue(repository),
        placeMapBuilderProvider.overrideWithValue(
          (request) => TextButton(
            onPressed: () => request.onSelect!(14.5, 121.5),
            child: const Text('Move map'),
          ),
        ),
      ],
      child: MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const ProfileView(),
      ),
    );

Future<void> openPlaces(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Saved places'), 200);
  await tester.ensureVisible(find.text('Saved places'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Saved places'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('place picker offers the updated saved place', (tester) async {
    final db = WaydayDatabase(NativeDatabase.memory());
    final local = await LocalRepositories.open(database: db);
    await local.savedPlaces.add(original);
    await local.savedPlaces.update(
      const SavedPlace(
        id: 'one',
        place: PlaceIntent(
          kind: PlaceKind.specific,
          label: 'New home',
          latitude: 14.5,
          longitude: 121.5,
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localRepositoriesProvider.overrideWithValue(local)],
        child: MaterialApp(
          theme: buildTheme(),
          home: const PlacePicker(title: 'Starting point', initial: ''),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place-name')));
    await tester.pumpAndSettle();
    expect(find.text('New home'), findsOneWidget);
    await tester.tap(find.text('New home'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm location'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });

  test(
    'SQLite update and delete survive reopening without changing other entries or snapshots',
    () async {
      final dir = await Directory.systemTemp.createTemp('wayday-saved-');
      final file = File('${dir.path}/places.sqlite');
      var db = WaydayDatabase(NativeDatabase(file));
      try {
        var repo = SqliteSavedPlaceRepository(db);
        await repo.add(original);
        await repo.add(other);
        final snapshot = original.intent;
        final local = await LocalRepositories.open(database: db);
        await local.today.save(
          DayPlan(
            errands: [
              Errand(
                id: 'e',
                title: 'Visit',
                place: snapshot.label,
                placeIntent: snapshot,
              ),
            ],
            from: snapshot.label,
            fromPlace: snapshot,
          ),
        );
        await repo.update(
          const SavedPlace(
            id: 'one',
            place: PlaceIntent(
              kind: PlaceKind.specific,
              label: 'New home',
              latitude: 16,
              longitude: 122,
            ),
          ),
        );
        await db.close();
        db = WaydayDatabase(NativeDatabase(file));
        repo = SqliteSavedPlaceRepository(db);
        expect((await repo.read()).first.place.label, 'New home');
        expect(snapshot.label, 'Home');
        expect(snapshot.latitude, 14);
        await repo.delete('one');
        await db.close();
        db = WaydayDatabase(NativeDatabase(file));
        expect((await SqliteSavedPlaceRepository(db).read()).single.id, 'two');
        final reopened = await LocalRepositories.open(database: db);
        expect(reopened.today.read().fromPlace.latitude, 14);
        expect(reopened.today.read().errands.single.placeIntent.label, 'Home');
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'profile edits, cancels and deletes without changing another place',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = MemorySavedPlaceRepository();
      await repo.add(original);
      await repo.add(other);
      await tester.pumpWidget(app(repo, scale: 1.3));
      await openPlaces(tester);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Changed');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect((await repo.read()).first.place.label, 'Home');
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'New home');
      await tester.ensureVisible(find.text('Change location'));
      await tester.tap(find.text('Change location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move map'));
      await tester.pump();
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      final edited = (await repo.read()).first;
      expect(edited.id, 'one');
      expect(edited.place.label, 'New home');
      expect(edited.place.latitude, 14.5);
      expect(edited.place.address, isNull);
      expect(edited.place.source, 'manual');
      await tester.tap(find.text('New home'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete saved place'));
      await tester.tap(find.text('Delete saved place'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await repo.read()).length, 2);
      await tester.tap(find.text('Delete saved place'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect((await repo.read()).single.id, 'two');
      expect(find.text('Shop'), findsOneWidget);
    },
  );

  testWidgets('empty, unavailable, retry and save failures are visible', (
    tester,
  ) async {
    await tester.pumpWidget(app(null));
    await openPlaces(tester);
    expect(find.textContaining('unavailable on this device'), findsOneWidget);
    final repo = FailingRepository();
    await repo.add(original);
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    // Replace the complete tree so Profile becomes the active route again.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(repo));
    await openPlaces(tester);
    expect(find.text('Saved places could not be loaded.'), findsOneWidget);
    repo.failRead = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Draft');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save changes. Try again.'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(MemorySavedPlaceRepository()));
    await openPlaces(tester);
    expect(find.textContaining('No saved places yet'), findsOneWidget);
  });
}
