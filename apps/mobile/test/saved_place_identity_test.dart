import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/places/presentation/saved_places_controller.dart';

void main() {
  test(
    'same-named branches remain separate and source updates preserve identity',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final saved = container.read(savedPlacesProvider.notifier);
      const first = PlaceIntent(
        kind: PlaceKind.specific,
        label: 'Synthetic branch',
        source: 'osm/node/1',
        latitude: 14.56,
        longitude: 121.075,
        address: 'Example Street',
        sourceDate: '2026-10-17',
        coordinateKind: 'mapped_point',
      );
      const second = PlaceIntent(
        kind: PlaceKind.specific,
        label: 'Synthetic branch',
        source: 'osm/node/2',
        latitude: 14.57,
        longitude: 121.08,
      );
      saved.save(first);
      final id = container.read(savedPlacesProvider).single.id;
      saved.save(second);
      saved.save(first);
      final places = container.read(savedPlacesProvider);
      expect(places.length, 2);
      expect(places.singleWhere((p) => p.place.source == first.source).id, id);
      expect(
        places.singleWhere((p) => p.id == id).intent.address,
        first.address,
      );
      final restored = PlaceIntent.fromJson(first.toJson());
      expect(restored.address, first.address);
      expect(restored.sourceDate, first.sourceDate);
      expect(restored.coordinateKind, first.coordinateKind);
      final legacy = Map<String, dynamic>.of(first.toJson())
        ..remove('address')
        ..remove('sourceDate')
        ..remove('coordinateKind');
      expect(PlaceIntent.fromJson(legacy).address, isNull);
    },
  );
}
