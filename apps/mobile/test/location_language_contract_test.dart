import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/location_intent_resolver.dart';
import 'package:wayday/features/planning/domain/location_assessment.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/domain/errand_location_review.dart';
import 'package:wayday/features/today/domain/day.dart';

/// Held-out language examples with mocked semantic outputs. These exercise
/// transport/policy contracts, not live Gemini accuracy or a runtime dictionary.
const cases = <(String, String, String, LocationIntent)>[
  (
    'en',
    'shopping',
    'Pick up laundry detergent, any supermarket is fine',
    LocationIntent.flexible,
  ),
  (
    'en',
    'shopping',
    'Collect the groceries I already paid for at my selected branch',
    LocationIntent.specific,
  ),
  ('en', 'shopping', 'Get my shopping', LocationIntent.unclear),
  (
    'en',
    'collection',
    'Find somewhere to have my jacket cleaned',
    LocationIntent.flexible,
  ),
  (
    'en',
    'collection',
    'Retrieve my repaired watch from the technician',
    LocationIntent.specific,
  ),
  ('en', 'collection', 'Pick up my food', LocationIntent.unclear),
  (
    'en',
    'appointment',
    'Find an available dentist for a new checkup',
    LocationIntent.flexible,
  ),
  (
    'en',
    'appointment',
    'Attend my booked clinic appointment',
    LocationIntent.specific,
  ),
  ('en', 'appointment', 'Check the clinic', LocationIntent.unclear),
  (
    'en',
    'meeting',
    'Suggest a cafe where I can arrange a meeting with my boss',
    LocationIntent.flexible,
  ),
  (
    'en',
    'meeting',
    'Meet my boss at the office we agreed on',
    LocationIntent.specific,
  ),
  ('en', 'meeting', 'Meet my boss', LocationIntent.unclear),
  (
    'en',
    'recreation',
    'Find any basketball court along the trip',
    LocationIntent.flexible,
  ),
  (
    'en',
    'recreation',
    'Inspect the basketball court I reserved',
    LocationIntent.specific,
  ),
  ('en', 'recreation', 'Checking the basketball court', LocationIntent.unclear),
  (
    'en',
    'service',
    'Find a repair shop for a new phone repair',
    LocationIntent.flexible,
  ),
  (
    'en',
    'service',
    'Collect my phone from the shop repairing it',
    LocationIntent.specific,
  ),
  ('en', 'service', 'Visit the repair shop', LocationIntent.unclear),
  (
    'fil',
    'shopping',
    'Bumili ng sabon kahit saang malapit na tindahan',
    LocationIntent.flexible,
  ),
  (
    'fil',
    'shopping',
    'Kunin ang binayaran kong mga bilihin sa napiling sangay',
    LocationIntent.specific,
  ),
  ('fil', 'shopping', 'Kunin ang mga bilihin ko', LocationIntent.unclear),
  (
    'fil',
    'collection',
    'Maghanap ng paglalabhan ng kumot',
    LocationIntent.flexible,
  ),
  (
    'fil',
    'collection',
    'Kunin ang damit kong ipinatahi',
    LocationIntent.specific,
  ),
  ('fil', 'collection', 'Kunin ang pagkain ko', LocationIntent.unclear),
  (
    'fil',
    'appointment',
    'Maghanap ng dentista para magpatingin',
    LocationIntent.flexible,
  ),
  (
    'fil',
    'appointment',
    'Pumunta sa nakausap kong doktor para sa takdang pagpapatingin',
    LocationIntent.specific,
  ),
  ('fil', 'appointment', 'Pumunta sa klinika', LocationIntent.unclear),
  (
    'fil',
    'meeting',
    'Maghanap ng lugar para magplano ng pagpupulong',
    LocationIntent.flexible,
  ),
  (
    'fil',
    'meeting',
    'Makipagkita sa amo sa napagkasunduang opisina',
    LocationIntent.specific,
  ),
  ('fil', 'meeting', 'Makipagkita sa amo ko', LocationIntent.unclear),
  (
    'fil',
    'recreation',
    'Maghanap ng kahit anong malapit na palaruan',
    LocationIntent.flexible,
  ),
  (
    'fil',
    'recreation',
    'Tingnan ang palaruang pinareserba ko',
    LocationIntent.specific,
  ),
  ('fil', 'recreation', 'Tingnan ang palaruan', LocationIntent.unclear),
  ('fil', 'service', 'Maghanap ng mapagpapagupitan', LocationIntent.flexible),
  (
    'fil',
    'service',
    'Kunin ang sapatos kong ipinagawa',
    LocationIntent.specific,
  ),
  ('fil', 'service', 'Dumaan sa pagawaan', LocationIntent.unclear),
  (
    'taglish',
    'shopping',
    'Bili ng supplies, wag sa usual store, any suitable shop',
    LocationIntent.flexible,
  ),
  (
    'taglish',
    'shopping',
    'Collect yung groceries na prepaid na sa selected branch',
    LocationIntent.specific,
  ),
  ('taglish', 'shopping', 'Pick up yung groceries', LocationIntent.unclear),
  (
    'taglish',
    'collection',
    'Find a laundry, wala pa akong naiiwang damit',
    LocationIntent.flexible,
  ),
  (
    'taglish',
    'collection',
    'Kunin yung package ko sa delivery pickup point',
    LocationIntent.specific,
  ),
  ('taglish', 'collection', 'Food pickup muna', LocationIntent.unclear),
  (
    'taglish',
    'appointment',
    'Suggest a clinic para sa new checkup',
    LocationIntent.flexible,
  ),
  (
    'taglish',
    'appointment',
    'Attend yung booked appointment ko',
    LocationIntent.specific,
  ),
  ('taglish', 'appointment', 'Check yung doctor', LocationIntent.unclear),
  (
    'taglish',
    'meeting',
    'Suggest somewhere for meeting, wala pang venue',
    LocationIntent.flexible,
  ),
  (
    'taglish',
    'meeting',
    'Meet si boss sa office na agreed na',
    LocationIntent.specific,
  ),
  ('taglish', 'meeting', 'Meet si boss later', LocationIntent.unclear),
  (
    'taglish',
    'recreation',
    'Hanap ng gym, no existing membership',
    LocationIntent.flexible,
  ),
  (
    'taglish',
    'recreation',
    'Check yung reserved court namin',
    LocationIntent.specific,
  ),
  ('taglish', 'recreation', 'Check the court muna', LocationIntent.unclear),
  (
    'taglish',
    'service',
    'Find somewhere para ipaayos yung bike',
    LocationIntent.flexible,
  ),
  (
    'taglish',
    'service',
    'Kunin ang bike na nasa mechanic na',
    LocationIntent.specific,
  ),
  ('taglish', 'service', 'Visit yung mechanic', LocationIntent.unclear),
];

