import '../../errands/domain/errand.dart';
import '../../errands/domain/errand_order.dart';
import 'planning_models.dart';

/// Plain values cross the worker-isolate boundary; no coordinate leases/widgets.
/// Times are seconds from the selected local midnight, distances stay in meters.
Map<String, dynamic> solveDay(Map<String, dynamic> input) {
  final errands = (input['errands'] as List)
      .map((e) => Errand.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  final issue = ErrandOrder.reconcile(errands).issue;
  if (issue != null) return {'error': 'invalid_input', 'message': issue};
  final keys = (input['keys'] as List).cast<String>();
  final index = {for (var i = 0; i < keys.length; i++) keys[i]: i};
  final matrix = (input['matrix'] as List)
      .map((r) => (r as List).cast<int?>())
      .toList();
  if (keys.toSet().length != keys.length ||
      matrix.length != keys.length ||
      matrix.any(
        (r) => r.length != keys.length || r.any((v) => v != null && v < 0),
      )) {
    return {'error': 'invalid_input', 'message': 'Invalid road matrix.'};
  }
  final options = (input['options'] as Map).map(
    (k, v) => MapEntry(k as String, (v as List).cast<String>()),
  );
  final departure = input['departure'] as int,
      deadline = input['deadline'] as int;
  final buffer = input['buffer'] as int? ?? 300;
  final startKey = input['start'] as String, endKey = input['end'] as String;
  final maxMillis = input['budgetMillis'] as int? ?? 5000;
  final hours = (input['hours'] as Map? ?? {}).map(
    (k, v) => MapEntry(
      k as String,
      (v as List).map((w) => (w as List).cast<int>()).toList(),
    ),
  );
  if (departure < 0 ||
      deadline <= departure ||
      deadline >= 86400 ||
      buffer < 0 ||
      !index.containsKey(startKey) ||
      !index.containsKey(endKey) ||
      options.values.expand((e) => e).any((k) => !index.containsKey(k))) {
    return {
      'error': 'invalid_input',
      'message': 'Invalid day or route references.',
    };
  }
  final byId = {for (final e in errands) e.id: e};
  final required = errands.where((e) => !e.optional).map((e) => e.id).toSet();
  void requireAncestors(String id) {
    for (final dep in byId[id]!.afterErrandIds) {
      if (required.add(dep)) requireAncestors(dep);
    }
  }

  for (final id in required.toList()) {
    requireAncestors(id);
  }
  for (final id in required) {
    if (options[id]?.isNotEmpty != true) {
      return {
        'error': 'no_candidates',
        'message': 'No suitable place for “${byId[id]!.title}”.',
      };
    }
  }
  int? leg(String a, String b) => a == b ? 0 : matrix[index[a]!][index[b]!];
  Set<String> reachable(String from, {bool reverse = false}) {
    final seen = {from}, pending = [from];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      for (final next in keys) {
        if (!seen.contains(next) &&
            (reverse ? leg(next, current) : leg(current, next)) != null) {
          seen.add(next);
          pending.add(next);
        }
      }
    }
    return seen;
  }

  final outbound = reachable(startKey),
      inbound = reachable(endKey, reverse: true);
  if (!outbound.contains(endKey) ||
      required.any(
        (id) => !options[id]!.any(
          (key) => outbound.contains(key) && inbound.contains(key),
        ),
      )) {
    return {
      'error': 'no_route',
      'message':
          'A required destination has no road connection with these places and travel mode.',
    };
  }
  final clock = Stopwatch()..start();
  bool timedOut = false;
  DaySchedule? best;
  int bestOptional = -1;
  bool open(String key, int from, int to) =>
      hours[key] == null ||
      hours[key]!.any((w) => w.length == 2 && from >= w[0] && to <= w[1]);
  final candidates = [...errands]
    ..sort((a, b) {
      final m = (a.minute ?? 1440).compareTo(b.minute ?? 1440);
      return m != 0 ? m : errands.indexOf(a).compareTo(errands.indexOf(b));
    });
  void search(
    Set<String> done,
    Set<String> skipped,
    List<ScheduledStop> stops,
    String at,
    int time,
    int travel,
  ) {
    if (clock.elapsedMilliseconds >= maxMillis) {
      timedOut = true;
      return;
    }
    if (time > deadline) return;
    if (done.length + skipped.length == errands.length) {
      final tail = leg(at, endKey);
      if (tail == null || time + tail > deadline) return;
      final optional = done.where((id) => byId[id]!.optional).length;
      final total = travel + tail;
      if (optional > bestOptional ||
          (optional == bestOptional &&
              (best == null ||
                  total < best!.travelSeconds ||
                  (total == best!.travelSeconds &&
                      (stops.length < best!.stops.length ||
                          (stops.length == best!.stops.length &&
                              time + tail < best!.endArrival)))))) {
        bestOptional = optional;
        best = DaySchedule(
          stops: [...stops],
          omitted: {
            for (final id in skipped)
              id: byId[id]!.afterErrandIds.any(skipped.contains)
                  ? 'A prerequisite could not be included.'
                  : 'Does not fit the selected day with the available places.',
          },
          endArrival: time + tail,
          travelSeconds: total,
        );
      }
      return;
    }
    final possibleOptional = errands
        .where((e) => e.optional && !skipped.contains(e.id))
        .length;
    if (possibleOptional < bestOptional) return;
    for (final e in candidates) {
      if (done.contains(e.id) || skipped.contains(e.id)) continue;
      if (e.afterErrandIds.every(done.contains)) {
        for (final key in options[e.id] ?? <String>[]) {
          final shared = stops.isNotEmpty && stops.last.placeKey == key;
          final previous = shared ? stops.last : null;
          final road = leg(at, key);
          if (road == null) continue;
          final arrival = shared ? previous!.arrival : time + road;
          var service = shared ? previous!.departure - buffer : arrival;
          final boundary = (e.minute ?? 0) * 60;
          if (e.timing == TimingRule.at) {
            if (service > boundary) continue;
            service = boundary;
          }
          if (e.timing == TimingRule.arriveBy && arrival > boundary) continue;
          final finish = service + e.durationMinutes * 60;
          if (e.timing == TimingRule.finishBefore &&
              finish + buffer > boundary) {
            continue;
          }
          final leave = finish + buffer;
          // Waiting for a known opening interval is part of service timing.
          if (!open(key, service, leave)) {
            final windows = hours[key];
            if (windows == null || shared || e.timing == TimingRule.at) {
              continue;
            }
            final valid =
                windows
                    .where(
                      (w) =>
                          w.length == 2 &&
                          w[0] >= service &&
                          w[0] + e.durationMinutes * 60 + buffer <= w[1],
                    )
                    .toList()
                  ..sort((a, b) => a[0].compareTo(b[0]));
            if (valid.isEmpty) continue;
            service = valid.first[0];
          }
          final actualFinish = service + e.durationMinutes * 60,
              actualLeave = actualFinish + buffer;
          if (e.timing == TimingRule.finishBefore && actualLeave > boundary) {
            continue;
          }
          final visitStart = shared ? previous!.tasks.first.start : service;
          if (!open(key, visitStart, actualLeave)) continue;
          final task = ScheduledTask(e.id, service, actualFinish);
          final next = ScheduledStop(key, arrival, actualLeave, [
            if (shared) ...previous!.tasks,
            task,
          ]);
          search(
            {...done, e.id},
            skipped,
            [...stops.take(shared ? stops.length - 1 : stops.length), next],
            key,
            actualLeave,
            travel + road,
          );
          if (timedOut) return;
        }
      }
      if (!required.contains(e.id)) {
        search(done, {...skipped, e.id}, stops, at, time, travel);
        if (timedOut) return;
      }
    }
  }

  search({}, {}, [], startKey, departure, 0);
  final result = best;
  if (result == null) {
    return {
      'error': timedOut ? 'timeout' : 'conflict',
      'message': timedOut
          ? 'No validated plan was found before the calculation limit. Try fewer alternatives.'
          : 'No itinerary fits these places, road connections and time rules. Review the constraints.',
    };
  }
  final checked = DaySchedule(
    stops: result.stops,
    omitted: result.omitted,
    endArrival: result.endArrival,
    travelSeconds: result.travelSeconds,
    timeLimited: timedOut,
  );
  final validation = validateSchedule(input, checked);
  if (validation != null) {
    return {'error': 'invalid_result', 'message': validation};
  }
  return {'schedule': checked.toJson()};
}

