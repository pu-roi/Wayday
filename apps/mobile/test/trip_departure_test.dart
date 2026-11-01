import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/planning/domain/trip_departure.dart';

void main() {
  test('the reported dates compare correctly in Philippine time', () {
    final selected = DayPlan(errands: [], date: '2026-10-30', departure: 510);
    expect(
      tripDepartureHasPassed(
        selected,
        now: DateTime.parse('2026-10-30T03:27:00+08:00'),
      ),
      isFalse,
    );
    expect(
      tripDepartureHasPassed(
        selected,
        now: DateTime.parse('2026-10-30T11:49:00+08:00'),
      ),
      isTrue,
    );
    expect(
      tripDepartureHasPassed(
        selected.copyWith(date: '2026-10-29'),
        now: DateTime.parse('2026-10-30T03:27:00+08:00'),
      ),
      isTrue,
    );
    expect(
      tripDepartureHasPassed(
        selected.copyWith(date: '2026-10-31'),
        now: DateTime.parse('2026-10-30T11:49:00+08:00'),
      ),
      isFalse,
    );
  });

  test('UTC and local instants agree at midnight and minute boundaries', () {
    final selected = DayPlan(errands: [], date: '2026-10-30', departure: 0);
    expect(
      tripDepartureHasPassed(selected, now: DateTime.utc(2026, 10, 29, 15, 59)),
      isFalse,
    );
    expect(
      tripDepartureHasPassed(
        selected,
        now: DateTime.utc(2026, 10, 29, 16, 0, 59),
      ),
      isFalse,
    );
    expect(
      tripDepartureHasPassed(selected, now: DateTime.utc(2026, 10, 29, 16, 1)),
      isTrue,
    );
  });
}
