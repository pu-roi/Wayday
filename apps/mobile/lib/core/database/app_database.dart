import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Versioned aggregates keep the small local workspace atomic. The regional
/// place catalog belongs to PostGIS, not this personal SQLite database.
class WorkspaceDocuments extends Table {
  TextColumn get key => text()();
  TextColumn get payload => text()();
  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [WorkspaceDocuments])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.device()
    : super(
        driftDatabase(
          name: 'wayday_personal',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
            onResult: (result) {
              if (result.chosenImplementation ==
                  WasmStorageImplementation.inMemory) {
                throw StateError('Persistent browser storage is unavailable');
              }
            },
          ),
        ),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // The prototype had no disk schema. Add explicit, tested transformations
      // here before increasing schemaVersion. Never reset a user's database.
      throw StateError('Unsupported database upgrade: $from to $to');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<Map<String, String>> readDocuments() async => {
    for (final row in await select(workspaceDocuments).get())
      row.key: row.payload,
  };

  Future<void> writeDocuments(Map<String, String> documents) =>
      transaction(() async {
        for (final entry in documents.entries) {
          await into(workspaceDocuments).insertOnConflictUpdate(
            WorkspaceDocumentsCompanion.insert(
              key: entry.key,
              payload: entry.value,
            ),
          );
        }
      });
}
