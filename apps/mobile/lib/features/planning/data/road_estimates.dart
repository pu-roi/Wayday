import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../today/domain/day.dart';
import '../domain/planning_models.dart';
import '../domain/day_scheduler.dart';
import 'planning_budget.dart';
import '../domain/recommendation.dart';

class PlanningRoads {
  PlanningRoads(
    this.client,
    this.budget, {
    this.apiKey = const String.fromEnvironment('GOOGLE_ROUTES_API_KEY'),
    Future<Map<String, String>> Function()? identity,
  }) : identity = identity ?? _identity;
  final http.Client client;
  final PlanningBudget budget;
  final String apiKey;
  final Future<Map<String, String>> Function() identity;
  static Future<Map<String, String>> _identity() async =>
      (await const MethodChannel(
        'wayday/planning',
      ).invokeMapMethod<String, String>('identity')) ??
      {};
  String mode(TravelProfile profile) => switch (profile) {
    TravelProfile.walk => 'WALK',
    TravelProfile.bike => 'BICYCLE',
    TravelProfile.motor => 'TWO_WHEELER',
    TravelProfile.sedan || TravelProfile.truck => 'DRIVE',
  };
  bool traffic(TravelProfile p) =>
      p != TravelProfile.walk && p != TravelProfile.bike;

  Future<void> preflight(int points, int legs, {bool seed = false}) async {
    if (points > 0) {
      await budget.reserve(
        'matrix',
        points * points,
        daily: 200,
        monthly: 900,
        checkOnly: true,
      );
    }
    await budget.reserve(
      'routes',
      legs + (seed ? 1 : 0),
      daily: 30,
      monthly: 300,
      checkOnly: true,
    );
  }

  Future<String?> discoveryRoute(
    DayPlan day,
    List<PlanCandidate> fixed, {
    bool Function()? cancelled,
  }) async {
    if (cancelled?.call() == true) {
      throw const PlanningFailure('Cancelled.', kind: 'cancelled');
    }
    if (fixed.length == 2 &&
        fixed.first.place.latitude == fixed.last.place.latitude &&
        fixed.first.place.longitude == fixed.last.place.longitude) {
      return null;
    }
    await budget.reserve('routes', 1, daily: 30, monthly: 300);
    final raw = await _post(
      'computeRoutes',
      {
        'origin': waypoint(fixed.first),
        'destination': waypoint(fixed.last),
        if (fixed.length > 2)
          'intermediates': fixed
              .skip(1)
              .take(fixed.length - 2)
              .map(waypoint)
              .toList(),
        'travelMode': mode(day.profile),
        if (traffic(day.profile)) 'routingPreference': 'TRAFFIC_AWARE',
        if (traffic(day.profile))
          'departureTime': instant(
            day,
            day.departure * 60,
          ).toUtc().toIso8601String(),
      },
      'routes.polyline.encodedPolyline',
      await headers(),
    );
    final routes = (raw as Map)['routes'] as List?;
    final route = routes?.isNotEmpty == true ? routes!.first as Map : null;
    final encoded = (route?['polyline'] as Map?)?['encodedPolyline'];
    if (encoded is! String || encoded.isEmpty) {
      throw const PlanningFailure(
        'No route is available for place discovery.',
        kind: 'no_route',
      );
    }
    return encoded;
  }

  DateTime instant(DayPlan day, int seconds) => DateTime.parse(
    '${day.date}T00:00:00+08:00',
  ).add(Duration(seconds: seconds));

  Future<Map<String, String>> headers() async {
    if (apiKey.isEmpty) {
      throw const PlanningFailure(
        'Routes is not configured in this build.',
        kind: 'configuration',
      );
    }
    final app = await identity();
    if (app['package']?.isNotEmpty != true ||
        app['certificate']?.isNotEmpty != true) {
      throw const PlanningFailure(
        'The Android signing identity could not be checked.',
        kind: 'configuration',
      );
    }
    return {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Android-Package': app['package']!,
      'X-Android-Cert': app['certificate']!,
    };
  }

  Map<String, Object> waypoint(PlanCandidate point) {
    if (!point.place.hasCoordinates) {
      throw const PlanningFailure(
        'A location has expired or needs a map pin.',
        kind: 'needs_clarification',
      );
    }
    return {
      'location': {
        'latLng': {
          'latitude': point.place.latitude,
          'longitude': point.place.longitude,
        },
      },
    };
  }

