import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/interpretation_request.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';

class _CountingInterpreter extends Interpreter {
  int calls = 0;
  @override
  Future<Interpretation> interpret(DayPlan day) {
    calls++;
    return super.interpret(day);
  }
}

class _CountingRoads extends Roads {
  int calls = 0;
  @override
  Future<Map<String, dynamic>> matrix(
    DayPlan day,
    List<PlanCandidate> points, {
    bool Function()? cancelled,
  }) {
    calls++;
    return super.matrix(day, points, cancelled: cancelled);
  }
}

void main() {
  test(
    'restoring a clock cannot silently resolve an ordering question',
    () async {
      final source = fixture(), roads = Roads();
      addTearDown(roads.client.close);
      final model = PlanningController(
        source,
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
      );
      await model.understand();
      model.needs['a'] = const ErrandNeed(
        id: 'a',
        query: 'grocery',
        question: 'Which errand must happen first?',
      );
      model.edit(
        source.errands.first.copyWith(
          timing: TimingRule.arriveBy,
          minute: 870,
          confirmedFields: {'timing'},
        ),
      );
      expect(
        model.applyReview,
        throwsA(
          isA<PlanningFailure>().having((f) => f.kind, 'kind', 'clarification'),
        ),
      );
      model.dispose();
    },
  );
  test(
    'invalid source fields and broken graphs never reach the interpreter',
    () async {
      final source = fixture(),
          interpreter = _CountingInterpreter(),
          roads = Roads();
      addTearDown(roads.client.close);
      for (final invalid in [
        source.copyWith(errands: [source.errands.first.copyWith(title: '')]),
        source.copyWith(
          errands: [source.errands.first.copyWith(durationMinutes: 0)],
        ),
        source.copyWith(
          errands: [
            source.errands.first.copyWith(afterErrandIds: ['missing']),
          ],
        ),
      ]) {
        final model = PlanningController(
          invalid,
          interpreter,
          roads,
          MemoryItineraryRepository(),
        );
        await model.understand();
        expect(model.stage, PreparationStage.failed);
        expect(model.error, isNotNull);
        expect(
          () => interpretationRequest(invalid),
          throwsA(isA<PlanningFailure>()),
        );
        model.dispose();
      }
      expect(interpreter.calls, 0);
    },
  );

  test(
    'controller review and calculation reject invalid clock inputs before roads',
    () async {
      final source = fixture(), roads = _CountingRoads();
      addTearDown(roads.client.close);
      final model = PlanningController(
        source,
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
      );
      await model.understand();
      model.day = model.day.copyWith(
        departure: 780,
        errands: [
          source.errands.first.copyWith(
            timing: TimingRule.arriveBy,
            minute: 570,
          ),
        ],
      );
      await model.calculate();
      expect(model.stage, PreparationStage.discovery);
      expect(model.error, contains('9:30 AM'));
      model.day = source.copyWith(date: '2020-01-01');
      await model.calculate();
      expect(model.error, contains('departure is in the past'));
      model.day = source.copyWith(
        errands: [
          source.errands.first.copyWith(afterErrandIds: ['missing']),
        ],
      );
      await model.calculate();
      expect(model.error, isNotNull);
      expect(roads.calls, 0);
      // A missing road matrix cannot mask this structural timing failure.
      model.dispose();
    },
  );
}
