import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';

class QuestionInterpreter implements ErrandInterpreter {
  QuestionInterpreter(this.needs);
  final List<ErrandNeed> needs;
  @override
  Future<Interpretation> interpret(DayPlan day) async => Interpretation(needs);
}

void main() {
  test(
    'saved locations answer where questions; unattached errands get recommendations',
    () async {
      final day = fixture().copyWith(
        errands: const [
          Errand(
            id: 'pickup',
            title: 'Pick up my girlfriend',
            placeIntent: pin,
          ),
          Errand(id: 'pares', title: 'Eat pares', placeIntent: pin),
          // Clearing a previous place can leave confirmation metadata behind.
          Errand(id: 'grocery', title: 'Grocery', confirmedFields: {'place'}),
          Errand(id: 'icecream', title: 'Kumain ng ice cream'),
        ],
      );
      final roads = Roads();
      addTearDown(roads.client.close);
      final model = PlanningController(
        day,
        QuestionInterpreter(const [
          ErrandNeed(
            id: 'pickup',
            query: 'pickup',
            category: 'meeting',
            question: 'Where should I pick up your girlfriend?',
          ),
          ErrandNeed(
            id: 'pares',
            query: 'pares',
            category: 'food',
            question: 'Where is the pares house located?',
          ),
          ErrandNeed(
            id: 'grocery',
            query: 'grocery store',
            category: 'grocery',
            question: 'Which store would you like to visit?',
          ),
          ErrandNeed(
            id: 'icecream',
            query: 'ice cream',
            category: 'convenience',
            question: 'Saan mo gustong bumili ng ice cream?',
          ),
        ]),
        roads,
        MemoryItineraryRepository(),
      );
      addTearDown(model.dispose);
      await model.understand();
      expect(model.applyReview, returnsNormally);
      expect(model.stage, PreparationStage.discovery);
      expect(model.candidates.keys.toSet(), {'pickup', 'pares'});
      expect(model.unresolved.map((e) => e.id), ['grocery', 'icecream']);
    },
  );

  test('genuine non-location questions still require clarification', () async {
    final roads = Roads();
    addTearDown(roads.client.close);
    final day = fixture().copyWith(errands: [fixture().errands.first]);
    final model = PlanningController(
      day,
      QuestionInterpreter(const [
        ErrandNeed(
          id: 'a',
          query: 'grocery',
          category: 'grocery',
          question: 'Which errand should this happen after?',
        ),
      ]),
      roads,
      MemoryItineraryRepository(),
    );
    addTearDown(model.dispose);
    await model.understand();
    expect(
      model.applyReview,
      throwsA(
        isA<PlanningFailure>().having((e) => e.kind, 'kind', 'clarification'),
      ),
    );
  });

  test('private pickup without a point uses location correction', () async {
    final roads = Roads();
    addTearDown(roads.client.close);
    final model = PlanningController(
      fixture().copyWith(
        errands: const [Errand(id: 'a', title: 'Pick up Ana')],
      ),
      QuestionInterpreter(const [
        ErrandNeed(
          id: 'a',
          query: 'pickup',
          category: 'meeting',
          question: 'Where should I pick up Ana?',
        ),
      ]),
      roads,
      MemoryItineraryRepository(),
    );
    addTearDown(model.dispose);
    await model.understand();
    expect(
      model.applyReview,
      throwsA(
        isA<PlanningFailure>().having(
          (e) => e.kind,
          'kind',
          'missing_location',
        ),
      ),
    );
  });
}