  Future<dynamic> _post(
    String operation,
    Map<String, dynamic> data,
    String fields,
    Map<String, String> auth,
  ) async {
    try {
      final response = await client
          .post(
            Uri.https(
              'routes.googleapis.com',
              operation == 'computeRouteMatrix'
                  ? '/distanceMatrix/v2:computeRouteMatrix'
                  : '/directions/v2:computeRoutes',
            ),
            headers: {...auth, 'X-Goog-FieldMask': fields},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 429) {
        throw const PlanningFailure(
          'Google routing quota is exhausted. Your draft is kept.',
          kind: 'quota',
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const PlanningFailure(
          'Routing access was denied for this app. Check the restricted key configuration.',
          kind: 'access',
        );
      }
      if (response.statusCode == 400) {
        throw const PlanningFailure(
          'This travel mode or dated request is unavailable for these locations.',
          kind: 'unsupported_profile',
        );
      }
      if (response.statusCode != 200 || response.body.length > 1500000) {
        throw const FormatException();
      }
      return jsonDecode(response.body);
    } on PlanningFailure {
      rethrow;
    } catch (_) {
      throw const PlanningFailure(
        'Road estimates are unavailable. Your errands and previous plan are kept.',
      );
    }
  }

  Future<Map<String, dynamic>> matrix(
    DayPlan day,
    List<PlanCandidate> points, {
    bool Function()? cancelled,
  }) async {
    final auth = await headers();
    final count = points.length;
    if (count < 2 || count > 38) {
      throw const PlanningFailure(
        'Too many places for one calculation. Reduce the day or alternatives.',
        kind: 'capacity',
      );
    }
    await budget.reserve('matrix', count * count, daily: 200, monthly: 900);
    final rows = List.generate(count, (_) => List<int?>.filled(count, null));
    final meters = List.generate(count, (_) => List<int?>.filled(count, null));
    var fallback = false;
    for (var origin = 0; origin < count; origin += 10) {
      for (var destination = 0; destination < count; destination += 10) {
        if (cancelled?.call() == true) {
          throw const PlanningFailure(
            'Calculation cancelled.',
            kind: 'cancelled',
          );
        }
        final origins = points.skip(origin).take(10).toList();
        final destinations = points.skip(destination).take(10).toList();
        final data = <String, dynamic>{
          'origins': origins.map((p) => {'waypoint': waypoint(p)}).toList(),
          'destinations': destinations
              .map((p) => {'waypoint': waypoint(p)})
              .toList(),
          'travelMode': mode(day.profile),
          if (traffic(day.profile)) 'routingPreference': 'TRAFFIC_AWARE',
          if (traffic(day.profile))
            'departureTime': instant(
              day,
              day.departure * 60,
            ).toUtc().toIso8601String(),
        };
        final raw = await _post(
          'computeRouteMatrix',
          data,
          'originIndex,destinationIndex,status,condition,duration,distanceMeters,fallbackInfo',
          auth,
        );
        if (raw is! List) {
          throw const PlanningFailure(
            'The road matrix response is incomplete.',
          );
        }
        final seen = <String>{};
        for (final value in raw) {
          final e = Map<String, dynamic>.from(value as Map);
          final a = e['originIndex'] as int? ?? 0,
              b = e['destinationIndex'] as int? ?? 0;
          if (a < 0 ||
              a >= origins.length ||
              b < 0 ||
              b >= destinations.length ||
              !seen.add('$a:$b')) {
            throw const PlanningFailure(
              'The road matrix response contains invalid references.',
            );
          }
          if ((e['status'] as Map?)?['code'] != null &&
              (e['status'] as Map)['code'] != 0) {
            continue;
          }
          if (e['condition'] != 'ROUTE_EXISTS') continue;
          rows[origin + a][destination + b] = seconds(e['duration']);
          final distance = e['distanceMeters'];
          if (distance is int && distance >= 0) {
            meters[origin + a][destination + b] = distance;
          }
          fallback = fallback || e['fallbackInfo'] != null;
        }
        if (seen.length != origins.length * destinations.length) {
          throw const PlanningFailure(
            'The road matrix is incomplete. Try again later.',
          );
        }
        if (destination + 10 < count || origin + 10 < count) {
          await Future<void>.delayed(const Duration(milliseconds: 1100));
        }
      }
    }
    return {'matrix': rows, 'meters': meters, 'fallback': fallback};
  }

  Future<RefinedPlan> refine(
    DayPlan day,
    DaySchedule initial,
    List<PlanCandidate> points, {
    bool Function()? cancelled,
  }) async {
    final auth = await headers();
    await budget.reserve(
      'routes',
      initial.stops.length + 1,
      daily: 30,
      monthly: 300,
    );
    final lookup = {for (final point in points) point.key: point};
    final errands = {for (final e in day.errands) e.id: e};
    var at = '@start', time = day.departure * 60, total = 0;
    final stops = <ScheduledStop>[], geometry = <List<List<double>>>[];
    final fixedMatrix = List.generate(
      points.length,
      (_) => List<int?>.filled(points.length, null),
    );
    final keys = points.map((p) => p.key).toList();
    final legTimes = <String, int>{};
    final warnings = <String>{};
    var fallback = false;
    final legs = <RecommendationLeg>[];
    Future<int> fetch(String next) async {
      if (cancelled?.call() == true) {
        throw const PlanningFailure(
          'Calculation cancelled.',
          kind: 'cancelled',
        );
      }
      if (at == next) return 0;
      final raw = await _post(
        'computeRoutes',
        {
          'origin': waypoint(lookup[at]!),
          'destination': waypoint(lookup[next]!),
          'travelMode': mode(day.profile),
          if (traffic(day.profile)) 'routingPreference': 'TRAFFIC_AWARE',
          if (traffic(day.profile))
            'departureTime': instant(day, time).toUtc().toIso8601String(),
        },
        'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.warnings,fallbackInfo',
        auth,
      );
      final routes = (raw as Map)['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        throw const PlanningFailure(
          'There is no road route between two selected stops.',
          kind: 'no_route',
        );
      }
      final route = routes.first as Map;
      final duration = seconds(route['duration']);
      final meters = route['distanceMeters'];
      legs.add(
        RecommendationLeg(
          from: at,
          to: next,
          seconds: duration,
          departureSeconds: time,
          meters: meters is int && meters >= 0 ? meters : null,
        ),
      );
      legTimes['$at>$next@$time'] = duration;
      warnings.addAll((route['warnings'] as List? ?? []).whereType<String>());
      final encoded =
          (route['polyline'] as Map?)?['encodedPolyline'] as String?;
      if (encoded == null) {
        throw const PlanningFailure(
          'Google did not return route geometry for this leg.',
        );
      }
      geometry.add(decodePolyline(encoded));
      fixedMatrix[keys.indexOf(at)][keys.indexOf(next)] = duration;
      fallback = fallback || raw['fallbackInfo'] != null;
      return duration;
    }

    for (final stop in initial.stops) {
      final road = await fetch(stop.placeKey);
      total += road;
      final arrival = time + road;
      var service = arrival;
      final tasks = <ScheduledTask>[];
      for (final original in stop.tasks) {
        final e = errands[original.errandId]!;
        final limit = (e.minute ?? 0) * 60;
        if (e.timing == TimingRule.at) {
          if (service > limit) {
            throw const PlanningFailure(
              'Updated road times miss an appointment. Change a place or departure and recalculate.',
              kind: 'needs_recalculation',
            );
          }
          service = limit;
        }
        final finish = service + e.durationMinutes * 60;
        if ((e.timing == TimingRule.arriveBy && arrival > limit) ||
            (e.timing == TimingRule.finishBefore && finish + 300 > limit)) {
          throw const PlanningFailure(
            'The current recommendation no longer meets an errand deadline. Change a place or departure and recalculate.',
            kind: 'needs_recalculation',
          );
        }
        tasks.add(ScheduledTask(e.id, service, finish));
        service = finish;
      }
      time = service + 300;
      stops.add(ScheduledStop(stop.placeKey, arrival, time, tasks));
      at = stop.placeKey;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    }
    final tail = await fetch('@end');
    total += tail;
    final schedule = DaySchedule(
      stops: stops,
      omitted: initial.omitted,
      endArrival: time + tail,
      travelSeconds: total,
      timeLimited: initial.timeLimited,
    );
    final validation = validateSchedule({
      'errands': day.errands.map((e) => e.toJson()).toList(),
      'keys': keys,
      'matrix': fixedMatrix,
      'legTimes': legTimes,
      'departure': day.departure * 60,
      'deadline': day.deadline * 60,
      'start': '@start',
      'end': '@end',
      'options': {
        for (final p in points)
          for (final id in p.errandIds)
            id: points
                .where((other) => other.errandIds.contains(id))
                .map((e) => e.key)
                .toList(),
      },
    }, schedule);
    if (validation != null) {
      throw PlanningFailure(
        'The final route needs another calculation. $validation',
        kind: 'needs_recalculation',
      );
    }
    return RefinedPlan(
      schedule,
      geometry,
      fallback,
      warnings: warnings.toList(),
      legs: legs,
    );
  }

