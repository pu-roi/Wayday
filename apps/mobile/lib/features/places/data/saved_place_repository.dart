import 'dart:convert';

import 'package:drift/drift.dart';
import '../../../core/data/wayday_database.dart' hide SavedPlace;
import '../domain/place_intent.dart';

abstract interface class SavedPlaceRepository {
  Future<List<SavedPlace>> read();
  Future<void> add(SavedPlace place);
  Future<void> update(SavedPlace place);
  Future<void> delete(String id);
}

class MemorySavedPlaceRepository implements SavedPlaceRepository {
  final List<SavedPlace> _places = [];
  @override
  Future<List<SavedPlace>> read() async => List.unmodifiable(_places);
  @override
  Future<void> add(SavedPlace place) async => _places.add(place);
  @override
  Future<void> update(SavedPlace place) async {
    final index = _places.indexWhere((item) => item.id == place.id);
    if (index == -1) throw StateError('Saved place no longer exists');
    _places[index] = place;
  }

  @override
  Future<void> delete(String id) async {
    final index = _places.indexWhere((item) => item.id == id);
    if (index == -1) throw StateError('Saved place no longer exists');
    _places.removeAt(index);
  }
}

class SqliteSavedPlaceRepository implements SavedPlaceRepository {
  SqliteSavedPlaceRepository(this.database);
  final WaydayDatabase database;
  @override
  Future<List<SavedPlace>> read() async => [
    for (final row in await database.select(database.savedPlaces).get())
      SavedPlace.fromJson(jsonDecode(row.payload) as Map<String, dynamic>),
  ];
  @override
  Future<void> add(SavedPlace place) => database
      .into(database.savedPlaces)
      .insert(
        SavedPlacesCompanion.insert(
          id: place.id,
          payload: jsonEncode(place.toJson()),
        ),
      );
  @override
  Future<void> update(SavedPlace place) async {
    final count =
        await (database.update(
          database.savedPlaces,
        )..where((row) => row.id.equals(place.id))).write(
          SavedPlacesCompanion(payload: Value(jsonEncode(place.toJson()))),
        );
    if (count != 1) throw StateError('Saved place no longer exists');
  }

  @override
  Future<void> delete(String id) async {
    final count = await (database.delete(
      database.savedPlaces,
    )..where((row) => row.id.equals(id))).go();
    if (count != 1) throw StateError('Saved place no longer exists');
  }
}
