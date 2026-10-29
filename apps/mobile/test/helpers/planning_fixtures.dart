// Synthetic fixtures only; never imported by the application.
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/data/road_estimates.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/domain/day.dart';

const pin = PlaceIntent(
  kind: PlaceKind.specific,
  label: 'User-selected test location',
  latitude: 14.58,
  longitude: 121.06,
);
DayPlan fixture() => DayPlan(
  date: calendarDate(DateTime.now().add(const Duration(days: 2))),
  from: 'Start',
  fromPlace: pin,
  to: 'End',
  toPlace: pin,
  errands: [
    const Errand(
      id: 'a',
      title: 'Grocery',
      placeIntent: pin,
      durationMinutes: 20,
      durationConfirmed: true,
    ),
    const Errand(
      id: 'b',
      title: 'Eat pares kasama ang girlfriend ko pagkatapos mamili',
      placeIntent: pin,
      durationMinutes: 40,
      durationConfirmed: true,
    ),
  ],
);

class Interpreter implements ErrandInterpreter {
  @override
  Future<Interpretation> interpret(DayPlan day) async => Interpretation([
    for (final e in day.errands)
      ErrandNeed(
        id: e.id,
        query: e.title,
        category: 'grocery',
        durationMinutes: 15,
        after: e.id == 'b' ? ['a'] : [],
      ),
  ]);
}

class Roads extends PlanningRoads {
  Roads()
    : super(
        http.Client(),
        PlanningBudget(read: () async => null, write: (_) async {}),
      );
  final finished = Completer<void>();
  @override
  Future<Map<String, dynamic>> matrix(
    DayPlan day,
    List<PlanCandidate> points, {
    bool Function()? cancelled,
  }) async => {
    'matrix': List.generate(
      points.length,
      (i) => List.generate(points.length, (j) => i == j ? 0 : 60),
    ),
    'fallback': false,
  };
  @override
  Future<RefinedPlan> refine(
    DayPlan day,
    DaySchedule initial,
    List<PlanCandidate> points, {
    bool Function()? cancelled,
  }) async {
    if (!finished.isCompleted) finished.complete();
    return RefinedPlan(initial, [], false);
  }
}

class DeferredInterpreter implements ErrandInterpreter {
  final response = Completer<Interpretation>();
  @override
  Future<Interpretation> interpret(DayPlan day) => response.future;
}
