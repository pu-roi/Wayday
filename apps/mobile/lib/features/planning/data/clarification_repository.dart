import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../core/data/wayday_database.dart';
import '../../../core/data/serial_write_queue.dart';
import '../../today/domain/day.dart';
import '../domain/clarification.dart';
import 'interpretation_request.dart';

String clarificationSourceKey(DayPlan day) => clarificationHash(
  jsonDecode(legacyInterpretationRequest(day))['contents'] as Object,
);

abstract interface class ClarificationRepository {
  Future<ClarificationSession> read(String key);
  Future<void> save(String key, ClarificationSession session);
}

class MemoryClarificationRepository implements ClarificationRepository {
  final _values = <String, String>{};
  final _queue = SerialWriteQueue();
  @override
  Future<ClarificationSession> read(String key) async => _values[key] == null
      ? ClarificationSession()
      : ClarificationSession.fromJson(
          jsonDecode(_values[key]!) as Map<String, dynamic>,
        );
  @override
  Future<void> save(String key, ClarificationSession session) {
    final snapshot = ClarificationSession.fromJson(
      jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>,
    );
    return _queue.enqueue(() async {
      final merged = mergeClarifications(await read(key), snapshot);
      _values.remove(key);
      _values[key] = jsonEncode(merged.toJson());
      while (_values.length > 8) {
        _values.remove(_values.keys.first);
      }
    });
  }
}

class SqliteClarificationRepository implements ClarificationRepository {
  SqliteClarificationRepository(this.database);
  final WaydayDatabase database;
  final _queue = SerialWriteQueue();
  @override
  Future<ClarificationSession> read(String key) async {
    var result = ClarificationSession();
    await _queue.enqueue(() async {
      final row = await (database.select(
        database.clarificationSessions,
      )..where((t) => t.sourceKey.equals(key))).getSingleOrNull();
      if (row != null) {
        result = ClarificationSession.fromJson(
          jsonDecode(row.payload) as Map<String, dynamic>,
        );
      }
    });
    return result;
  }

  @override
  Future<void> save(String key, ClarificationSession session) {
    final payload = jsonEncode(session.toJson());
    return _queue.enqueue(
      () => database.transaction(() async {
        final previous = await (database.select(
          database.clarificationSessions,
        )..where((t) => t.sourceKey.equals(key))).getSingleOrNull();
        final incoming = ClarificationSession.fromJson(
          jsonDecode(payload) as Map<String, dynamic>,
        );
        final merged = previous == null
            ? incoming
            : mergeClarifications(
                ClarificationSession.fromJson(
                  jsonDecode(previous.payload) as Map<String, dynamic>,
                ),
                incoming,
              );
        await database
            .into(database.clarificationSessions)
            .insertOnConflictUpdate(
              ClarificationSessionsCompanion.insert(
                sourceKey: key,
                payload: jsonEncode(merged.toJson()),
                updatedAt: DateTime.now().microsecondsSinceEpoch,
              ),
            );
        final rows = await (database.select(
          database.clarificationSessions,
        )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
        for (final row in rows.skip(8)) {
          await (database.delete(
            database.clarificationSessions,
          )..where((t) => t.sourceKey.equals(row.sourceKey))).go();
        }
      }),
    );
  }
}
