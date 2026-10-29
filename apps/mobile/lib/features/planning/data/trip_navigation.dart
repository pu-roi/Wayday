import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;
import '../../today/domain/day.dart';
import '../../places/domain/place_intent.dart';
import '../domain/planning_models.dart';
import 'planning_budget.dart';

class TripNavigation {
  TripNavigation(this.budget);
  final PlanningBudget budget;
  bool initialized = false;
  Future<void> initialize() async {
    final accepted =
        await nav.GoogleMapsNavigator.areTermsAccepted() ||
        await nav.GoogleMapsNavigator.showTermsAndConditionsDialog(
          'Wayday',
          'Wayday',
        );
    if (!accepted) {
      throw const PlanningFailure(
        'Accept Google navigation terms to start guidance.',
      );
    }
    await nav.GoogleMapsNavigator.initializeNavigationSession(
      abnormalTerminationReportingEnabled: false,
      taskRemovedBehavior: nav.TaskRemovedBehavior.quitService,
    );
    initialized = true;
  }

  Future<void> guide(PlaceIntent destination, TravelProfile profile) async {
    if (!initialized) {
      throw const PlanningFailure('Start the navigation session first.');
    }
    if (!destination.hasCoordinates) {
      throw const PlanningFailure(
        'Refresh this stop’s location before guidance.',
      );
    }
    if (profile == TravelProfile.bike) {
      throw const PlanningFailure(
        'Bicycle guidance has not been qualified in the Philippines. Choose a supported travel mode.',
        kind: 'unsupported_profile',
      );
    }
    await budget.reserve('navigation', 1, daily: 20, monthly: 100);
    final status = await nav.GoogleMapsNavigator.setDestinations(
      nav.Destinations(
        displayOptions: nav.NavigationDisplayOptions(),
        waypoints: [
          nav.NavigationWaypoint.withLatLngTarget(
            title: destination.label,
            target: nav.LatLng(
              latitude: destination.latitude!,
              longitude: destination.longitude!,
            ),
          ),
        ],
        routingOptions: nav.RoutingOptions(
          travelMode: switch (profile) {
            TravelProfile.walk => nav.NavigationTravelMode.walking,
            TravelProfile.motor => nav.NavigationTravelMode.twoWheeler,
            TravelProfile.bike => nav.NavigationTravelMode.cycling,
            TravelProfile.sedan ||
            TravelProfile.truck => nav.NavigationTravelMode.driving,
          },
        ),
      ),
    );
    if (status != nav.NavigationRouteStatus.statusOk) {
      throw const PlanningFailure(
        'Google guidance is unavailable for this stop and travel mode. Your progress is kept.',
        kind: 'no_route',
      );
    }
    await nav.GoogleMapsNavigator.startGuidance();
  }

  Future<void> stop() async {
    if (!initialized) return;
    initialized = false;
    try {
      await nav.GoogleMapsNavigator.stopGuidance();
    } finally {
      await nav.GoogleMapsNavigator.cleanup();
    }
  }
}
