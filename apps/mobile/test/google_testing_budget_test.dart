import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';

void main() {
  test(
    'unsent reservations can be released and malformed saved allocations fail closed',
    () async {
      String? saved;
      final budget = PlanningBudget(
        read: () async => saved,
        write: (v) async => saved = v,
      );
      await budget.google('places_32000', 1, 32000);
      await budget.google('places_32000', 1, 32000, release: true);
      expect(jsonDecode(saved!)['testing']['usedMicros'], 0);
      saved = jsonEncode({
        'version': 1,
        'entries': <Object?>[],
        'testing': {'version': 999},
      });
      await expectLater(
        budget.google('routes_WALK', 1, 5000),
        throwsA(
          isA<PlanningFailure>().having((e) => e.kind, 'kind', 'accounting'),
        ),
      );
    },
  );
  test(
    'testing allocation survives restart without erasing old counters or refilling',
    () async {
      String? saved = jsonEncode({
        'version': 1,
        'entries': [
          {
            'kind': 'matrix',
            'units': 200,
            'at': DateTime.now().toUtc().toIso8601String(),
          },
        ],
      });
      PlanningBudget open() => PlanningBudget(
        read: () async => saved,
        write: (value) async => saved = value,
        allocation: () async => 100000,
      );
      await open().google('matrix_WALK', 10, 5000);
      await open().google('matrix_WALK', 10, 5000);
      await expectLater(
        open().google('routes_WALK', 1, 5000),
        throwsA(
          isA<PlanningFailure>().having(
            (e) => e.kind,
            'kind',
            'testing_budget',
          ),
        ),
      );
      expect((jsonDecode(saved!)['entries'] as List).length, 1);
      expect(jsonDecode(saved!)['testing']['usedMicros'], 100000);
    },
  );
  test(
    'preflight does not consume allocation and a failed save blocks dispatch',
    () async {
      String? saved;
      final budget = PlanningBudget(
        read: () async => saved,
        write: (value) async => saved = value,
      );
      await budget.google('matrix_WALK', 64, 5000, checkOnly: true);
      expect(saved, isNull);
      final broken = PlanningBudget(
        read: () async => null,
        write: (_) async => throw StateError('disk'),
      );
      await expectLater(
        broken.google('routes_WALK', 1, 5000),
        throwsA(
          isA<PlanningFailure>().having((e) => e.kind, 'kind', 'accounting'),
        ),
      );
    },
  );
}
