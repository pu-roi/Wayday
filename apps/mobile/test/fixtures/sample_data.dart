import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/recurring/domain/errand_group.dart';

DayPlan fixtureDay() => DayPlan(
  from: 'PLP',
  to: 'Home',
  departure: 510,
  deadline: 1080,
  profile: TravelProfile.motor,
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

List<ErrandGroup> fixtureGroups() => [
  ErrandGroup(
    id: 'weekly',
    name: 'Weekly essentials',
    repeat: RepeatPattern.weekly,
    items: const [
      Errand(
        id: 'weekly-groceries',
        title: 'Stock up on groceries',
        notes: 'Vegetables\nFruits\nMeat',
      ),
      Errand(id: 'weekly-laundry', title: 'Pick up the laundry'),
      Errand(id: 'weekly-cat', title: 'Get cat food'),
    ],
  ),
  ErrandGroup(
    id: 'midweek',
    name: 'A little reset',
    items: const [
      Errand(id: 'midweek-pharmacy', title: 'Stop by the pharmacy'),
      Errand(
        id: 'midweek-coffee',
        title: 'Coffee and a quiet moment',
        optional: true,
      ),
    ],
  ),
];
