import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/trip_waypoints.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  test(
    'remaining waypoints merge adjacent targets, retain returns and final',
    () {
      final day = fixture().copyWith(
        toPlace: const PlaceIntent(
          kind: PlaceKind.specific,
          label: 'End',
          latitude: 14.6,
          longitude: 121.1,
        ),
      );
      final plan = AcceptedItinerary(
        day: day,
        acceptedAt: DateTime.now(),
        stops: [
          ItineraryStop(day.fromPlace, ['a']),
          ItineraryStop(day.fromPlace, ['b']),
          ItineraryStop(day.toPlace, ['c']),
          ItineraryStop(day.fromPlace, ['d']),
        ],
      );
      final points = remainingWaypoints(plan);
      expect(points.length, 4);
      expect(points.first.errandIds, ['a', 'b']);
      expect(points[2].place, day.fromPlace);
      expect(points.last.finalDestination, isTrue);
      expect(points.last.errandIds, isEmpty);
    },
  );
  test(
    'completed tasks are excluded and final coincident stop stays distinct in purpose',
    () {
      final day = fixture();
      final plan = AcceptedItinerary(
        day: day,
        acceptedAt: DateTime.now(),
        completed: {'a'},
        stops: [
          ItineraryStop(day.fromPlace, ['a']),
          ItineraryStop(day.toPlace, ['b']),
        ],
      );
      final points = remainingWaypoints(plan);
      expect(points.single.errandIds, ['b']);
      expect(points.single.finalDestination, isTrue);
    },
  );
}
