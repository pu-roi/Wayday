import '../../today/domain/day.dart';

class ReviewTimingEdit {
  ReviewTimingEdit(this.timing, this.minute) {
    if ((minute != null && (minute! < 0 || minute! > 1439)) ||
        (timing != TimingRule.anytime && minute == null)) {
      throw const FormatException('Invalid saved errand time');
    }
  }
  final TimingRule timing;
  final int? minute;
  Errand apply(Errand e) => e.copyWith(
    timing: timing,
    minute: minute,
    clearTime: minute == null,
    confirmedFields: {...e.confirmedFields, 'timing'},
  );
  Map<String, Object?> toJson() => {'timing': timing.name, 'minute': minute};
  factory ReviewTimingEdit.fromJson(Map<String, dynamic> json) {
    final timing = TimingRule.values
        .where((t) => t.name == json['timing'])
        .firstOrNull;
    final minute = json['minute'];
    if (timing == null || (minute != null && minute is! int)) {
      throw const FormatException('Invalid saved errand time');
    }
    return ReviewTimingEdit(timing, minute as int?);
  }
}
