import '../../today/domain/day.dart';
import '../../places/domain/place_intent.dart';

class PlanningFailure implements Exception {
  const PlanningFailure(this.message, {this.kind = 'unavailable'});
  final String message, kind;
  @override
  String toString() => message;
}

/// Text-derived proposals never carry model-invented coordinates or businesses.
class ErrandNeed {
  const ErrandNeed({
    required this.id,
    required this.query,
    this.category = 'other',
    this.items = const [],
    this.question,
    this.durationMinutes = 15,
    this.after = const [],
    this.optional,
    this.timing,
    this.minute,
    this.proposedTitle,
    this.questionKind,
    this.questionRequired,
    this.requiresSpecificLocation = false,
  });
  final String id, query, category;
  final List<String> items, after;
  final String? question, proposedTitle, timing;
  final int durationMinutes;
  final bool? optional;
  final int? minute;
  final String? questionKind;
  final bool? questionRequired;
  final bool requiresSpecificLocation;
  ErrandNeed copyWith({
    String? query,
    String? category,
    List<String>? items,
    bool? requiresSpecificLocation,
  }) => ErrandNeed(
    id: id,
    query: query ?? this.query,
    category: category ?? this.category,
    items: items ?? this.items,
    question: question,
    durationMinutes: durationMinutes,
    after: after,
    optional: optional,
    timing: timing,
    minute: minute,
    proposedTitle: proposedTitle,
    questionKind: questionKind,
    questionRequired: questionRequired,
    requiresSpecificLocation:
        requiresSpecificLocation ?? this.requiresSpecificLocation,
  );
  bool get meeting => category == 'meeting';

  static const categories = {
    'grocery',
    'marketplace',
    'food',
    'convenience',
    'pharmacy',
    'other',
    'meeting',
  };

  factory ErrandNeed.fromJson(Map<String, dynamic> json) {
    final id = json['id'], query = json['query'], category = json['category'];
    final duration = json['durationMinutes'];
    final items = json['items'], after = json['after'];
    final timing = json['timing'], minute = json['minute'];
    if (id is! String ||
        id.isEmpty ||
        query is! String ||
        query.length > 100 ||
        !categories.contains(category) ||
        duration is! int ||
        duration < 1 ||
        duration > 480 ||
        items is! List ||
        items.length > 40 ||
        items.any((e) => e is! String || e.length > 120) ||
        after is! List ||
        after.any((e) => e is! String || e == id) ||
        (json['question'] != null && json['question'] is! String) ||
        (json['title'] != null && json['title'] is! String) ||
        (json['optional'] != null && json['optional'] is! bool) ||
        (timing != null && !TimingRule.values.any((t) => t.name == timing)) ||
        (minute != null && (minute is! int || minute < 0 || minute >= 1440))) {
      throw const FormatException('Invalid interpretation');
    }
    if (json['specificLocation'] != null && json['specificLocation'] is! bool) {
      throw const FormatException('Invalid destination requirement');
    }
    final spec = json['clarification'] as Map?;
    if (spec != null &&
        (!{
              'preference',
              'location',
              'timing',
              'dependency',
              'other',
            }.contains(spec['kind']) ||
            spec['required'] is! bool)) {
      throw const FormatException('Invalid clarification metadata');
    }
    return ErrandNeed(
      id: id,
      query: query.trim(),
      category: category as String,
      items: items.cast<String>(),
      after: after.cast<String>(),
      durationMinutes: duration,
      question: json['question'] as String?,
      proposedTitle: json['title'] as String?,
      optional: json['optional'] as bool?,
      timing: timing as String?,
      minute: minute as int?,
      questionKind: spec?['kind'] as String?,
      questionRequired: spec?['kind'] == 'preference'
          ? false
          : spec?['required'] as bool?,
      requiresSpecificLocation: json['specificLocation'] == true,
    );
  }

