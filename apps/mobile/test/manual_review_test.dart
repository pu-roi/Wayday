import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wayday/features/review/domain/day_review.dart';
import 'package:wayday/features/review/presentation/day_review_view.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/maps/presentation/regional_map.dart';
import 'package:wayday/features/places/domain/place_intent.dart';

void main() {
  testWidgets('manual review displays selected places without claiming a route', (
    tester,
  ) async {
    final day = DayPlan(
      errands: const [
        Errand(
          id: 'a',
          title: 'First',
          placeIntent: PlaceIntent(
            kind: PlaceKind.specific,
            label: 'Cebu',
            latitude: 10.3,
            longitude: 123.9,
          ),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        dayRepositoryProvider.overrideWithValue(
          MemoryDayRepository(initialData: day),
        ),
        mapPlatformSupportedProvider.overrideWithValue(true),
        placeMapBuilderProvider.overrideWithValue(
          (request) => Text(
            'Pinned: ${request.pins.where((pin) => pin.place.hasCoordinates).length}',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(), home: const DayReviewView()),
      ),
    );
    expect(find.text('Pinned: 1'), findsOneWidget);
    expect(
      find.text(
        'Your order. Travel times and opening hours are not checked yet.',
      ),
      findsOneWidget,
    );
  });
  testWidgets('stale manual review does not overwrite newer errands', (
    tester,
  ) async {
    final repo = MemoryDayRepository(
      initialData: DayPlan(
        errands: const [Errand(id: 'a', title: 'First')],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        dayRepositoryProvider.overrideWithValue(repo),
        mapPlatformSupportedProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(), home: const DayReviewView()),
      ),
    );
    container.read(todayProvider.notifier).add('Newer');
    await tester.pump();
    await tester.tap(find.text('Save manual order'));
    await tester.pump();
    expect(
      find.text(
        'Today changed while this review was open. Reload it before saving.',
      ),
      findsOneWidget,
    );
    expect(container.read(todayProvider).errands.map((e) => e.title), [
      'First',
      'Newer',
    ]);
  });
  test('manual review rejects moving an errand ahead of its prerequisite', () {
    final review = DayReview(
      DayPlan(
        errands: const [
          Errand(id: 'a', title: 'Pick up'),
          Errand(id: 'b', title: 'Deliver', afterErrandIds: ['a']),
        ],
      ),
    );
    expect(review.move(1, 0), isNotNull);
    expect(review.day.errands.map((item) => item.id), ['a', 'b']);
  });

  test('manual review can reorder independent errands', () {
    final review = DayReview(
      DayPlan(
        errands: const [
          Errand(id: 'a', title: 'First'),
          Errand(id: 'b', title: 'Second'),
        ],
      ),
    );
    expect(review.move(1, 0), isNull);
    expect(review.day.errands.map((item) => item.id), ['b', 'a']);
  });
}
