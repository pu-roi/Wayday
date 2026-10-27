import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  test(
    'native attribution stays enabled by default and can be disabled per map',
    () {
      final defaultOptions = MapLibreMapOptions.fromWidget(MapLibreMap());
      final todayOptions = MapLibreMapOptions.fromWidget(
        MapLibreMap(attributionButtonEnabled: false),
      );
      expect(defaultOptions.toMap()['attributionButtonEnabled'], true);
      expect(todayOptions.toMap()['attributionButtonEnabled'], false);
      expect(
        defaultOptions.updatesMap(todayOptions)['attributionButtonEnabled'],
        false,
      );
    },
  );
}