  Errand apply(Errand original) => original.copyWith(
    // Explicit structured values remain authoritative, including older records
    // whose confirmation metadata was incomplete.
    durationMinutes: original.durationConfirmed
        ? original.durationMinutes
        : durationMinutes,
    optional: original.confirmedFields.contains('optional') || original.optional
        ? original.optional
        : optional ?? original.optional,
    timing:
        original.confirmedFields.contains('timing') ||
            original.timing != TimingRule.anytime
        ? original.timing
        : timing == null
        ? original.timing
        : TimingRule.values.byName(timing!),
    minute:
        original.confirmedFields.contains('timing') ||
            original.timing != TimingRule.anytime
        ? original.minute
        : minute ?? original.minute,
    afterErrandIds:
        original.confirmedFields.contains('dependencies') ||
            original.afterErrandIds.isNotEmpty
        ? original.afterErrandIds
        : after,
  );
}

class Interpretation {
  Interpretation(this.needs, {this.additions = const []});
  final List<ErrandNeed> needs, additions;
  factory Interpretation.fromJson(Map<String, dynamic> json, DayPlan day) {
    final values = (json['needs'] as List)
        .map((e) => ErrandNeed.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final additions = (json['additions'] as List? ?? [])
        .map((e) => ErrandNeed.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final ids = day.errands.map((e) => e.id).toSet();
    final all = [...values, ...additions];
    final allIds = all.map((e) => e.id).toSet();
    if (values.length != ids.length ||
        values.map((e) => e.id).toSet().length != ids.length ||
        values.any((e) => !ids.contains(e.id)) ||
        allIds.length != all.length ||
        all.length > 12 ||
        additions.any((e) => ids.contains(e.id) || e.proposedTitle == null) ||
        all.any((e) => e.after.any((id) => !allIds.contains(id))) ||
        all.any(
          (e) => e.timing != null && e.timing != 'anytime' && e.minute == null,
        )) {
      throw const FormatException(
        'Interpretation references do not match the day',
      );
    }
    return Interpretation(values, additions: additions);
  }
}

class PlanCandidate {
  const PlanCandidate({
    required this.key,
    required this.place,
    required this.errandIds,
    this.reason = 'Matches this search; check availability.',
  });
  final String key, reason;
  final PlaceIntent place;
  final Set<String> errandIds;
}

String placeKey(PlaceIntent place) => place.providerPlaceId != null
    ? '${place.isGoogle ? 'google' : place.provider}:${place.providerPlaceId}'
    : place.savedPlaceId != null
    ? 'saved:${place.savedPlaceId}'
    : '${place.source}:${place.latitude},${place.longitude}:${place.label}';

class ScheduledTask {
  const ScheduledTask(this.errandId, this.start, this.finish);
  final String errandId;
  final int start, finish;
  Map<String, Object> toJson() => {
    'id': errandId,
    'start': start,
    'finish': finish,
  };
  factory ScheduledTask.fromJson(Map<String, dynamic> json) => ScheduledTask(
    json['id'] as String,
    json['start'] as int,
    json['finish'] as int,
  );
}

class ScheduledStop {
  const ScheduledStop(this.placeKey, this.arrival, this.departure, this.tasks);
  final String placeKey;
  final int arrival, departure;
  final List<ScheduledTask> tasks;
  Map<String, Object> toJson() => {
    'place': placeKey,
    'arrival': arrival,
    'departure': departure,
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };
  factory ScheduledStop.fromJson(Map<String, dynamic> json) => ScheduledStop(
    json['place'] as String,
    json['arrival'] as int,
    json['departure'] as int,
    (json['tasks'] as List)
        .map((t) => ScheduledTask.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList(),
  );
}

class DaySchedule {
  const DaySchedule({
    required this.stops,
    required this.omitted,
    required this.endArrival,
    required this.travelSeconds,
    this.timeLimited = false,
  });
  final List<ScheduledStop> stops;
  final Map<String, String> omitted;
  final int endArrival, travelSeconds;
  final bool timeLimited;
  Map<String, Object> toJson() => {
    'stops': stops.map((s) => s.toJson()).toList(),
    'omitted': omitted,
    'endArrival': endArrival,
    'travelSeconds': travelSeconds,
    'timeLimited': timeLimited,
  };
  factory DaySchedule.fromJson(Map<String, dynamic> json) => DaySchedule(
    stops: (json['stops'] as List)
        .map((s) => ScheduledStop.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList(),
    omitted: Map<String, String>.from(json['omitted'] as Map),
    endArrival: json['endArrival'] as int,
    travelSeconds: json['travelSeconds'] as int,
    timeLimited: json['timeLimited'] as bool? ?? false,
  );
}