void main() {
  for (final c in cases) {
    test('${c.$1}/${c.$2}: ${c.$3}', () {
      final context = LocationAssessmentContext({
        'version': 1,
        'id': 'a',
        'title': c.$3,
        'notes': 'Supplied text; keep unchanged',
      });
      final body = jsonDecode(locationAssessmentRequest(context));
      expect(
        jsonDecode(body['contents'][0]['parts'][0]['text'] as String)['title'],
        c.$3,
      );
      final result = LocationAssessmentResult.fromJson({
        'id': 'a',
        'locationIntent': c.$4.name,
        'summary': 'Mocked intention',
        'question': c.$4 == LocationIntent.unclear
            ? 'Specific place or suitable recommendation?'
            : null,
      }, 'a');
      final e = Errand(id: 'a', title: c.$3),
          need = ErrandNeed(
            id: 'a',
            query: 'suitable place',
            locationIntent: result.intent,
          );
      expect(needsActualLocation(e, need), c.$4 == LocationIntent.specific);
      expect(
        needsPlaceRecommendation(e, need),
        c.$4 == LocationIntent.flexible,
      );
      expect(
        needsLocationUnderstanding(e, need),
        c.$4 == LocationIntent.unclear,
      );
      expect(body.containsKey('tools'), isFalse);
    });
  }
}
