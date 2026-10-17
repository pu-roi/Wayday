import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/errands/domain/errand.dart';
import 'package:wayday/features/errands/domain/errand_interpreter.dart';
import 'package:wayday/features/places/domain/place_intent.dart';

void main() {
  test('saved aliases match explicit places and do not invent coordinates', () {
    const places = [
      SavedPlace(
        id: 'office',
        place: PlaceIntent(label: 'My office'),
      ),
    ];
    final result = interpretErrand(
      'Get documents at My office',
      savedPlaces: places,
    );
    expect(result.place!.savedPlaceId, 'office');
    expect(result.place!.hasCoordinates, isFalse);
    expect(
      interpretErrand(
        'Get documents at My office annex',
        savedPlaces: places,
      ).place,
      isNull,
    );
  });
  test('multiple times need review instead of choosing the first', () {
    final result = interpretErrand('Arrive by 4 PM and finish before 5 PM');
    expect(result.timing, isNull);
    expect(result.questions.join(' '), contains('More than one time'));
  });
  test(
    'explicit brand, finish deadline and duration remain separate suggestions',
    () {
      final result = interpretErrand(
        'Buy groceries at any Puregold, finish before 5 PM, allow 30 minutes.',
      );
      expect(result.place!.brand, 'Puregold');
      expect(result.place!.category, 'groceries');
      expect(result.place!.hasCoordinates, isFalse);
      expect(result.timing, TimingRule.finishBefore);
      expect(result.minute, 1020);
      expect(result.durationMinutes, 30);
    },
  );
  test('arrival deadline differs from completion deadline', () {
    expect(interpretErrand('Arrive by 4 PM').timing, TimingRule.arriveBy);
    expect(
      interpretErrand('Finish before 4 PM').timing,
      TimingRule.finishBefore,
    );
  });
  test(
    'Filipino and Taglish explicit phrases work without guessing places',
    () {
      final result = interpretErrand(
        'Mamili sa palengke, tapos bago 4 pm, laan 30 minuto, kung may oras',
      );
      expect(result.timing, TimingRule.finishBefore);
      expect(result.minute, 960);
      expect(result.durationMinutes, 30);
      expect(result.optional, isTrue);
      expect(result.place, isNull);
      expect(result.questions, contains('Choose the specific place you mean.'));
      expect(
        interpretErrand('Pagupit kung may time').place!.category,
        'haircut',
      );
      expect(interpretErrand('Bili gamot').place!.category, 'pharmacy');
    },
  );
  test('ambiguous hours and before-versus-arrival require clarification', () {
    final ambiguous = interpretErrand('Meet at 5');
    expect(ambiguous.minute, isNull);
    expect(ambiguous.questions.join(' '), contains('AM or PM'));
    final before = interpretErrand('Groceries before 5 PM');
    expect(before.timing, isNull);
    expect(before.questions.join(' '), contains('arrive by'));
  });
  test('24-hour input and noon/midnight are explicit', () {
    expect(interpretErrand('Meet at 17:30').minute, 1050);
    expect(interpretErrand('Meet at 12 PM').minute, 720);
    expect(interpretErrand('Meet at 12 AM').minute, 0);
  });
  test(
    'invalid times, durations and unknown dependencies are never invented',
    () {
      expect(interpretErrand('Meet at 25:99').minute, isNull);
      expect(interpretErrand('Spend for 0 minutes').durationMinutes, isNull);
      final unknown = interpretErrand('Lunch with her after');
      expect(unknown.hasDetails, isFalse);
      expect(unknown.minute, isNull);
    },
  );
  test('word boundaries prevent accidental category matches', () {
    expect(interpretErrand('Discuss banking').place, isNull);
    expect(interpretErrand('Haircut').place!.category, 'haircut');
  });
}
