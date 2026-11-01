import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/places/data/combined_place_search.dart';
import 'package:wayday/features/places/data/google_pin_cache.dart';
import 'package:wayday/features/places/data/google_search.dart';
import 'package:wayday/features/places/domain/place_search.dart';
import 'package:wayday/features/places/presentation/place_search_controller.dart';
import 'package:wayday/features/places/presentation/google_search_view.dart';

/// One standard visible Google place binding and a map-only Navigation SDK view.
/// No Gemini call, route matrix, guidance destination or device GPS is used.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Places candidate metadata coexists with the Navigation map implementation',
    (tester) async {
      final container = ProviderContainer();
      final choice = SearchSourceChoice();
      final search = PlaceSearchController(
        container.read(combinedPlaceSearchProvider),
        google: container.read(googleSearchProvider),
        sourceChoice: choice,
        pins: container.read(googlePinCacheProvider),
      );
      expect(search.googleSupported, isTrue);
      search.open();
      search.updateArea(const SearchArea(14.5849, 121.0568, 13));
      nav.GoogleMapViewController? map;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildTheme(),
            home: Scaffold(
              appBar: AppBar(
                title: const Text('Isolated Google compatibility check'),
              ),
              body: Column(
                children: [
                  SizedBox(
                    height: 220,
                    child: nav.GoogleMapsMapView(
                      onViewCreated: (value) {
                        map = value;
                      },
                      initialMapToolbarEnabled: false,
                      initialMapColorScheme: nav.MapColorScheme.light,
                      initialCameraPosition: const nav.CameraPosition(
                        target: nav.LatLng(
                          latitude: 14.5849,
                          longitude: 121.0568,
                        ),
                        zoom: 13,
                      ),
                    ),
                  ),
                  Expanded(child: GoogleSearchView(search: search)),
                ],
              ),
            ),
          ),
        ),
      );
      search.change('SM Megamall');
      search.submit();
      final deadline = DateTime.now().add(const Duration(seconds: 25));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 200));
        if (map != null && search.searched) break;
      }
      expect(map, isNotNull);
      expect(search.failed, isFalse);
      expect(search.googleCandidates, isNotEmpty);
      expect(search.googleCandidates.every((p) => p.valid), isTrue);
      final marks = await map!.addMarkers([
        const nav.MarkerOptions(
          position: nav.LatLng(latitude: 14.5849, longitude: 121.0568),
        ),
      ]);
      expect(marks.whereType<nav.Marker>(), isNotEmpty);
      expect(tester.takeException(), isNull);
      debugPrint('WAYDAY_GOOGLE_MAP_CANDIDATE_COMPATIBILITY_PASSED bindings=1');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      search.dispose();
      choice.dispose();
      container.dispose();
    },
  );
}
