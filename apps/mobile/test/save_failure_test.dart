import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/wayday_app.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';

class FailingOnceRepository implements DayRepository {
  DayPlan day = DayPlan(errands: []);
  bool fail = true;
  @override
  DayPlan read() => day;
  @override
  Future<void> save(DayPlan value) async {
    if (fail) {
      fail = false;
      throw StateError('Synthetic storage failure');
    }
    day = value;
  }
}

void main() {
  testWidgets('failed save is visible and retry saves the latest state', (
    tester,
  ) async {
    final repository = FailingOnceRepository();
    final container = ProviderContainer(
      overrides: [dayRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AppShell(location: '/today', child: Text('Today')),
        ),
      ),
    );
    container.read(todayProvider.notifier).add('Errand');
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Today errands could not be saved on this device.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(repository.day.errands.single.title, 'Errand');
    expect(
      find.text('Today errands could not be saved on this device.'),
      findsNothing,
    );
  });
}
