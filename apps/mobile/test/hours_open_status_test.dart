import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/domain/business_hours.dart';

void main() {
  test(
    'open status uses exclusive closing boundaries and keeps unknown distinct',
    () {
      const available = HoursDay(
        HoursState.available,
        windows: [
          [32400, 43200],
          [46800, 75600],
        ],
      );
      expect(available.openAt(32400), isTrue);
      expect(available.openAt(43200), isFalse);
      expect(available.openAt(46800), isTrue);
      expect(available.openAt(75600), isFalse);
      expect(
        const HoursDay(HoursState.available, windows: []).openAt(36000),
        isFalse,
      );
      for (final state in HoursState.values.where(
        (s) => s != HoursState.available,
      )) {
        expect(HoursDay(state).openAt(36000), isNull);
      }
    },
  );
}
