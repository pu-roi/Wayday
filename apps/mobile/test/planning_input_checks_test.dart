import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/planning/domain/planning_input_checks.dart';

void main() {
  DayPlan trip(
    List<Errand> errands, {
    int departure = 780,
    int deadline = 1080,
  }) => DayPlan(
    date: '2026-12-01',
    errands: errands,
    departure: departure,
    deadline: deadline,
  );
  test('a required 9:30 arrival cannot follow a 1 PM departure', () {
    final e = const Errand(
      id: 'a',
      title: 'Pick up my girlfriend',
      timing: TimingRule.arriveBy,
      minute: 570,
    );
    final issues = planningInputChecks(trip([e]), [e]);
    expect(issues, hasLength(1));
    expect(issues.single.errand!.id, 'a');
    expect(issues.single.message, contains('9:30 AM'));
    expect(issues.single.message, contains('1:00 PM'));
  });
  test(
    'set-time, finish deadlines and final window use configured visit time',
    () {
      const at = Errand(
        id: 'a',
        title: 'Appointment',
        timing: TimingRule.at,
        minute: 570,
      );
      expect(planningInputChecks(trip([at]), [at]), isNotEmpty);
      const finish = Errand(
        id: 'a',
        title: 'Submit',
        durationMinutes: 40,
        timing: TimingRule.finishBefore,
        minute: 810,
      );
      expect(planningInputChecks(trip([finish]), [finish]), isNotEmpty);
      const long = Errand(id: 'a', title: 'Visit', durationMinutes: 400);
      expect(planningInputChecks(trip([long]), [long]), isNotEmpty);
    },
  );
  test(
    'future appointments and exact boundary arrivals are not falsely blocked',
    () {
      const e = Errand(
        id: 'a',
        title: 'Pickup',
        timing: TimingRule.arriveBy,
        minute: 570,
      );
      expect(planningInputChecks(trip([e], departure: 510), [e]), isEmpty);
      expect(planningInputChecks(trip([e], departure: 570), [e]), isEmpty);
    },
  );
  test(
    'optional missed appointments may be omitted unless required as a prerequisite',
    () {
      const optional = Errand(
        id: 'a',
        title: 'Optional',
        optional: true,
        timing: TimingRule.at,
        minute: 570,
      );
      expect(planningInputChecks(trip([optional]), [optional]), isEmpty);
      const required = Errand(
        id: 'b',
        title: 'Required',
        afterErrandIds: ['a'],
      );
      expect(
        planningInputChecks(trip([optional, required]), [
          optional,
          required,
        ]).any((i) => i.errand?.id == 'a'),
        isTrue,
      );
    },
  );
  test(
    'dependency service bounds detect impossible appointments but allow shared arrival',
    () {
      const a = Errand(id: 'a', title: 'First', durationMinutes: 60);
      const at = Errand(
        id: 'b',
        title: 'Second',
        afterErrandIds: ['a'],
        timing: TimingRule.at,
        minute: 810,
      );
      expect(planningInputChecks(trip([a, at]), [a, at]), isNotEmpty);
      const arrive = Errand(
        id: 'b',
        title: 'Shared visit',
        afterErrandIds: ['a'],
        timing: TimingRule.arriveBy,
        minute: 810,
      );
      expect(planningInputChecks(trip([a, arrive]), [a, arrive]), isEmpty);
    },
  );
  test(
    'date, timezone, numeric range and trip-window structure are verified',
    () {
      const e = Errand(id: 'a', title: 'Visit');
      for (final day in [
        trip([e]).copyWith(date: '2026-02-30'),
        trip([e]).copyWith(timeZone: 'Other'),
        trip([e], departure: -1),
        trip([e], deadline: 1440),
        trip([e], departure: 1080),
      ]) {
        expect(planningInputChecks(day, [e]), isNotEmpty);
      }
    },
  );
  test(
    'errand identity, title, duration and missing time fail structural validation',
    () {
      for (final errands in <List<Errand>>[
        [],
        [const Errand(id: '', title: 'Visit')],
        [const Errand(id: 'a', title: ' ')],
        [const Errand(id: 'a', title: 'Visit', durationMinutes: 0)],
        [const Errand(id: 'a', title: 'Visit', durationMinutes: 1441)],
        [const Errand(id: 'a', title: 'Visit', timing: TimingRule.at)],
        [const Errand(id: 'a', title: 'Visit', minute: 1440)],
        [
          const Errand(id: 'a', title: 'Visit'),
          const Errand(id: 'a', title: 'Duplicate'),
        ],
      ]) {
        expect(errandFieldChecks(errands), isNotEmpty);
      }
    },
  );
}
