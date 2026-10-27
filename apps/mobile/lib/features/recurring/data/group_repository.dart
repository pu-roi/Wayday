import 'dart:convert';
import 'package:drift/drift.dart';

import '../../../core/data/serial_write_queue.dart';
import '../../errands/domain/errand.dart';
import '../domain/errand_group.dart';
import '../../../core/data/wayday_database.dart';

abstract interface class GroupRepository {
  List<ErrandGroup> read();
  Future<void> save(List<ErrandGroup> groups);
}

class MemoryGroupRepository implements GroupRepository {
  MemoryGroupRepository({List<ErrandGroup>? initialData})
    : _groups = List.unmodifiable(initialData ?? const <ErrandGroup>[]);

  List<ErrandGroup> _groups;

  @override
  List<ErrandGroup> read() => _groups;

  @override
  Future<void> save(List<ErrandGroup> groups) async {
    _groups = List.unmodifiable(groups);
  }
}

class SqliteGroupRepository implements GroupRepository {
  SqliteGroupRepository._(this._database, this._groups);

  final WaydayDatabase _database;
  final SerialWriteQueue _writes = SerialWriteQueue();
  List<ErrandGroup> _groups;

  static Future<SqliteGroupRepository> open(WaydayDatabase database) async {
    final groupRows = await (database.select(
      database.recurringGroups,
    )..orderBy([(row) => OrderingTerm.asc(row.position)])).get();
    final itemRows = await (database.select(
      database.groupErrands,
    )..orderBy([(row) => OrderingTerm.asc(row.position)])).get();
    return SqliteGroupRepository._(database, [
      for (final group in groupRows)
        ErrandGroup(
          id: group.id,
          name: group.name,
          repeat: _parseRepeat(group.repeat),
          day: group.day,
          items: [
            for (final item in itemRows.where(
              (item) => item.groupId == group.id,
            ))
              item.details != null
                  ? Errand.fromJson(
                      jsonDecode(item.details!) as Map<String, dynamic>,
                    )
                  : Errand(
                      id: item.id,
                      title: item.title,
                      place: item.place,
                      notes: item.notes,
                      timing: _parseTiming(item.timing),
                      minute: item.minute,
                      optional: item.optional,
                    ),
          ],
        ),
    ]);
  }

  @override
  List<ErrandGroup> read() => _groups;

  @override
  Future<void> save(List<ErrandGroup> groups) =>
      _writes.enqueue(() => _save(List.unmodifiable(groups)));

  Future<void> _save(List<ErrandGroup> groups) async {
    await _database.transaction(() async {
      await _database.delete(_database.groupErrands).go();
      await _database.delete(_database.recurringGroups).go();
      if (groups.isNotEmpty) {
        await _database.batch((batch) {
          batch.insertAll(_database.recurringGroups, [
            for (var position = 0; position < groups.length; position++)
              RecurringGroupsCompanion.insert(
                id: groups[position].id,
                position: position,
                name: groups[position].name,
                repeat: groups[position].repeat.name,
                day: groups[position].day,
              ),
          ]);
          final items = <GroupErrandsCompanion>[];
          for (final group in groups) {
            for (var position = 0; position < group.items.length; position++) {
              items.add(
                _toGroupErrand(group.id, group.items[position], position),
              );
            }
          }
          if (items.isNotEmpty) {
            batch.insertAll(_database.groupErrands, items);
          }
        });
      }
    });
    _groups = List.unmodifiable(groups);
  }
}

GroupErrandsCompanion _toGroupErrand(
  String groupId,
  Errand errand,
  int position,
) => GroupErrandsCompanion.insert(
  id: errand.id,
  groupId: groupId,
  position: position,
  title: errand.title,
  place: errand.place,
  notes: errand.notes,
  timing: errand.timing.name,
  minute: Value(errand.minute),
  optional: errand.optional,
  details: Value(jsonEncode(errand.toJson())),
);

RepeatPattern _parseRepeat(String name) => RepeatPattern.values.firstWhere(
  (value) => value.name == name,
  orElse: () => RepeatPattern.asNeeded,
);

TimingRule _parseTiming(String name) => TimingRule.values.firstWhere(
  (value) => value.name == name,
  orElse: () => TimingRule.anytime,
);
