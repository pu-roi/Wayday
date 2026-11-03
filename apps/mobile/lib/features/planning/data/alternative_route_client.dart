import 'dart:convert';
import '../../../core/network/gateway_client.dart';
import '../../today/domain/day.dart';
import '../domain/navigation_models.dart';
import '../domain/planning_models.dart';

class AlternativeRouteClient {
  AlternativeRouteClient({
    GatewayClient? gateway,
    this.enabled = const bool.fromEnvironment('WAYDAY_ALTERNATIVE_NAVIGATION'),
  }) : gateway = gateway ?? GatewayClient.shared;
  final GatewayClient gateway;
  final bool enabled;
  Future<List<NavigationLeg>> route(
    List<NavigationCoordinate> points,
    TravelProfile profile,
  ) async {
    if (!enabled) {
      throw const PlanningFailure(
        'OpenStreetMap navigation is not available in this build. Your trip is kept.',
        kind: 'alternative_disabled',
      );
    }
    if (points.length < 2 ||
        points.length > 26 ||
        points.any((p) => !p.valid) ||
        profile == TravelProfile.bike) {
      throw const PlanningFailure(
        'This route or travel mode is not available for alternative guidance.',
        kind: 'unsupported_profile',
      );
    }
    final response = await gateway.post('/v1/navigation/geoapify/route', {
      'points': points.map((p) => p.toJson()).toList(),
      'profile': profile == TravelProfile.truck ? 'sedan' : profile.name,
    });
    if (response.statusCode != 200) {
      throw PlanningFailure(switch (response.statusCode) {
        401 ||
        403 => 'Alternative navigation access was denied. Your trip is kept.',
        429 =>
          'Alternative navigation is temporarily unavailable. Try another map or retry later. Your trip progress is kept.',
        503 =>
          'Alternative navigation is unavailable or has not been enabled. Your trip is kept.',
        504 => 'Alternative routing timed out. Retry explicitly.',
        _ =>
          'A usable alternative route could not be obtained. Your trip is kept.',
      }, kind: 'alternative_${response.statusCode}');
    }
    return decode(jsonDecode(response.body), points.length - 1);
  }

  static List<NavigationLeg> decode(dynamic data, int expectedLegs) {
    try {
      if (data is! Map ||
          data['version'] != 1 ||
          data['legs'] is! List ||
          data['legs'].length != expectedLegs) {
        throw const FormatException();
      }
      var vertices = 0;
      double metric(dynamic value) {
        if (value is! num || !value.isFinite || value < 0 || value > 10000000) {
          throw const FormatException();
        }
        return value.toDouble();
      }

      return List.unmodifiable(
        (data['legs'] as List).map((leg) {
          final raw = leg['coordinates'] as List;
          vertices += raw.length;
          if (raw.length < 2 || vertices > 30000) throw const FormatException();
          final coordinates = raw
              .map((p) {
                if (p is! List || p.length != 2 || p.any((v) => v is! num)) {
                  throw const FormatException();
                }
                final point = NavigationCoordinate(
                  latitude: (p[0] as num).toDouble(),
                  longitude: (p[1] as num).toDouble(),
                );
                if (!point.valid) throw const FormatException();
                return point;
              })
              .toList(growable: false);
          var end = 0;
          final rawSteps = leg['steps'] as List;
          if (rawSteps.length < 2 || rawSteps.length > 2000) {
            throw const FormatException();
          }
          final steps = rawSteps
              .map((s) {
                final from = s['from'], to = s['to'], text = s['instruction'];
                if (from is! int ||
                    to is! int ||
                    from != end ||
                    to < from ||
                    to >= coordinates.length ||
                    text is! String ||
                    text.trim().isEmpty ||
                    text.length > 1000) {
                  throw const FormatException();
                }
                end = to;
                return NavigationManeuver(
                  from,
                  to,
                  metric(s['distance']),
                  metric(s['duration']),
                  text,
                  maneuver:
                      s['maneuver'] is String &&
                          (s['maneuver'] as String).length <= 80
                      ? s['maneuver'] as String
                      : 'None',
                );
              })
              .toList(growable: false);
          if (end != coordinates.length - 1 || steps.last.from != end) {
            throw const FormatException();
          }
          return NavigationLeg(
            List.unmodifiable(coordinates),
            steps: List.unmodifiable(steps),
            distance: metric(leg['distance']),
            duration: metric(leg['duration']),
          );
        }),
      );
    } catch (_) {
      throw const PlanningFailure(
        'The provider returned incomplete or invalid road guidance. Your trip is kept.',
        kind: 'invalid_route',
      );
    }
  }
}
