import '../../places/domain/place_intent.dart';

enum TimingRule {
  anytime('Anytime'),
  at('At a set time'),
  arriveBy('Arrive by'),
  finishBefore('Finish before');

  const TimingRule(this.label);
  final String label;
}

class Errand {
  const Errand({
    required this.id,
    required this.title,
    this.place = '',
    this.notes = '',
    this.timing = TimingRule.anytime,
    this.minute,
    this.optional = false,
    this.sourceGroupId,
    this.sourceItemId,
    this.originalText,
    PlaceIntent? placeIntent,
    this.durationMinutes = 15,
    this.durationConfirmed = false,
    this.confirmedFields = const {},
    this.afterErrandIds = const [],
  }) : _placeIntent = placeIntent;
  final String id;
  final String title;
  final String place;
  final String notes;
  final TimingRule timing;
  final int? minute;
  final bool optional;
  final String? sourceGroupId;
  final String? sourceItemId;
  final String? originalText;
  final PlaceIntent? _placeIntent;
  PlaceIntent get placeIntent =>
      _placeIntent == null ||
          (_placeIntent.kind == PlaceKind.unresolved &&
              _placeIntent.label.isEmpty &&
              !_placeIntent.hasCoordinates)
      ? PlaceIntent(label: place)
      : _placeIntent;
  final int durationMinutes;
  final bool durationConfirmed;
  final Set<String> confirmedFields;
  final List<String> afterErrandIds;

  String get inputText => originalText ?? title;

  Errand copyWith({
    String? title,
    String? place,
    String? notes,
    TimingRule? timing,
    int? minute,
    bool clearTime = false,
    bool? optional,
    PlaceIntent? placeIntent,
    int? durationMinutes,
    bool? durationConfirmed,
    Set<String>? confirmedFields,
    List<String>? afterErrandIds,
  }) => Errand(
    id: id,
    title: title ?? this.title,
    place: place ?? this.place,
    notes: notes ?? this.notes,
    timing: timing ?? this.timing,
    minute: clearTime ? null : minute ?? this.minute,
    optional: optional ?? this.optional,
    sourceGroupId: sourceGroupId,
    sourceItemId: sourceItemId,
    originalText: inputText,
    placeIntent:
        placeIntent ??
        (place != null && place != this.place
            ? PlaceIntent(label: place)
            : this.placeIntent),
    durationMinutes: durationMinutes ?? this.durationMinutes,
    durationConfirmed: durationConfirmed ?? this.durationConfirmed,
    confirmedFields: Set.unmodifiable(confirmedFields ?? this.confirmedFields),
    afterErrandIds: List.unmodifiable(afterErrandIds ?? this.afterErrandIds),
  );

  Errand copyForToday({
    required String newId,
    required String groupId,
    Map<String, String> idMap = const {},
  }) => Errand(
    id: newId,
    title: title,
    place: place,
    notes: notes,
    timing: timing,
    minute: minute,
    optional: optional,
    sourceGroupId: groupId,
    sourceItemId: id,
    originalText: inputText,
    placeIntent: placeIntent,
    durationMinutes: durationMinutes,
    durationConfirmed: durationConfirmed,
    confirmedFields: Set.unmodifiable(confirmedFields),
    afterErrandIds: List.unmodifiable([
      for (final id in afterErrandIds) idMap[id] ?? id,
    ]),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'originalText': inputText,
    'place': place,
    'notes': notes,
    'timing': timing.name,
    'minute': minute,
    'optional': optional,
    'sourceGroupId': sourceGroupId,
    'sourceItemId': sourceItemId,
    'placeIntent': placeIntent.toJson(),
    'durationMinutes': durationMinutes,
    'durationConfirmed': durationConfirmed,
    'confirmedFields': confirmedFields.toList(),
    'afterErrandIds': afterErrandIds,
  };

  factory Errand.fromJson(Map<String, dynamic> json) {
    final duration = json['durationMinutes'] as int? ?? 15;
    final timing = TimingRule.values.byName(json['timing'] as String);
    final minute = json['minute'] as int?;
    if (duration < 1 ||
        duration > 1440 ||
        (minute != null && (minute < 0 || minute >= 1440)) ||
        (timing != TimingRule.anytime && minute == null)) {
      throw const FormatException('Invalid errand timing');
    }
    return Errand(
      id: json['id'] as String,
      title: json['title'] as String,
      originalText: json['originalText'] as String?,
      place: json['place'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      timing: timing,
      minute: minute,
      optional: json['optional'] as bool? ?? false,
      sourceGroupId: json['sourceGroupId'] as String?,
      sourceItemId: json['sourceItemId'] as String?,
      placeIntent: json['placeIntent'] == null
          ? PlaceIntent(label: json['place'] as String? ?? '')
          : PlaceIntent.fromJson(json['placeIntent'] as Map<String, dynamic>),
      durationMinutes: duration,
      durationConfirmed: json['durationConfirmed'] as bool? ?? false,
      confirmedFields: Set.unmodifiable(
        (json['confirmedFields'] as List? ?? []).cast<String>(),
      ),
      afterErrandIds: List.unmodifiable(
        (json['afterErrandIds'] as List? ?? []).cast<String>(),
      ),
    );
  }
}

String formatMinute(int minute) {
  final hour = minute ~/ 60;
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${(minute % 60).toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';
}
