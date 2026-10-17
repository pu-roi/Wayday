import '../../places/domain/place_intent.dart';
import '../../today/domain/day.dart';

/// Manual review operates on structured errands, independently of interpretation.
class DayReview {
  DayReview(DayPlan source) : baseRevision = source.revision, day = source;
  final int baseRevision;
  DayPlan day;

  int get missingPlaces => [
    day.fromPlace,
    ...day.errands.map((e) => e.placeIntent),
    day.toPlace,
  ].where((p) => !p.hasCoordinates).length;

  String? get orderingIssue {
    final positions = {
      for (var i = 0; i < day.errands.length; i++) day.errands[i].id: i,
    };
    for (var i = 0; i < day.errands.length; i++) {
      final errand = day.errands[i];
      for (final dependency in errand.afterErrandIds) {
        final position = positions[dependency];
        if (position == null) {
          return '“${errand.title}” refers to an errand that is no longer in this day. Edit its ordering first.';
        }
        if (position >= i) {
          return 'Keep “${errand.title}” after its prerequisite errand.';
        }
      }
    }
    return null;
  }

  String? move(int from, int to) {
    final previous = day;
    final errands = [...day.errands];
    errands.insert(to, errands.removeAt(from));
    day = day.copyWith(errands: errands);
    final issue = orderingIssue;
    if (issue != null) day = previous;
    return issue;
  }

  void replace(Errand errand) => day = day.copyWith(
    errands: [
      for (final item in day.errands) item.id == errand.id ? errand : item,
    ],
  );

  void setPlace({required bool start, required PlaceIntent place}) =>
      day = start
      ? day.copyWith(from: place.label, fromPlace: place)
      : day.copyWith(to: place.label, toPlace: place);
}
