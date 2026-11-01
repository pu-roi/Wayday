import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/wayday_app.dart';
import 'package:wayday/features/maps/presentation/regional_map.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/saved_plan_view.dart';
import 'package:wayday/features/planning/presentation/finish_trip.dart';
import 'package:wayday/features/planning/presentation/current_trip_section.dart';
import 'package:wayday/features/planning/presentation/trip_view.dart';
import 'trip_navigation_test.dart' show FakeNavigationDriver;
import 'trip_session_test.dart' show tripSession, FakeTripMap;
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'trip_session_test.dart' show tripFixture;

class FinishRepository extends MemoryItineraryRepository {
  bool fail = false;
  Completer<void>? gate;
  int finishes = 0;
  @override
  Future<DayPlan> finish(
    String runId, {
    required DayRepository today,
    required int expectedRevision,
    required bool Function() stillCurrent,
    required DateTime now,
  }) async {
    finishes++;
    await gate?.future;
    if (fail) throw StateError('fixture storage failure');
    return super.finish(
      runId,
      today: today,
      expectedRevision: expectedRevision,
      stillCurrent: stillCurrent,
      now: now,
    );
  }
}

Future<(ProviderContainer, FinishRepository)> launchCurrent(
  WidgetTester tester, {
  bool complete = true,
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final trip = complete
      ? tripFixture().complete('a').complete('b')
      : tripFixture();
  final repository = FinishRepository();
  await repository.save(trip);
  final container = ProviderContainer(
    overrides: [
      mapPlatformSupportedProvider.overrideWithValue(false),
      itineraryRepositoryProvider.overrideWithValue(repository),
      dayRepositoryProvider.overrideWithValue(
        MemoryDayRepository(initialData: trip.day),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const RepaintBoundary(
        key: ValueKey('current-trip-capture'),
        child: WaydayApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, repository);
}

Future<void> openFinish(WidgetTester tester) async {
  await tester.tap(find.text('Resume trip'));
  await tester.pumpAndSettle();
  final finish = find.text('Finish trip');
  await tester.scrollUntilVisible(finish, 180);
  await tester.pumpAndSettle();
  await tester.tap(finish);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'direct navigation Finish returns to Today with a finished result',
    (tester) async {
      final (container, repo) = await launchCurrent(tester);
      final trip = (await repo.read())!;
      final result =
          Navigator.of(
            tester.element(find.text('Today').first),
            rootNavigator: true,
          ).push<TripExit>(
            MaterialPageRoute(
              builder: (_) => TripView(
                initial: trip,
                session: tripSession(
                  FakeNavigationDriver(),
                  plan: trip,
                  save: repo.updateProgress,
                ),
                mapBuilder: (_, ready, position) {
                  ready(FakeTripMap());
                  return const SizedBox.expand();
                },
              ),
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('Final destination'), findsOneWidget);
      await tester.tap(find.text('Finish trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish and clear Today'));
      await tester.pumpAndSettle();
      expect((await result)!.finished, isTrue);
      expect(container.read(todayProvider).errands, isEmpty);
      expect(find.text('Resume trip'), findsNothing);
    },
  );
  setUpAll(() async {
    await (FontLoader(
      'Figtree',
    )..addFont(rootBundle.load('assets/fonts/Figtree.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets(
    'top recovery opens summary; cancelling preserves, confirmed finish clears Today',
    (tester) async {
      final (container, repo) = await launchCurrent(tester);
      expect(find.text('Current trip'), findsOneWidget);
      expect(find.text('2 of 2 errands completed'), findsOneWidget);
      expect(find.textContaining('View saved plan'), findsNothing);
      expect(
        tester.getTopLeft(find.byType(CurrentTripSection)).dy,
        lessThan(tester.getTopLeft(find.text('Errands')).dy),
      );
      await openFinish(tester);
      expect(find.text('Finish trip and clear Today?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.finishes, 0);
      expect(container.read(todayProvider).errands.length, 2);
      await tester.tap(find.text('Finish trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish and clear Today'));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Resume trip'), findsNothing);
      expect(await repo.read(), isNull);
      final today = container.read(todayProvider);
      expect(today.errands, isEmpty);
      expect(today.from, isEmpty);
      expect(today.to, isEmpty);
      expect(today.departure, 510);
      expect(today.deadline, 1080);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Today changed while confirming requires a new confirmation', (
    tester,
  ) async {
    final (container, repo) = await launchCurrent(tester);
    await openFinish(tester);
    container.read(todayProvider.notifier).add('New errand');
    await tester.tap(find.text('Finish and clear Today'));
    await tester.pumpAndSettle();
    expect(repo.finishes, 0);
    expect(find.textContaining('Today changed.'), findsOneWidget);
    await tester.tap(find.text('Retry finishing trip'));
    await tester.pumpAndSettle();
    expect(find.text('Finish trip and clear Today?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(todayProvider).errands.length, 3);
  });
  testWidgets(
    'finish failure keeps both records and explicit retry completes once',
    (tester) async {
      final (container, repo) = await launchCurrent(tester);
      repo.fail = true;
      await openFinish(tester);
      await tester.tap(find.text('Finish and clear Today'));
      await tester.pumpAndSettle();
      expect(find.text('Retry finishing trip'), findsOneWidget);
      expect(await repo.read(), isNotNull);
      expect(container.read(todayProvider).errands.length, 2);
      repo.fail = false;
      repo.gate = Completer();
      await tester.tap(find.text('Retry finishing trip'));
      await tester.pump();
      expect(find.text('Finishing trip…'), findsOneWidget);
      expect(repo.finishes, 2);
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(await repo.read(), isNull);
      expect(container.read(todayProvider).errands, isEmpty);
    },
  );
  testWidgets(
    'unfinished trip Back retains recovery and does not offer finish',
    (tester) async {
      final (_, repo) = await launchCurrent(tester, complete: false);
      await tester.tap(find.text('Resume trip'));
      await tester.pumpAndSettle();
      expect(find.text('Finish trip'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Resume trip'), findsOneWidget);
      expect(await repo.read(), isNotNull);
    },
  );
  for (final variant in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'recovery and confirmation at ${variant.$1} scale ${variant.$2}',
      (tester) async {
        await launchCurrent(
          tester,
          size: Size(variant.$1, 844),
          scale: variant.$2,
        );
        if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(
                  find.byKey(const ValueKey('current-trip-capture')),
                )
                .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final dir = Directory('../../.tools/current-trip-screenshots')
              ..createSync(recursive: true);
            File(
              '${dir.path}/today-${variant.$1.toInt()}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await openFinish(tester);
        expect(find.text('Finish and clear Today'), findsOneWidget);
        await tester.ensureVisible(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
