import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/today/domain/day.dart';

/// Deliberate one-request qualification; never run as an unattended regression.
/// Uses the separately provisioned private debug credential and finite allowance.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('one bounded live Taglish interpretation', (tester) async {
    final identity = await const MethodChannel(
      'wayday/planning',
    ).invokeMapMethod<String, String>('identity');
    expect(identity?['package'], 'dev.wayday.wayday.maptest');
    final day = DayPlan(
      errands: const [
        Errand(
          id: 'fixture-grocery',
          title: 'Grocery',
          notes: 'Bili ng bigas, toyo, at food supplies for the week.',
          durationMinutes: 40,
          durationConfirmed: true,
        ),
        Errand(
          id: 'fixture-pares',
          title: 'Eat pares',
          notes: 'Kain ng pares pagkatapos ng grocery.',
          durationMinutes: 40,
          durationConfirmed: true,
        ),
        Errand(
          id: 'fixture-pickup',
          title: 'Pick up a friend',
          notes: 'I will choose the meeting point on the map.',
          durationMinutes: 15,
        ),
      ],
    );
    final interpreter = GeminiInterpreter(PlanningBudget());
    final result = await interpreter.interpret(day);
    expect(
      result.needs.map((n) => n.id).toSet(),
      day.errands.map((e) => e.id).toSet(),
    );
    expect(
      result.needs.firstWhere((n) => n.id == 'fixture-pickup').meeting,
      isTrue,
    );
    expect(
      result.needs.firstWhere((n) => n.id == 'fixture-pares').category,
      'food',
    );
    expect(
      result.needs.firstWhere((n) => n.id == 'fixture-pares').after,
      contains('fixture-grocery'),
    );
    expect(
      result.needs.firstWhere((n) => n.id == 'fixture-grocery').items,
      isNotEmpty,
    );
    final before = await const MethodChannel(
      'wayday/planning',
    ).invokeMapMethod<String, dynamic>('geminiStatus');
    await interpreter.interpret(day);
    final after = await const MethodChannel(
      'wayday/planning',
    ).invokeMapMethod<String, dynamic>('geminiStatus');
    expect(after?['remainingGenerations'], before?['remainingGenerations']);
    // Report validation only; never model output, coordinates, task bodies or keys.
    debugPrint('WAYDAY_LIVE_GEMINI_TAGLISH_PASSED requests=1 cacheReused=true');
  });
}