  static int seconds(dynamic value) {
    if (value is! String || !RegExp(r'^\d+(\.\d+)?s$').hasMatch(value)) {
      throw const PlanningFailure('A road time is missing.');
    }
    final number = double.parse(value.substring(0, value.length - 1));
    if (!number.isFinite || number < 0 || number > 86400 * 7) {
      throw const PlanningFailure('A road time is invalid.');
    }
    return number.ceil();
  }
}

class RefinedPlan {
  const RefinedPlan(
    this.schedule,
    this.geometry,
    this.fallback, {
    this.warnings = const [],
    this.legs = const [],
    this.calculatedAt,
  });
  final DaySchedule schedule;
  final List<List<List<double>>> geometry;
  final bool fallback;
  final List<String> warnings;
  final List<RecommendationLeg> legs;
  final DateTime? calculatedAt;
}

List<List<double>> decodePolyline(String encoded) {
  final points = <List<double>>[];
  var i = 0, lat = 0, lon = 0;
  int next() {
    var result = 0, shift = 0, b = 0;
    do {
      if (i >= encoded.length || shift > 30) {
        throw const PlanningFailure('The road geometry is malformed.');
      }
      b = encoded.codeUnitAt(i++) - 63;
      if (b < 0 || b > 63) {
        throw const PlanningFailure('Invalid route geometry.');
      }
      result |= (b & 31) << shift;
      shift += 5;
    } while (b >= 32);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (i < encoded.length) {
    lat += next();
    lon += next();
    if (lat.abs() > 9000000 || lon.abs() > 18000000) {
      throw const PlanningFailure('Invalid road coordinates.');
    }
    points.add([lat / 1e5, lon / 1e5]);
  }
  return points;
}
