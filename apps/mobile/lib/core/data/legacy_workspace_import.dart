import 'dart:convert';

import '../../features/places/domain/place_intent.dart';
import '../../features/recurring/domain/errand_group.dart';
import '../../features/today/domain/day.dart';
import 'local_repositories.dart';
import 'wayday_database.dart' hide SavedPlace;

/// Decode Rudy's complete versioned workspace before changing the destination.
class LegacyWorkspace {
  const LegacyWorkspace(this.day, this.groups, this.places);
  final DayPlan day;
  final List<ErrandGroup> groups;
  final List<SavedPlace> places;

  factory LegacyWorkspace.decode(Map<String, String> documents) {
    Object? value(String key) {
      final raw = documents[key];
      if (raw == null) throw FormatException('Missing workspace section: $key');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['format'] != 1 ||
          !decoded.containsKey('value')) {
        throw const FormatException('Unsupported workspace format');
      }
      return decoded['value'];
    }

    return LegacyWorkspace(
      DayPlan.fromJson(value('day') as Map<String, dynamic>),
      (value('groups') as List)
          .map((item) => ErrandGroup.fromJson(item as Map<String, dynamic>))
          .toList(),
      (value('places') as List)
          .map((item) => SavedPlace.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Call only for an empty destination selected for import.
  Future<void> importInto(WaydayDatabase database) async {
    await database.transaction(() async {
      final existingDay = await database.select(database.daySettings).get();
      final existingErrands = await database.select(database.dayErrands).get();
      final existingGroups = await database
          .select(database.recurringGroups)
          .get();
      final existingPlaces = await database.select(database.savedPlaces).get();
      if (existingDay.isNotEmpty ||
          existingErrands.isNotEmpty ||
          existingGroups.isNotEmpty ||
          existingPlaces.isNotEmpty) {
        throw StateError('Import destination is not empty');
      }
      final repositories = await LocalRepositories.open(database: database);
      await repositories.today.save(day);
      await repositories.recurring.save(groups);
      for (final place in places) {
        await database
            .into(database.savedPlaces)
            .insert(
              SavedPlacesCompanion.insert(
                id: place.id,
                payload: jsonEncode(place.toJson()),
              ),
            );
      }
    });
  }
}
