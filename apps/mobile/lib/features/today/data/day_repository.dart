import '../domain/day.dart';

abstract interface class DayRepository {
  DayPlan read();
  void save(DayPlan day);
}

class MemoryDayRepository implements DayRepository {
  DayPlan _day = exampleDay();
  @override
  DayPlan read() => _day;
  @override
  void save(DayPlan day) => _day = day;
}

DayPlan exampleDay() => DayPlan(
  errands: const [
    Errand(
      id: 'registrar',
      title: 'Get documents from the registrar',
      place: 'PLP · Pasig',
      timing: TimingRule.finishBefore,
      minute: 960,
    ),
    Errand(
      id: 'pitch',
      title: 'Capstone presentation',
      place: 'PLP · Pasig',
      timing: TimingRule.at,
      minute: 660,
    ),
    Errand(
      id: 'pickup',
      title: 'Pick up in Ortigas',
      place: 'Ortigas Center',
      timing: TimingRule.arriveBy,
      minute: 900,
    ),
    Errand(id: 'lunch', title: 'Grab a late lunch', place: 'Choose a place'),
    Errand(
      id: 'groceries',
      title: 'Groceries for home',
      place: 'Choose a place',
      optional: true,
    ),
  ],
);
