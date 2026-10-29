import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/planning_view.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'package:wayday/features/today/domain/day.dart';

class _Deferred implements ErrandInterpreter {
  final pending = Completer<Interpretation>();
  int calls = 0;
  @override
  Future<Interpretation> interpret(DayPlan day) {
    calls++;
    return pending.future;
  }
}

void main() {
  testWidgets(
    'Plan my day opens loading immediately, Back and reopen recover the same pending result',
    (tester) async {
      final service = _Deferred();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interpreterProvider.overrideWithValue(service),
            dayRepositoryProvider.overrideWithValue(
              MemoryDayRepository(
                initialData: DayPlan(
                  errands: [const Errand(id: 'a', title: 'Grocery')],
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: buildTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const PlanningView()),
                  ),
                  child: const Text('Plan my day'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Plan my day'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Understanding your errands…'), findsOneWidget);
      expect(find.text('Continue with Gemini'), findsNothing);
      expect(find.text('Let’s put your day in order'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      service.pending.complete(
        Interpretation([
          const ErrandNeed(id: 'a', query: 'grocery', category: 'grocery'),
        ]),
      );
      await tester.pump();
      await tester.tap(find.text('Plan my day'));
      await tester.pumpAndSettle();
      expect(find.text('Review errands'), findsOneWidget);
      // Missing endpoints expand trip details; the errand list remains scrollable.
      await tester.scrollUntilVisible(find.text('Grocery'), 180);
      await tester.pumpAndSettle();
      expect(find.text('Grocery'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // The presentation may reattach to the service twice; the interpreter's
      // actual request coalescing/durable cache is tested independently.
      expect(service.calls, 2);
    },
  );
}