/// Independent acceptance walk, rather than trusting search construction.
String? validateSchedule(Map<String, dynamic> input, DaySchedule schedule) {
  final errands = (input['errands'] as List)
      .map((e) => Errand.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  final byId = {for (final e in errands) e.id: e};
  final keys = (input['keys'] as List).cast<String>();
  final matrix = (input['matrix'] as List)
      .map((r) => (r as List).cast<int?>())
      .toList();
  final options = input['options'] as Map;
  final buffer = input['buffer'] as int? ?? 300;
  var at = input['start'] as String,
      time = input['departure'] as int,
      travel = 0;
  int? roadAt(String from, String to, int departure) {
    if (from == to) return 0;
    final timed = input['legTimes'] as Map?;
    if (timed != null) return timed['$from>$to@$departure'] as int?;
    return matrix[keys.indexOf(from)][keys.indexOf(to)];
  }

  final done = <String>{};
  for (final stop in schedule.stops) {
    final a = keys.indexOf(at), b = keys.indexOf(stop.placeKey);
    if (a < 0 || b < 0 || stop.tasks.isEmpty) return 'Invalid scheduled stop.';
    final road = roadAt(at, stop.placeKey, time);
    if (road == null || stop.arrival != time + road) {
      return 'A road leg is missing or has changed.';
    }
    travel += road;
    var earliest = stop.arrival;
    for (final task in stop.tasks) {
      final e = byId[task.errandId];
      if (e == null ||
          !done.add(task.errandId) ||
          !(options[e.id] as List).contains(stop.placeKey) ||
          !e.afterErrandIds.every(done.contains) ||
          e.afterErrandIds.contains(e.id) ||
          task.start < earliest ||
          task.finish != task.start + e.durationMinutes * 60) {
        return 'The task sequence is invalid.';
      }
      final limit = (e.minute ?? 0) * 60;
      if ((e.timing == TimingRule.at && task.start != limit) ||
          (e.timing == TimingRule.arriveBy && stop.arrival > limit) ||
          (e.timing == TimingRule.finishBefore &&
              task.finish + buffer > limit)) {
        return 'An errand time rule was violated.';
      }
      earliest = task.finish;
    }
    if (stop.departure != earliest + buffer) {
      return 'The visit buffer is invalid.';
    }
    final windows = (input['hours'] as Map?)?[stop.placeKey] as List?;
    if (windows != null &&
        !windows.any((w) {
          final interval = (w as List).cast<int>();
          return stop.tasks.first.start >= interval[0] &&
              stop.departure <= interval[1];
        })) {
      return 'The visit is outside known business hours.';
    }
    time = stop.departure;
    at = stop.placeKey;
  }
  for (final e in errands) {
    if (!done.contains(e.id) &&
        (!e.optional || !schedule.omitted.containsKey(e.id))) {
      return 'A required errand is missing.';
    }
    if (done.contains(e.id) && schedule.omitted.containsKey(e.id)) {
      return 'An errand is both selected and omitted.';
    }
  }
  if (schedule.omitted.keys.any((id) => !byId.containsKey(id))) {
    return 'An omission references an unknown errand.';
  }
  final tail = roadAt(at, input['end'] as String, time);
  if (tail == null ||
      schedule.endArrival != time + tail ||
      schedule.endArrival > (input['deadline'] as int) ||
      schedule.travelSeconds != travel + tail) {
    return 'The final arrival is invalid.';
  }
  return null;
}
