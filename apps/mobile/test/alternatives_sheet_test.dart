import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/domain/recommendation.dart';
import 'package:wayday/features/planning/presentation/place_alternatives_page.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'helpers/planning_fixtures.dart';

class Browser implements RecommendationDiscovery, AlternativeDiscovery {
  int calls = 0;
  bool fail = false;
  Completer<void>? gate;
  List<PlanCandidate> places(String id) => List.generate(
    18,
    (i) => PlanCandidate(
      key: 'saved:$id-$i',
      place: PlaceIntent(
        savedPlaceId: '$id-$i',
        kind: PlaceKind.specific,
        label: '$id branch $i',
        latitude: 14.58 + i * .001,
        longitude: 121.06,
      ),
      errandIds: {id},
      reason: 'Matches this errand.',
    ),
  );
  @override
  Future<void> preflight(int count) async {}
  @override
  RecommendationPlace? metadata(PlaceIntent p) => null;
  @override
  Future<RecommendationPlace?> hydrate(
    PlaceIntent p, {
    bool Function()? cancelled,
  }) async => null;
  @override
  Future<DiscoveryResult> discover(
    ErrandNeed n, {
    required String? polyline,
    required List<PlaceIntent> anchors,
    required int limit,
    required bool Function() cancelled,
  }) async => DiscoveryResult(places(n.id).take(limit).toList());
  @override
  Future<AlternativeBatch> moreAlternatives(
    ErrandNeed n, {
    required String? polyline,
    required List<PlaceIntent> anchors,
    required Set<String> excludedKeys,
    required int limit,
    required bool Function() cancelled,
  }) async {
    calls++;
    await gate?.future;
    if (fail) {
      throw const PlanningFailure(
        'Search temporarily unavailable.',
        kind: 'network',
      );
    }
    final remaining = places(
      n.id,
    ).where((p) => !excludedKeys.contains(p.key)).toList();
    return AlternativeBatch(
      remaining.take(limit).toList(),
      exhausted: remaining.length <= limit,
    );
  }
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Figtree')
      ..addFont(rootBundle.load('assets/fonts/Figtree.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  test(
    'browsing coalesces taps and caps the independent pool at twelve',
    () async {
      final browser = Browser(), roads = Roads();
      final source = fixture().copyWith(
        errands: fixture().errands
            .map((e) => e.copyWith(placeIntent: const PlaceIntent()))
            .toList(),
      );
      final model = PlanningController(
        source,
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
        discovery: browser,
      );
      addTearDown(model.dispose);
      addTearDown(roads.client.close);
      await model.understand();
      model.found('a', browser.places('a').take(3).toList());
      browser.gate = Completer<void>();
      final first = model.showMoreAlternatives('a');
      await model.showMoreAlternatives('a');
      expect(browser.calls, 1);
      browser.gate!.complete();
      await first;
      browser.gate = null;
      await model.showMoreAlternatives('a');
      await model.showMoreAlternatives('a');
      await model.showMoreAlternatives('a');
      expect(browser.calls, 3);
      expect(model.alternativesFor('a').values.length, 12);
      expect(model.alternativesFor('a').exhausted, isTrue);
      expect(model.candidates['a']!.length, 3);
    },
  );
  for (final variant in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'content-sized sheet retains suggestions at ${variant.$1} text ${variant.$2}',
      (tester) async {
        tester.view.physicalSize = Size(variant.$1, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final browser = Browser(), roads = Roads();
        final source = fixture().copyWith(
          errands: fixture().errands
              .map((e) => e.copyWith(placeIntent: const PlaceIntent()))
              .toList(),
        );
        final model = PlanningController(
          source,
          Interpreter(),
          roads,
          MemoryItineraryRepository(),
          discovery: browser,
        );
        addTearDown(model.dispose);
        addTearDown(roads.client.close);
        await model.understand();
        model.found('a', browser.places('a').take(3).toList());
        model.found('b', browser.places('b').take(3).toList());
        final capture = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              theme: buildTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(variant.$2)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      showDragHandle: true,
                      builder: (_) =>
                          PlaceAlternativesPage(model: model, errandId: 'a'),
                    ),
                    child: const Text('Open alternatives'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open alternatives'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Errand 1 of 2'), findsOneWidget);
        expect(find.text('Current place'), findsOneWidget);
        expect(
          tester.getSize(find.byType(PlaceAlternativesPage)).height,
          lessThanOrEqualTo(844 * .9),
        );
        if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(find.byKey(capture))
                .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final dir = Directory('../../.tools/alternatives-screenshots')
              ..createSync(recursive: true);
            File(
              '${dir.path}/sheet-${variant.$1.toInt()}-${variant.$2}.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.scrollUntilVisible(
          find.text('Show more suggestions'),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Show more suggestions'));
        await tester.pumpAndSettle();
        expect(
          model.alternativesFor('a').values.map((p) => p.place.savedPlaceId),
          ['a-0', 'a-1', 'a-2', 'a-3', 'a-4', 'a-5'],
        );
        await tester.scrollUntilVisible(
          find.text('Show more suggestions'),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        final savedOffset = tester
            .widget<ListView>(
              find.byKey(const PageStorageKey('alternatives-a')),
            )
            .controller!
            .offset;
        expect(savedOffset, greaterThan(0));
        await tester.tap(find.byTooltip('Next errand'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Errand 2 of 2'), findsOneWidget);
        await tester.tap(find.byTooltip('Previous errand'));
        await tester.pumpAndSettle();
        expect(model.alternativesFor('a').values.length, 6);
        expect(
          tester
              .widget<ListView>(
                find.byKey(const PageStorageKey('alternatives-a')),
              )
              .controller!
              .offset,
          closeTo(savedOffset, 1),
        );
        browser.fail = true;
        await tester.scrollUntilVisible(
          find.text('Show more suggestions'),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Show more suggestions'));
        await tester.pumpAndSettle();
        expect(model.alternativesFor('a').values.length, 6);
        expect(find.text('Search temporarily unavailable.'), findsOneWidget);
        browser.fail = false;
        await tester.tap(find.text('Retry loading suggestions'));
        await tester.pumpAndSettle();
        expect(model.alternativesFor('a').values.length, 9);
        await tester.tap(find.byTooltip('Close place alternatives'));
        await tester.pumpAndSettle();
        expect(find.text('Open alternatives'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
