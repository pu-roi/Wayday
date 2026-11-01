import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/interpretation_request.dart';
import 'package:wayday/features/planning/domain/place_search_intent.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'package:wayday/features/today/domain/day.dart';

void main() {
  test(
    'invalid optional hints do not discard validated meaning or clarification',
    () {
      const need = ErrandNeed(
        id: 'a',
        query: 'supermarket',
        category: 'grocery',
        items: ['rice'],
      );
      final context = ClarificationContext.create(
        const Errand(id: 'a', title: 'Groceries'),
        need,
        const [Errand(id: 'a', title: 'Groceries')],
      );
      final resolution = {
        'id': 'a',
        ...const ClarificationResolution(
          outcome: 'flexible',
          kind: 'preference',
          summary: 'General groceries',
          query: 'supermarket',
          category: 'grocery',
          items: ['rice'],
        ).toJson(),
      };
      for (final hints in [
        'not an object',
        {
          'variants': ['grocery'],
          'preferredTypes': ['supermarket'],
          'acceptableTypes': ['market'],
        },
        {
          'variants': ['grocery'],
          'preferredTypes': <String>[],
          'acceptableTypes': ['invented_inventory'],
        },
        {
          'variants': ['a', 'b', 'c', 'd'],
          'preferredTypes': <String>[],
          'acceptableTypes': <String>[],
        },
      ]) {
        final decoded = ErrandNeed.fromJson({
          ...need.toJson(),
          'searchIntent': hints,
        });
        expect(decoded.searchIntent, isNull);
        expect(decoded.query, need.query);
        expect(decoded.items, need.items);
        final clarified = ClarificationResolution.fromJson({
          ...resolution,
          'searchIntent': hints,
        }, context);
        expect(clarified.searchIntent, isNull);
        expect(clarified.items, ['rice']);
        expect(
          () => ErrandNeed.fromJson({
            ...need.toJson(),
            'searchIntent': hints,
            'locationIntent': 'invented',
          }),
          throwsFormatException,
        );
        expect(
          () => ClarificationResolution.fromJson({
            ...resolution,
            'searchIntent': hints,
            'id': 'unrelated',
          }, context),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'transport avoids repeated large enums while preserving local validation',
    () {
      final request =
          jsonDecode(
                interpretationRequest(
                  DayPlan(
                    errands: const [Errand(id: 'sample', title: 'Grocery')],
                  ),
                ),
              )
              as Map;
      for (final key in ['needs', 'additions']) {
        final search =
            request['generationConfig']['responseSchema']['properties'][key]['items']['properties']['searchIntent'];
        for (final types in ['preferredTypes', 'acceptableTypes']) {
          expect(search['properties'][types]['items'], {'type': 'STRING'});
          expect(search['properties'][types]['maxItems'], 12);
        }
      }
      final instruction =
          request['systemInstruction']['parts'][0]['text'] as String;
      for (final type in PlaceSearchIntent.supportedTypes) {
        expect(instruction, contains(type));
      }
      expect(
        () => PlaceSearchIntent.fromJson({
          'variants': ['grocery'],
          'preferredTypes': ['market'],
          'acceptableTypes': ['supermarket'],
        }),
        throwsFormatException,
      );
      expect(
        () => PlaceSearchIntent.fromJson({
          'variants': ['grocery'],
          'preferredTypes': <String>[],
          'acceptableTypes': List.filled(13, 'supermarket'),
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'semantic venue alternatives are bounded and survive interpretation',
    () {
      final intent = PlaceSearchIntent.fromJson({
        'variants': ['rice retailer', 'supermarket', 'public market'],
        'preferredTypes': ['grocery_store', 'market'],
        'acceptableTypes': [
          'grocery_store',
          'market',
          'supermarket',
          'convenience_store',
        ],
      });
      final need = ErrandNeed(
        id: 'rice',
        query: 'rice retailer',
        searchIntent: intent,
      );
      expect(
        ErrandNeed.fromJson(need.toJson()).searchIntent!.variants.last,
        'public market',
      );
      expect(
        () => PlaceSearchIntent.fromJson({
          ...intent.toJson(),
          'variants': ['a', 'b', 'c', 'd'],
        }),
        throwsFormatException,
      );
      expect(
        () => PlaceSearchIntent.fromJson({
          ...intent.toJson(),
          'acceptableTypes': ['invented_rice_inventory'],
        }),
        throwsFormatException,
      );
    },
  );
}
