import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/alternative_route_client.dart';
import 'package:wayday/features/planning/domain/navigation_models.dart';
import 'package:wayday/features/places/domain/place_intent.dart';

Map<String, dynamic> route() => {
  'version': 1,
  'legs': [
    {
      'coordinates': [
        [14.5, 121.0],
        [14.501, 121.001],
      ],
      'distance': 140,
      'duration': 20,
      'steps': [
        {
          'from': 0,
          'to': 1,
          'distance': 140,
          'duration': 20,
          'instruction': 'Continue north.',
        },
        {
          'from': 1,
          'to': 1,
          'distance': 0,
          'duration': 0,
          'instruction': 'You have arrived.',
        },
      ],
    },
  ],
};
void main() {
  test('provider geometry, units and instruction indexes are validated', () {
    final parsed = AlternativeRouteClient.decode(route(), 1);
    expect(parsed.single.coordinates.last.longitude, 121.001);
    expect(parsed.single.steps.first.instruction, 'Continue north.');
    for (final field in ['coordinates', 'distance', 'steps']) {
      final invalid = route();
      invalid['legs'][0][field] = field == 'distance' ? double.nan : <Object>[];
      expect(
        () => AlternativeRouteClient.decode(invalid, 1),
        throwsA(anything),
      );
    }
    final invalid = route();
    invalid['legs'][0]['steps'][0]['to'] = 99;
    expect(() => AlternativeRouteClient.decode(invalid, 1), throwsA(anything));
    expect(() => AlternativeRouteClient.decode(route(), 2), throwsA(anything));
  });
  test(
    'restricted standard SDK and separate UI Kit provenance cannot leak into routing',
    () {
      final lease = GooglePinLease()
        ..latitude = 14.5
        ..longitude = 121
        ..acquiredAt = DateTime.now();
      final sdk = PlaceIntent(provider: 'google_places_sdk', googlePin: lease);
      final kit = PlaceIntent(provider: 'google_ui_kit', googlePin: lease);
      expect(alternativeDestinationIssue([sdk]), contains('Google Places'));
      expect(alternativeDestinationIssue([kit]), contains('UI Kit'));
      const manual = PlaceIntent(latitude: 14.5, longitude: 121);
      expect(alternativeDestinationIssue([manual]), isNull);
      expect(manual.latitude, 14.5);
    },
  );
}
