import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/places/domain/place_intent.dart';

void main() {
  test('only empty default forms follow the Manila day', () {
    final empty = DayPlan(errands: [], date: '2026-10-31');
    expect(empty.canDefaultDate, isTrue);
    expect(empty.copyWith(from: 'Home').canDefaultDate, isFalse);
    expect(empty.copyWith(departure: 600).canDefaultDate, isFalse);
    expect(empty.copyWith(dateSelected: true).canDefaultDate, isFalse);
    expect(
      empty
          .copyWith(
            fromPlace: const PlaceIntent(
              kind: PlaceKind.providerReference,
              provider: 'google_places_sdk',
              providerPlaceId: 'retained-branch',
            ),
          )
          .canDefaultDate,
      isFalse,
    );
    expect(
      empty
          .copyWith(toPlace: const PlaceIntent(savedPlaceId: 'home'))
          .canDefaultDate,
      isFalse,
    );
    expect(
      DayPlan(
        errands: [Errand(id: 'x', title: 'Rice')],
      ).canDefaultDate,
      isFalse,
    );
  });
  test('legacy dates stay selected and new selection state round trips', () {
    final raw = DayPlan(errands: [], date: '2026-10-31').toJson();
    raw.remove('dateSelected');
    expect(DayPlan.fromJson(raw).canDefaultDate, isFalse);
    raw['dateSelected'] = false;
    expect(DayPlan.fromJson(raw).canDefaultDate, isTrue);
    expect(pilotToday(DateTime.utc(2026, 10, 31, 16)), '2026-11-01');
  });
}
