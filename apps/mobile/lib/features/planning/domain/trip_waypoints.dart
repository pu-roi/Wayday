import '../../places/domain/place_intent.dart';
import '../data/itinerary_repository.dart';
import 'planning_models.dart';

class TripWaypoint {
  const TripWaypoint(
    this.place,
    this.errandIds, {
    this.finalDestination = false,
  });
  final PlaceIntent place;
  final List<String> errandIds;
  final bool finalDestination;
}

bool sameNavigationTarget(PlaceIntent a, PlaceIntent b) =>
    placeKey(a) == placeKey(b) ||
    a.hasCoordinates &&
        b.hasCoordinates &&
        a.latitude == b.latitude &&
        a.longitude == b.longitude;

/// Merge adjacent visits only. A later return to the same place is intentional.
List<TripWaypoint> remainingWaypoints(AcceptedItinerary plan) {
  final result = <TripWaypoint>[];
  void add(TripWaypoint point) {
    if (result.isNotEmpty &&
        sameNavigationTarget(result.last.place, point.place)) {
      final previous = result.removeLast();
      result.add(
        TripWaypoint(previous.place, [
          ...previous.errandIds,
          ...point.errandIds,
        ], finalDestination: point.finalDestination),
      );
    } else {
      result.add(point);
    }
  }

  for (final stop in plan.stops) {
    final ids = stop.errandIds
        .where((id) => !plan.completed.contains(id))
        .toList();
    if (ids.isNotEmpty) add(TripWaypoint(stop.place, ids));
  }
  add(TripWaypoint(plan.day.toPlace, const [], finalDestination: true));
  return result;
}
