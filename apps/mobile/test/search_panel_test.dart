import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/places/data/combined_place_search.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/places/data/google_search.dart';
import 'package:wayday/features/places/presentation/google_search_view.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/places/domain/place_search.dart';
import 'package:wayday/features/places/presentation/place_search_controller.dart';
import 'package:wayday/features/places/presentation/place_search_panel.dart';
import 'place_search_controller_test.dart' show TestAdapter, TestLedger;
import 'search_ranking_test.dart' show place;

void main() {
  testWidgets(
    'shared search chrome keeps native identity and request count through keyboard and text scaling',
    (tester) async {
      final font = FontLoader('Figtree')
        ..addFont(rootBundle.load('assets/fonts/Figtree.ttf'));
      await font.load();
      tester.view.physicalSize = const Size(360, 736);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var creates = 0, loads = 0, disposals = 0;
      final channels = <MethodChannel>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          creates++;
          final id = (call.arguments as Map)['id'];
          final channel = MethodChannel('wayday/google_places/$id');
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'search') {
              loads++;
              return {'count': 2};
            }
            return null;
          });
        }
        if (call.method == 'dispose') disposals++;
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      final now = tester.binding.clock.now;
      final ledger = QuotaLedger(
        now: now,
        read: () async => null,
        write: (_) async {},
      );
      final google = GoogleSearchService(ledger, now: now);
      final others = CombinedPlaceSearch([], ledger, now: now);
      final source = SearchSourceChoice();
      final c =
          PlaceSearchController(others, google: google, sourceChoice: source)
            ..updateDeviceLocation(const SearchOrigin.device(14.58, 121.05))
            ..change('Megamall');
      addTearDown(() {
        c.dispose();
        google.dispose();
        others.dispose();
        source.dispose();
      });
      Widget app(double scale) => MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            height: 568,
            child: ListenableBuilder(
              listenable: c,
              builder: (context, child) => PlaceSearchPanel(
                search: c,
                saved: const [],
                onUseLocation: () {},
                onSelect: (_) {},
                onNameOnly: () {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(1));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(creates, 1);
      expect(loads, 1);
      final native = tester.state<GoogleSearchViewState>(
        find.byType(GoogleSearchView),
      );
      final selected = tester.widget<Text>(find.text('Google'));
      expect(selected.style!.decoration, TextDecoration.underline);
      expect(find.text('Search this area').hitTestable(), findsOneWidget);
      expect(find.text('Places').hitTestable(), findsOneWidget);
      expect(find.text('Search original text').hitTestable(), findsOneWidget);
      expect(
        find.text('Saves this name without a map pin.').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Back to map').hitTestable(), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpWidget(app(1.6));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Search options'), findsNothing);
      expect(find.text('Saves this name without a map pin.'), findsOneWidget);
      expect(tester.state(find.byType(GoogleSearchView)), same(native));
      expect(
        tester.getSize(find.byType(GoogleSearchView)).height,
        greaterThan(140),
      );
      tester.view.resetViewInsets();
      await tester.pumpWidget(app(1));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(GoogleSearchView)), same(native));
      expect(creates, 1);
      expect(loads, 1);
      expect(disposals, 0);
      expect(c.query, 'Megamall');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(disposals, 1);
    },
  );
  testWidgets(
    'a held result stays in place and selects its original record after a late batch',
    (tester) async {
      final later = Completer<List<PlaceSearchResult>>();
      final clock = tester.binding.clock.now;
      final first = place('tenant', 'Megamall Building A', 14.58);
      final service = CombinedPlaceSearch(
        [
          TestAdapter('geoapify', (_) async => [first]),
          TestAdapter('locationiq', (_) => later.future),
        ],
        TestLedger(clock).ledger,
        now: clock,
      );
      final c = PlaceSearchController(service)..change('Megamall');
      PlaceIntent? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: c,
              builder: (context, child) => PlaceSearchPanel(
                search: c,
                saved: const [],
                onSelect: (p) => selected = p,
                onNameOnly: () {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      final row = find.text('Megamall Building A');
      final position = tester.getTopLeft(row);
      final finger = await tester.startGesture(tester.getCenter(row));
      await tester.pump();
      later.complete([place('mall', 'SM Megamall', 14.6)]);
      await tester.pump();
      expect(tester.getTopLeft(row), position);
      expect(find.text('Updated results'), findsOneWidget);
      await finger.up();
      await tester.pump();
      expect(selected!.source, 'tenant');
      expect(selected!.latitude, 14.58);
      await tester.tap(find.text('Updated results'));
      await tester.pump();
      expect(c.results.first.sourceId, 'mall');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      service.dispose();
    },
  );
  testWidgets(
    'small screen and keyboard keep results and provider credit reachable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = CombinedPlaceSearch(
        [],
        QuotaLedger(read: () async => null, write: (_) async {}),
      );
      final c = PlaceSearchController(service);
      addTearDown(() {
        c.dispose();
        service.dispose();
      });
      c.query = 'Public market';
      c.results = [
        const PlaceSearchResult(
          name: 'Pampublikong Pamilihan at Sentro ng mga Tindahan',
          latitude: 14.5,
          longitude: 121,
          sourceId: 'osm/node/1',
          provider: 'geoapify',
          attributions: [
            '© OpenStreetMap contributors',
            'Powered by Geoapify',
            'Search by LocationIQ.com',
          ],
        ),
      ];
      PlaceIntent? chosen;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: const EdgeInsets.only(bottom: 300),
              textScaler: TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: PlaceSearchPanel(
              search: c,
              saved: const [],
              onSelect: (v) => chosen = v,
              onNameOnly: () {},
              onClose: () {},
            ),
          ),
        ),
      );
      for (final credit in [
        '© OpenStreetMap contributors',
        'Powered by Geoapify',
        'Search by LocationIQ.com',
      ]) {
        await tester.scrollUntilVisible(
          find.text(credit),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(credit), findsOneWidget);
      }
      final result = find.text(
        'Pampublikong Pamilihan at Sentro ng mga Tindahan',
      );
      await tester.scrollUntilVisible(
        result,
        -100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(result);
      await tester.pump();
      expect(chosen!.provider, 'geoapify');
      expect(chosen!.attributions.length, 3);
      expect(chosen!.latitude, 14.5);
      expect(tester.takeException(), isNull);
    },
  );
}
