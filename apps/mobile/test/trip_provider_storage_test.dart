import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/navigation_models.dart';
import 'trip_session_test.dart' show tripFixture;

void main() {
  test(
    'provider metadata retains the latest completion and legacy defaults',
    () async {
      final repository = MemoryItineraryRepository();
      final plan = tripFixture();
      await repository.save(plan);
      await repository.updateProgress(plan.complete('a'));
      final changed = await repository.updateNavigationProvider(
        plan.runId,
        TripMapProvider.openStreetMap,
      );
      expect(changed.completed, {'a'});
      expect(changed.navigationProvider, TripMapProvider.openStreetMap);
      final json = changed.toJson()..remove('navigationProvider');
      expect(
        AcceptedItinerary.fromJson(
          json,
          (_) => throw StateError('not Google'),
        ).navigationProvider,
        TripMapProvider.google,
      );
    },
  );
  test('metadata update cannot recreate a finished or replaced trip', () async {
    final repository = MemoryItineraryRepository();
    final plan = tripFixture();
    await repository.save(plan);
    repository.value = null;
    await expectLater(
      repository.updateNavigationProvider(
        plan.runId,
        TripMapProvider.openStreetMap,
      ),
      throwsA(anything),
    );
    expect(await repository.read(), isNull);
  });
}
