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
  });
  final String id;
  final String title;
  final String place;
  final String notes;
  final TimingRule timing;
  final int? minute;
  final bool optional;
  final String? sourceGroupId;
  final String? sourceItemId;

  Errand copyWith({
    String? title,
    String? place,
    String? notes,
    TimingRule? timing,
    int? minute,
    bool clearTime = false,
    bool? optional,
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
  );

  Errand copyForToday({required String newId, required String groupId}) =>
      Errand(
        id: newId,
        title: title,
        place: place,
        notes: notes,
        timing: timing,
        minute: minute,
        optional: optional,
        sourceGroupId: groupId,
        sourceItemId: id,
      );
}

String formatMinute(int minute) {
  final hour = minute ~/ 60;
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${(minute % 60).toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';
}
