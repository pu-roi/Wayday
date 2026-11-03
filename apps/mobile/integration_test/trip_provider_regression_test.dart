import 'alternative_navigation_core_test.dart' as alternative;
import 'trip_navigation_test.dart' as trip;
import 'alternative_trip_map_test.dart' as viewport;
import '../test/trip_target_switch_test.dart' as targets;

/// Synthetic core movement plus the unchanged trip controls/progress fixture.
/// The guarded .maptest harness is required; no live provider requests.
void main() {
  alternative.main();
  trip.main();
  viewport.main();
  targets.main();
}
