import '../../errands/domain/errand.dart';

enum RepeatPattern {
  asNeeded('As needed'),
  weekly('Weekly'),
  fortnightly('Every 2 weeks'),
  monthly('Monthly');

  const RepeatPattern(this.label);
  final String label;
}

const weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class ErrandGroup {
  ErrandGroup({
    required this.id,
    required this.name,
    required List<Errand> items,
    this.repeat = RepeatPattern.asNeeded,
    this.day = 6,
  }) : items = List.unmodifiable(items);
  final String id;
  final String name;
  final List<Errand> items;
  final RepeatPattern repeat;
  final int day;
  String get schedule => switch (repeat) {
    RepeatPattern.asNeeded => 'Whenever you need it',
    RepeatPattern.weekly => 'Weekly · ${weekdays[day - 1]}',
    RepeatPattern.fortnightly => 'Every 2 weeks · ${weekdays[day - 1]}',
    RepeatPattern.monthly => 'Monthly · Day $day',
  };
}
