import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/planning_models.dart';
import 'planning_budget_storage.dart';

final googleTestingBudgetProvider = Provider(
  (ref) => PlanningBudget(
    allocation: () async {
      if (!kDebugMode) return 0;
      final app = await const MethodChannel(
        'wayday/planning',
      ).invokeMapMethod<String, String>('identity');
      return switch (app?['package']) {
        'dev.wayday.wayday' => 8000000,
        'dev.wayday.wayday.maptest' => 2000000,
        _ => 0,
      };
    },
  ),
);

/// Counts units, not just HTTP starts. Failed dispatched requests remain consumed.
class PlanningBudget {
  PlanningBudget({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
    DateTime Function()? now,
    Future<int> Function()? allocation,
  }) : read = read ?? readPlanningBudget,
       write = write ?? writePlanningBudget,
       now = now ?? DateTime.now,
       allocation = allocation ?? (() async => 8000000);
  final Future<int> Function() allocation;
  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  final DateTime Function() now;
  Future<void> _tail = Future.value();

  /// Additional testing allocation, in USD millionths. No assumed free credit,
  /// expiry, automatic refill, or erasure of the legacy request counters.
  Future<void> google(
    String sku,
    int units,
    int unitMicros, {
    bool checkOnly = false,
    bool release = false,
  }) {
    final result = _tail.then((_) async {
      try {
        if (units < 1 || unitMicros < 1) throw const FormatException();
        final raw = await read();
        final root = raw == null
            ? <String, dynamic>{'version': 1, 'entries': <dynamic>[]}
            : jsonDecode(raw) as Map<String, dynamic>;
        if (root['version'] != 1 || root['entries'] is! List) {
          throw const FormatException();
        }
        for (final entry in root['entries'] as List) {
          if (entry is! Map ||
              entry['kind'] is! String ||
              entry['units'] is! int ||
              (entry['units'] as int) < 1 ||
              DateTime.parse(entry['at'] as String).isAfter(now().toUtc())) {
            throw const FormatException();
          }
        }
        final maximum = await allocation();
        final saved = root['testing'] as Map?;
        if (saved != null &&
            (saved['limitMicros'] is! int ||
                saved['usedMicros'] is! int ||
                saved['services'] is! Map ||
                saved['startedAt'] is! String)) {
          throw const FormatException();
        }
        if (saved != null) {
          final services = saved['services'] as Map;
          if (services.values.any((v) => v is! int || v < 0) ||
              services.values.fold<int>(0, (sum, v) => sum + (v as int)) !=
                  saved['usedMicros']) {
            throw const FormatException();
          }
          DateTime.parse(saved['startedAt'] as String);
        }

        if (saved != null && saved['version'] != 1) {
          throw const FormatException();
        }
        final limit = saved?['limitMicros'] as int? ?? maximum;
        final used = saved?['usedMicros'] as int? ?? 0;
        if (limit < 0 || used < 0 || limit > maximum) {
          throw const FormatException();
        }
        final cost = units * unitMicros * (release ? -1 : 1);
        if (used + cost < 0) throw const FormatException();
        if (used + cost > limit) {
          throw PlanningFailure(
            'Google testing budget: US\$${(used / 1000000).toStringAsFixed(2)} of US\$${(limit / 1000000).toStringAsFixed(2)} reserved. This calculation needs up to US\$${(cost / 1000000).toStringAsFixed(2)} more. Your choices are kept. Review testing usage before increasing the allocation.',
            kind: 'testing_budget',
          );
        }
        if (checkOnly) return;
        final services = Map<String, dynamic>.from(
          saved?['services'] as Map? ?? {},
        );
        services[sku] = ((services[sku] as int?) ?? 0) + cost;
        if ((services[sku] as int) < 0) throw const FormatException();
        root['testing'] = {
          'version': 1,
          'limitMicros': limit,
          'usedMicros': used + cost,
          'services': services,
          'startedAt': saved?['startedAt'] ?? now().toUtc().toIso8601String(),
        };
        await write(jsonEncode(root));
      } on PlanningFailure {
        rethrow;
      } catch (_) {
        throw const PlanningFailure(
          'Google testing usage could not be saved. Your choices are kept.',
          kind: 'accounting',
        );
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> reserve(
    String kind,
    int units, {
    required int daily,
    required int monthly,
    bool checkOnly = false,
  }) {
    final result = _tail.then((_) async {
      try {
        final raw = await read();
        final root = raw == null
            ? <String, dynamic>{'version': 1, 'entries': <dynamic>[]}
            : jsonDecode(raw) as Map<String, dynamic>;
        if (root['version'] != 1) throw const FormatException();
        final entries = (root['entries'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final time = now().toUtc();
        for (final e in entries) {
          if (e['kind'] is! String ||
              e['units'] is! int ||
              (e['units'] as int) < 1) {
            throw const FormatException();
          }
          final at = DateTime.parse(e['at'] as String);
          if (at.isAfter(time)) throw const FormatException();
        }
        entries.removeWhere(
          (e) => DateTime.parse(
            e['at'] as String,
          ).isBefore(time.subtract(const Duration(days: 31))),
        );
        int used(Duration age) => entries
            .where(
              (e) =>
                  e['kind'] == kind &&
                  DateTime.parse(e['at'] as String).isAfter(time.subtract(age)),
            )
            .fold(0, (sum, e) => sum + (e['units'] as int));
        if (units < 1 ||
            units + used(const Duration(hours: 24)) > daily ||
            units + used(const Duration(days: 31)) > monthly) {
          throw const PlanningFailure(
            'This device’s planning allowance is exhausted. Your errands are kept.',
            kind: 'quota',
          );
        }
        if (checkOnly) return;
        entries.add({
          'kind': kind,
          'units': units,
          'at': time.toIso8601String(),
        });
        root['entries'] = entries;
        await write(jsonEncode(root));
      } on PlanningFailure {
        rethrow;
      } catch (_) {
        throw const PlanningFailure(
          'Planning is paused because usage accounting could not be saved.',
          kind: 'accounting',
        );
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
