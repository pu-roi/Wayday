import '../../places/domain/place_intent.dart';
import '../data/itinerary_repository.dart';
import 'planning_models.dart';
import 'navigation_models.dart';

enum NavigationTargetSource { independent, googleUiKit }

/// A navigation-only snapshot; never serialized into accepted places/templates.
class ResolvedNavigationTarget {
  const ResolvedNavigationTarget({
    required this.tripId,
    required this.waypointId,
    required this.errandIds,
    required this.coordinate,
    required this.source,
    required this.acquiredAt,
    this.expiresAt,
    this.placeId,
  });
  final String tripId, waypointId;
  final List<String> errandIds;
  final NavigationCoordinate coordinate;
  final NavigationTargetSource source;
  final DateTime acquiredAt;
  final DateTime? expiresAt;
  final String? placeId;
  bool validAt(DateTime now) =>
      coordinate.valid &&
      !acquiredAt.isAfter(now) &&
      (expiresAt == null || now.isBefore(expiresAt!));
}

class TripWaypoint {
  const TripWaypoint(
    this.place,
    this.errandIds, {
    this.finalDestination = false,
    this.target,
  });
  final PlaceIntent place;
  final List<String> errandIds;
  final bool finalDestination;
  final ResolvedNavigationTarget? target;
  NavigationCoordinate? get coordinate =>
      target?.coordinate ??
      (place.hasCoordinates
          ? NavigationCoordinate(
              latitude: place.latitude!,
              longitude: place.longitude!,
            )
          : null);
  TripWaypoint withTarget(ResolvedNavigationTarget value) => TripWaypoint(
    place,
    errandIds,
    finalDestination: finalDestination,
    target: value,
  );
}

String? alternativeWaypointIssue(Iterable<TripWaypoint> points) {
  for (final point in points) {
    final target = point.target;
    if (target == null) {
      final issue = alternativeDestinationIssue([point.place]);
      if (issue != null) return issue;
    } else if (!target.validAt(DateTime.now()) ||
        ((point.place.isGoogle || point.place.usesGoogleSdk) &&
            (target.source != NavigationTargetSource.googleUiKit ||
                target.placeId != point.place.providerPlaceId))) {
      return 'A navigation target is expired or has incompatible provenance. Retry explicitly.';
    }
  }
  return null;
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
