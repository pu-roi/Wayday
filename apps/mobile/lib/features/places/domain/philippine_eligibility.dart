import 'dart:convert';
import 'dart:math' as math;
import 'philippine_boundary.g.dart';

/// Conservative country membership, independent of Google bias/query text.
/// Natural Earth's land mask may omit islands/reclamation. Boundary-adjacent
/// coordinates remain unconfirmed; callers must retain a usable fallback.
class PhilippineEligibility {
  static final _polygons = (jsonDecode(philippineBoundaryJson) as List)
      .map(
        (polygon) => (polygon as List)
            .map(
              (ring) => (ring as List)
                  .map((point) => ((point as List)[0] as num, point[1] as num))
                  .toList(),
            )
            .toList(),
      )
      .toList();

  static bool confirmed(double latitude, double longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < 4 ||
        latitude > 22 ||
        longitude < 116 ||
        longitude > 127) {
      return false;
    }
    for (final polygon in _polygons) {
      if (!_inside(polygon.first, latitude, longitude)) continue;
      if (polygon.skip(1).any((ring) => _inside(ring, latitude, longitude))) {
        continue;
      }
      // Avoid treating points on uncertain shorelines as verified. Do not
      // expand the mask: small islands/coastal uncertainty fail closed.
      if (polygon.any((ring) => _nearRing(ring, latitude, longitude))) {
        return false;
      }
      return true;
    }
    return false;
  }

  static bool _inside(List<(num, num)> ring, double lat, double lon) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final (xi, yi) = ring[i];
      final (xj, yj) = ring[j];
      if ((yi > lat) != (yj > lat) &&
          lon < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  static bool _nearRing(List<(num, num)> ring, double lat, double lon) {
    final xScale = 111320 * math.cos(lat * math.pi / 180);
    for (var i = 1; i < ring.length; i++) {
      final (ax, ay) = ring[i - 1];
      final (bx, by) = ring[i];
      final x = (ax - lon) * xScale, y = (ay - lat) * 111320;
      final dx = (bx - ax) * xScale, dy = (by - ay) * 111320;
      final denominator = dx * dx + dy * dy;
      final t = denominator == 0
          ? 0
          : (-(x * dx + y * dy) / denominator).clamp(0, 1);
      if (math.pow(x + t * dx, 2) + math.pow(y + t * dy, 2) <= 250 * 250) {
        return true;
      }
    }
    return false;
  }
}
