import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:wayday/core/data/legacy_recovery_native.dart';
import 'package:wayday/core/data/local_repositories.dart';
import 'package:wayday/core/data/recovery_types.dart';
import 'package:wayday/core/data/wayday_database.dart';
import 'package:wayday/features/today/domain/day.dart';

void main() {
  test(
    'malformed Rudy data is not treated as an empty fresh workspace',
    () async {
      final dir = await Directory.systemTemp.createTemp('wayday-corrupt-');
      final source = File('${dir.path}/wayday_personal.sqlite');
      final legacy = sqlite.sqlite3.open(source.path);
      legacy.execute(
        'CREATE TABLE workspace_documents (key TEXT PRIMARY KEY, payload TEXT NOT NULL)',
      );
      legacy.execute("INSERT INTO workspace_documents VALUES ('day', '{}')");
      legacy.close();
      try {
        final recovery = LegacyRecovery(directory: () async => dir);
        await expectLater(recovery.inspect(), throwsFormatException);
        expect(await source.exists(), isTrue);
        expect(await File('${dir.path}/wayday.sqlite').exists(), isFalse);
        final roiDb = WaydayDatabase(
          NativeDatabase(File('${dir.path}/wayday.sqlite')),
        );
        final roi = await LocalRepositories.open(database: roiDb);
        await roi.today.save(
          DayPlan(
            errands: const [Errand(id: 'safe', title: 'Safe task')],
          ),
        );
        await roiDb.close();
        expect(await recovery.inspect(), RecoveryState.choose);
        final selected = await recovery.open(RecoveryChoice.roi);
        expect(selected.today.read().errands.single.title, 'Safe task');
        await selected.database.close();
        expect(await source.exists(), isTrue);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'choosing Rudy imports to a new database and preserves both originals',
    () async {
      final dir = await Directory.systemTemp.createTemp('wayday-recovery-');
      final roiFile = File('${dir.path}/wayday.sqlite');
      final rudyFile = File('${dir.path}/wayday_personal.sqlite');
      final roiDb = WaydayDatabase(NativeDatabase(roiFile));
      final roi = await LocalRepositories.open(database: roiDb);
      await roi.today.save(
        DayPlan(
          errands: const [Errand(id: 'roi', title: 'Roi task')],
        ),
      );
      await roiDb.close();
      final legacy = sqlite.sqlite3.open(rudyFile.path);
      legacy.execute(
        'CREATE TABLE workspace_documents (key TEXT PRIMARY KEY, payload TEXT NOT NULL)',
      );
      final day = DayPlan(
        errands: const [Errand(id: 'rudy', title: 'Rudy task')],
      );
      for (final entry in {
        'day': day.toJson(),
        'groups': <Object>[],
        'places': <Object>[],
      }.entries) {
        legacy.execute('INSERT INTO workspace_documents VALUES (?, ?)', [
          entry.key,
          jsonEncode({'format': 1, 'value': entry.value}),
        ]);
      }
      legacy.close();
      final recovery = LegacyRecovery(directory: () async => dir);
      try {
        expect(await recovery.inspect(), RecoveryState.choose);
        final imported = await recovery.open(RecoveryChoice.rudy);
        expect(imported.today.read().errands.single.title, 'Rudy task');
        await imported.database.close();
        expect(await recovery.inspect(), RecoveryState.imported);
        final reopened = await recovery.open(RecoveryChoice.roi);
        expect(reopened.today.read().errands.single.title, 'Rudy task');
        await reopened.database.close();
        final original = WaydayDatabase(NativeDatabase(roiFile));
        final originalRepos = await LocalRepositories.open(database: original);
        expect(originalRepos.today.read().errands.single.title, 'Roi task');
        await original.close();
        expect(await rudyFile.exists(), isTrue);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
