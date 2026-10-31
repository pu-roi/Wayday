import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/today/domain/day.dart';

void main() {
  Map<String, dynamic> input(int suitability, int seconds) => {
    'errands': [const Errand(id: 'a', title: 'Grocery').toJson()],
    'keys': ['s', 'small', 'market', 'e'],
    'matrix': [
      [0, 60, seconds, 60],
      [60, 0, 60, 60],
      [60, 60, 0, 60],
      [60, 60, 60, 0],
    ],
    'departure': 30000,
    'deadline': 60000,
    'start': 's',
    'end': 'e',
    'options': {
      'a': ['small', 'market'],
    },
    'preferences': {
      'a': {
        'small': {'suitability': 1, 'quality': 4.9},
        'market': {'suitability': suitability, 'quality': 3.6},
      },
    },
  };
  String selected(Map<String, dynamic> value) =>
      ((solveDay(value)['schedule'] as Map)['stops'] as List).first['place']
          as String;
  test('suitability precedes travel, travel precedes ratings', () {
    expect(selected(input(2, 180)), 'market');
    expect(selected(input(1, 30)), 'market');
    expect(selected(input(1, 60)), 'small');
  });
}
