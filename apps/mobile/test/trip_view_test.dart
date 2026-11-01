import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/presentation/trip_view.dart';
import 'trip_navigation_test.dart' show FakeNavigationDriver;
import 'trip_session_test.dart' show FakeTripMap, tripSession, tripFixture;

Future<void> mountTrip(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool shared = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final initial = tripFixture();
  final plan = shared
      ? initial
      : AcceptedItinerary(
          day: initial.day,
          stops: [
            ItineraryStop(initial.stops.first.place, ['a']),
          ],
          acceptedAt: DateTime.now(),
        );
  final session = tripSession(FakeNavigationDriver(), plan: plan);
  final map = FakeTripMap();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('trip-capture'),
          child: TripView(
            initial: plan,
            session: session,
            mapBuilder: (_, ready, position) {
              ready(map);
              return const ColoredBox(
                key: ValueKey('fixture-map'),
                color: Color(0xffe5f0f9),
                child: Center(child: Text('Navigation map · fixture')),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(session.active, isTrue);
}

void main() {
  testWidgets('only the current errand is shown, completion reveals the next', (
    tester,
  ) async {
    await mountTrip(tester, shared: true);
    expect(find.text('Grocery'), findsOneWidget);
    expect(
      find.text('Eat pares kasama ang girlfriend ko pagkatapos mamili'),
      findsNothing,
    );
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await tester.tap(find.text('Grocery'));
    await tester.pumpAndSettle();
    expect(find.text('Grocery'), findsNothing);
    expect(
      find.text('Eat pares kasama ang girlfriend ko pagkatapos mamili'),
      findsOneWidget,
    );
    expect(find.byType(CheckboxListTile), findsOneWidget);
  });
  setUpAll(() async {
    await (FontLoader(
      'Figtree',
    )..addFont(rootBundle.load('assets/fonts/Figtree.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('compact checklist, whole trip and info retain navigation', (
    tester,
  ) async {
    await mountTrip(tester);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.text('Grocery'), findsOneWidget);
    expect(find.textContaining('Traffic rerouting'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('trip-checklist'))).height,
      lessThan(125),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('fixture-map'))).height,
      greaterThan(600),
    );
    await tester.tap(find.text('Whole trip'));
    await tester.pump();
    await tester.tap(find.byTooltip('Trip options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Navigation info'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Traffic rerouting'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final data in [
    (const Size(390, 844), 1.0),
    (const Size(320, 740), 2.0),
    (const Size(740, 390), 1.3),
  ]) {
    testWidgets('trip controls wrap at ${data.$1} / ${data.$2}', (
      tester,
    ) async {
      await mountTrip(tester, size: data.$1, textScale: data.$2, shared: true);
      await tester.tap(find.text('Grocery'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(find.byTooltip('Trip options'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('fixture-map'))).height,
        greaterThan(150),
      );
      final semantics = tester.ensureSemantics();
      expect(find.byType(Checkbox), findsOneWidget);
      semantics.dispose();
      expect(tester.takeException(), isNull);
      if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('trip-capture')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(
            '../../.tools/navigation-screenshots',
          ).create(recursive: true);
          await File(
            '../../.tools/navigation-screenshots/trip-${data.$1.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
