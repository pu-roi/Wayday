import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'legacy_workspace_import.dart';
import 'local_repositories.dart';
import 'recovery_types.dart';
import 'wayday_database.dart';

class LegacyRecovery {
  LegacyRecovery({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;
  final Future<Directory> Function() _directory;

  Future<RecoveryState> inspect() async {
    final dir = await _directory();
    if (await File('${dir.path}/wayday-recovery.json').exists()) {
      return RecoveryState.imported;
    }
    final legacy = File('${dir.path}/wayday_personal.sqlite');
    if (!await legacy.exists()) return RecoveryState.normal;
    final hasRoi = await File('${dir.path}/wayday.sqlite').exists();
    // Validate before deciding; a damaged source is an error, not a fresh install.
    try {
      final documents = _readLegacy(legacy);
      if (documents.isEmpty) return RecoveryState.normal;
      LegacyWorkspace.decode(documents);
      return hasRoi ? RecoveryState.choose : RecoveryState.rudyOnly;
    } catch (_) {
      // A damaged legacy file must not prevent choosing an intact Roi file.
      if (hasRoi) return RecoveryState.choose;
      rethrow;
    }
  }

  Map<String, String> _readLegacy(File file) {
    final database = sqlite.sqlite3.open(
      file.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      return {
        for (final row in database.select(
          'SELECT key, payload FROM workspace_documents',
        ))
          row['key'] as String: row['payload'] as String,
      };
    } finally {
      database.close();
    }
  }

  Future<LocalRepositories> open(RecoveryChoice choice) async {
    final dir = await _directory();
    final marker = File('${dir.path}/wayday-recovery.json');
    if (await marker.exists()) {
      final record = jsonDecode(await marker.readAsString());
      final name = record is Map ? record['database'] : null;
      if (name is! String ||
          !RegExp(r'^wayday(?:_import_[0-9]+)?\.sqlite$').hasMatch(name) ||
          !await File('${dir.path}/$name').exists()) {
        throw const FormatException('Saved database selection is invalid');
      }
      return LocalRepositories.open(
        database: WaydayDatabase(NativeDatabase(File('${dir.path}/$name'))),
      );
    }

    if (choice == RecoveryChoice.roi) {
      final repositories = await LocalRepositories.open(
        database: WaydayDatabase(
          NativeDatabase(File('${dir.path}/wayday.sqlite')),
        ),
      );
      try {
        await _writeMarker(marker, 'wayday.sqlite');
        return repositories;
      } catch (_) {
        await repositories.database.close();
        rethrow;
      }
    }

    final workspace = LegacyWorkspace.decode(
      _readLegacy(File('${dir.path}/wayday_personal.sqlite')),
    );
    final name =
        'wayday_import_${DateTime.now().microsecondsSinceEpoch}.sqlite';
    final db = WaydayDatabase(NativeDatabase(File('${dir.path}/$name')));
    try {
      await workspace.importInto(db);
      final repositories = await LocalRepositories.open(database: db);
      await _writeMarker(marker, name);
      return repositories;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  Future<void> _writeMarker(File marker, String name) async {
    final temporary = File('${marker.path}.tmp');
    await temporary.writeAsString(jsonEncode({'database': name}), flush: true);
    await temporary.rename(marker.path);
  }
}
