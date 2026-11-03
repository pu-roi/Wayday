import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:wayday/app/wayday_app.dart';
import 'package:wayday/core/data/persist_safely.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/maps/presentation/map_platform.dart';
import 'package:wayday/features/places/data/combined_place_search.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'package:wayday/features/planning/presentation/saved_plan_view.dart';

class MapLifetime {
  int created = 0, disposed = 0;
}

class PendingTrips extends MemoryItineraryRepository {
  Completer<AcceptedItinerary?>? pending;
  @override
  Future<AcceptedItinerary?> read() => pending?.future ?? super.read();
}

class RetainedMapDouble extends StatefulWidget {
  const RetainedMapDouble(this.lifetime, {super.key});
  final MapLifetime lifetime;
  @override
  State<RetainedMapDouble> createState() => _MapDoubleState();
}

class _MapDoubleState extends State<RetainedMapDouble> {
  @override
  void initState() {
    super.initState();
    widget.lifetime.created++;
  }

  @override
  void dispose() {
    widget.lifetime.disposed++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Colors.blueGrey,
    child: Text('Retained map fixture'),
  );
}

Future<ProviderContainer> mountTabs(
  WidgetTester tester,
  MapLifetime lifetime, {
  DateTime Function()? clock,
  DayPlan? day,
  MemoryItineraryRepository? trips,
  PlaceMapBuilder? mapBuilder,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      mapPlatformSupportedProvider.overrideWithValue(true),
      placeMapBuilderProvider.overrideWithValue(
        mapBuilder ?? (_) => RetainedMapDouble(lifetime),
      ),
      dayRepositoryProvider.overrideWithValue(
        MemoryDayRepository(initialData: day),
      ),
      itineraryRepositoryProvider.overrideWithValue(
        trips ?? MemoryItineraryRepository(),
      ),
      combinedPlaceSearchProvider.overrideWithValue(
        CombinedPlaceSearch(
          [],
          QuotaLedger(read: () async => null, write: (_) async {}),
        ),
      ),
      if (clock != null) todayClockProvider.overrideWithValue(clock),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const WaydayApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> tab(WidgetTester tester, String name) async {
  final bar = find.byType(NavigationBar);
  await tester.tap(find.descendant(of: bar, matching: find.text(name)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Recurring keeps its selected inner tab across main tabs', (
    tester,
  ) async {
    await mountTabs(tester, MapLifetime());
    await tab(tester, 'Recurring');
    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();
    expect(find.text('No saved trips yet.'), findsOneWidget);
    await tab(tester, 'Profile');
    await tab(tester, 'Recurring');
    expect(find.text('No saved trips yet.'), findsOneWidget);
    expect(find.byTooltip('New recurring list'), findsNothing);
    await tab(tester, 'Recurring');
    expect(find.text('No saved trips yet.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tab changes retain the map until the shell is removed', (
    tester,
  ) async {
    final lifetime = MapLifetime();
    final container = await mountTabs(tester, lifetime);
    for (var pass = 0; pass < 3; pass++) {
      for (final name in ['Recurring', 'Profile', 'Settings']) {
        await tab(tester, name);
        expect(find.text('Retained map fixture'), findsNothing);
        expect(lifetime.disposed, 0);
        await tab(tester, 'Today');
        expect(lifetime.created, 1);
      }
    }
    container.read(routerProvider).go('/profile');
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/today');
    await tester.pumpAndSettle();
    expect(lifetime.created, 1);
    await tester.pumpWidget(const SizedBox());
    expect(lifetime.disposed, 1);
  });

  testWidgets('Today keeps draft, disclosure and scroll without hidden focus', (
    tester,
  ) async {
    final lifetime = MapLifetime();
    await mountTabs(tester, lifetime);
    await tester.tap(find.text('Add errand'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('quick-add')),
      'Unfinished Taglish errand',
    );
    await tab(tester, 'Recurring');
    expect(tester.testTextInput.isVisible, isFalse);
    await tab(tester, 'Today');
    final field = tester.widget<TextField>(find.byKey(const Key('quick-add')));
    expect(field.controller!.text, 'Unfinished Taglish errand');
    expect(field.focusNode!.hasFocus, isFalse);
    await tester.scrollUntilVisible(
      find.text('Saved on this device.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byType(Scaffold).last,
      matching: find.byType(ListView),
    );
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: list.first, matching: find.byType(Scrollable)).first,
    );
    final offset = scroll.position.pixels;
    await tab(tester, 'Profile');
    await tab(tester, 'Today');
    expect(scroll.position.pixels, closeTo(offset, 1));
    await tab(tester, 'Today');
    expect(scroll.position.pixels, closeTo(offset, 1));
    expect(lifetime.created, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('banner and rail changes do not replace the map', (tester) async {
    final lifetime = MapLifetime();
    final container = await mountTabs(tester, lifetime);
    container.read(saveFailuresProvider.notifier).failed('Fixture', () {});
    await tester.pumpAndSettle();
    expect(lifetime.created, 1);
    container.read(saveFailuresProvider.notifier).saved('Fixture');
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1024, 900);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(lifetime.created, 1);
    expect(lifetime.disposed, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('returning to Today refreshes only eligible empty dates', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 2, 15, 59);
    final container = await mountTabs(
      tester,
      MapLifetime(),
      clock: () => now,
      day: DayPlan(errands: [], date: '2026-11-02'),
    );
    await tab(tester, 'Settings');
    now = DateTime.utc(2026, 11, 2, 16, 1);
    await tester.pump(const Duration(minutes: 2));
    expect(container.read(todayProvider).date, '2026-11-02');
    await tab(tester, 'Today');
    expect(container.read(todayProvider).date, '2026-11-03');
    container.read(todayProvider.notifier).setDate(DateTime(2026, 11, 5));
    await tab(tester, 'Profile');
    now = DateTime.utc(2026, 11, 3, 16, 1);
    await tab(tester, 'Today');
    expect(container.read(todayProvider).date, '2026-11-05');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'returning preserves an unfinished draft date and root editor Back',
    (tester) async {
      var now = DateTime.utc(2026, 11, 2, 15, 59);
      final lifetime = MapLifetime();
      final container = await mountTabs(
        tester,
        lifetime,
        clock: () => now,
        day: DayPlan(errands: [], date: '2026-11-02'),
      );
      await tester.tap(find.text('Add errand'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('quick-add')), 'Draft only');
      await tab(tester, 'Profile');
      now = DateTime.utc(2026, 11, 2, 16, 1);
      await tab(tester, 'Today');
      expect(container.read(todayProvider).date, '2026-11-02');
      await tester.tap(find.text('Done adding'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('trip-date')),
        -160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('trip-date')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(lifetime.created, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('late recovery read cannot refresh a hidden Today date', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 2, 15, 59);
    final trips = PendingTrips();
    final container = await mountTabs(
      tester,
      MapLifetime(),
      trips: trips,
      clock: () => now,
      day: DayPlan(errands: [], date: '2026-11-02'),
    );
    await tab(tester, 'Profile');
    trips.pending = Completer<AcceptedItinerary?>();
    container.invalidate(savedItineraryProvider);
    now = DateTime.utc(2026, 11, 2, 16, 1);
    await tab(tester, 'Today');
    await tab(tester, 'Recurring');
    trips.pending!.complete(null);
    await tester.pumpAndSettle();
    expect(container.read(todayProvider).date, '2026-11-02');
    await tab(tester, 'Today');
    expect(container.read(todayProvider).date, '2026-11-03');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'background resume preserves map and refreshes only visible dates',
    (tester) async {
      var now = DateTime.utc(2026, 11, 2, 15, 59);
      final lifetime = MapLifetime();
      final container = await mountTabs(
        tester,
        lifetime,
        clock: () => now,
        day: DayPlan(errands: [], date: '2026-11-02'),
      );
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      now = DateTime.utc(2026, 11, 2, 16, 1);
      await tester.pump(const Duration(minutes: 2));
      expect(container.read(todayProvider).date, '2026-11-02');
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).date, '2026-11-03');
      expect(lifetime.created, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'an unavailable map survives tabs and recreates only on explicit Retry',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final hybrid = MapLibreMap.useHybridComposition;
      MapLibreMap.useHybridComposition = false;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var creates = 0;
      final channels = <MethodChannel>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          creates++;
          final id = (call.arguments as Map)['id'];
          final channel = MethodChannel('plugins.flutter.io/maplibre_gl_$id');
          channels.add(channel);
          // The map exists but never receives a successful style-load event.
          messenger.setMockMethodCallHandler(channel, (_) async => null);
          return 1;
        }
        return null;
      });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        MapLibreMap.useHybridComposition = hybrid;
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      await mountTabs(
        tester,
        MapLifetime(),
        mapBuilder: (request) => PlaceMap(request: request),
      );
      await tester.pump(const Duration(seconds: 16));
      expect(creates, 1);
      await tab(tester, 'Recurring');
      await tab(tester, 'Today');
      expect(creates, 1);
      await tester.scrollUntilVisible(
        find.text('Retry'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(creates, 2);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
      expect(tester.takeException(), isNull);
    },
  );
}
