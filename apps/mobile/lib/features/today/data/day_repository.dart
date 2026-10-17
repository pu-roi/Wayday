import '../domain/day.dart';

abstract interface class DayRepository {
  DayPlan read();
  void save(DayPlan day);
}

class MemoryDayRepository implements DayRepository {
  MemoryDayRepository({DayPlan? initial}) : _day = initial ?? newDay();
  DayPlan _day;
  @override
  DayPlan read() => _day;
  @override
  void save(DayPlan day) => _day = day;
}

DayPlan newDay() => DayPlan(errands: [], from: '', to: '');
