import '../../today/domain/day.dart';

/// Compare instants in the plan's Philippine timezone, regardless of the host
/// timezone. Input is minute-precision, so the current minute remains selectable.
bool tripDepartureHasPassed(DayPlan day, {DateTime? now}) {
  final date = DateTime.tryParse(day.date);
  if (date == null ||
      calendarDate(date) != day.date ||
      day.departure < 0 ||
      day.departure > 1439) {
    return false;
  }
  final instant = (now ?? DateTime.now()).toUtc();
  final minute = DateTime.utc(
    instant.year,
    instant.month,
    instant.day,
    instant.hour,
    instant.minute,
  );
  final departure = DateTime.parse(
    '${day.date}T00:00:00+08:00',
  ).add(Duration(minutes: day.departure));
  return departure.isBefore(minute);
}
