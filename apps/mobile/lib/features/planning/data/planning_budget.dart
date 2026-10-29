import 'dart:convert';
import '../domain/planning_models.dart';
import 'planning_budget_storage.dart';

/// Counts units, not just HTTP starts. Failed dispatched requests remain consumed.
class PlanningBudget {
  PlanningBudget({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
    DateTime Function()? now,
  }) : read = read ?? readPlanningBudget,
       write = write ?? writePlanningBudget,
       now = now ?? DateTime.now;
  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  final DateTime Function() now;
  Future<void> _tail = Future.value();
  Future<void> reserve(
    String kind,
    int units, {
    required int daily,
    required int monthly,
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
        entries.add({
          'kind': kind,
          'units': units,
          'at': time.toIso8601String(),
        });
        await write(jsonEncode({'version': 1, 'entries': entries}));
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
