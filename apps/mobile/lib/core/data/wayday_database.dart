import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'wayday_database.g.dart';

@DataClassName('DaySettingsRow')
class DaySettings extends Table {
  IntColumn get id => integer()();
  TextColumn get fromPlace => text()();
  TextColumn get toPlace => text()();
  IntColumn get departure => integer()();
  IntColumn get deadline => integer()();
  TextColumn get profile => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DayErrandRow')
class DayErrands extends Table {
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get title => text()();
  TextColumn get place => text()();
  TextColumn get notes => text()();
  TextColumn get timing => text()();
  IntColumn get minute => integer().nullable()();
  BoolColumn get optional => boolean()();
  TextColumn get sourceGroupId => text().nullable()();
  TextColumn get sourceItemId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('RecurringGroupRow')
class RecurringGroups extends Table {
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get name => text()();
  TextColumn get repeat => text()();
  IntColumn get day => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('GroupErrandRow')
class GroupErrands extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  IntColumn get position => integer()();
  TextColumn get title => text()();
  TextColumn get place => text()();
  TextColumn get notes => text()();
  TextColumn get timing => text()();
  IntColumn get minute => integer().nullable()();
  BoolColumn get optional => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [DaySettings, DayErrands, RecurringGroups, GroupErrands])
class WaydayDatabase extends _$WaydayDatabase {
  WaydayDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'wayday'));

  @override
  int get schemaVersion => 1;
}
