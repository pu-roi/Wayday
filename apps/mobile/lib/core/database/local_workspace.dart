import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/places/domain/place_intent.dart';
import '../../features/recurring/data/group_repository.dart';
import '../../features/recurring/domain/errand_group.dart';
import '../../features/today/data/day_repository.dart';
import '../../features/today/domain/day.dart';
import 'app_database.dart';

final localWorkspaceProvider = Provider<LocalWorkspace?>((ref) => null);

/// Hydrated before views appear. Writes are ordered and failures remain visible.
/// Each queued snapshot covers the whole workspace, so retry cannot restore an
/// older Today list over a newer template edit.
class LocalWorkspace extends ChangeNotifier {
  LocalWorkspace._(this.database, this.day, this.groups, this.places);
  final AppDatabase database;
  DayPlan day;
  List<ErrandGroup> groups;
  List<SavedPlace> places;
  Future<void> _writes = Future.value();
  Object? lastError;
  int _pending = 0;
  bool get isSaving => _pending > 0;

  static Future<LocalWorkspace> open(AppDatabase database) async {
    final documents = await database.readDocuments();
    if (documents.isEmpty) {
      final workspace = LocalWorkspace._(
        database,
        newDay(),
        MemoryGroupRepository().read(),
        const [],
      );
      await database.writeDocuments(workspace._snapshot());
      return workspace;
    }
    // Missing or malformed data is an error, never permission to reseed.
    Map<String, dynamic> decode(String key) {
      final payload = documents[key];
      if (payload == null) {
        throw FormatException('Missing workspace section: $key');
      }
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      if (decoded['format'] != 1) {
        throw const FormatException('Unsupported workspace format');
      }
      return decoded;
    }

    final day = DayPlan.fromJson(
      decode('day')['value'] as Map<String, dynamic>,
    );
    final groups = (decode('groups')['value'] as List)
        .map((e) => ErrandGroup.fromJson(e as Map<String, dynamic>))
        .toList();
    final places = (decode('places')['value'] as List)
        .map((e) => SavedPlace.fromJson(e as Map<String, dynamic>))
        .toList();
    final workspace = LocalWorkspace._(
      database,
      day.copyWith(from: '', to: ''),
      List.unmodifiable(groups),
      List.unmodifiable(places),
    );
    if (day.from.isNotEmpty ||
        day.to.isNotEmpty ||
        day.fromPlace.hasCoordinates ||
        day.toPlace.hasCoordinates) {
      // Remove legacy persisted endpoints without changing any other section.
      await database.writeDocuments(workspace._snapshot());
    }
    return workspace;
  }

  Map<String, String> _snapshot() => {
    // Endpoints belong to this app session; errands and saved places are durable.
    'day': jsonEncode({
      'format': 1,
      'value': day.copyWith(from: '', to: '').toJson(),
    }),
    'groups': jsonEncode({
      'format': 1,
      'value': groups.map((e) => e.toJson()).toList(),
    }),
    'places': jsonEncode({
      'format': 1,
      'value': places.map((e) => e.toJson()).toList(),
    }),
  };

  void saveDay(DayPlan value) {
    day = value;
    _enqueue();
  }

  void saveGroups(List<ErrandGroup> value) {
    groups = List.unmodifiable(value);
    _enqueue();
  }

  void savePlaces(List<SavedPlace> value) {
    places = List.unmodifiable(value);
    _enqueue();
  }

  void retry() => _enqueue();

  void _enqueue() {
    final snapshot = _snapshot();
    _pending++;
    notifyListeners();
    _writes = _writes.then((_) async {
      try {
        await database.writeDocuments(snapshot);
        lastError = null;
      } catch (error) {
        lastError = error;
      } finally {
        _pending--;
        notifyListeners();
      }
    });
  }

  Future<void> flush() async {
    await _writes;
    if (lastError != null) {
      throw StateError('Personal changes have not been saved');
    }
  }

  Future<void> close() async {
    await flush();
    await database.close();
    dispose();
  }
}

class LocalDayRepository implements DayRepository {
  const LocalDayRepository(this.workspace);
  final LocalWorkspace workspace;
  @override
  DayPlan read() => workspace.day;
  @override
  void save(DayPlan day) => workspace.saveDay(day);
}

class LocalGroupRepository implements GroupRepository {
  const LocalGroupRepository(this.workspace);
  final LocalWorkspace workspace;
  @override
  List<ErrandGroup> read() => workspace.groups;
  @override
  void save(List<ErrandGroup> groups) => workspace.saveGroups(groups);
}
