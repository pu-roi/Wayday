import 'dart:convert';
import 'package:drift/drift.dart';

import '../../../core/data/serial_write_queue.dart';
import '../domain/day.dart';
import '../../../core/data/wayday_database.dart';
import '../../places/domain/place_intent.dart';

abstract interface class DayRepository {
  DayPlan read();
  Future<void> save(DayPlan day);
}

class MemoryDayRepository implements DayRepository {
  MemoryDayRepository({DayPlan? initialData})
    : _day = initialData ?? DayPlan(errands: const []);

  DayPlan _day;
  @override
  DayPlan read() => _day;
  @override
  Future<void> save(DayPlan day) async {
    _day = day;
  }
}

class SqliteDayRepository implements DayRepository {
  SqliteDayRepository._(this._database, this._day);

  final WaydayDatabase _database;
  final SerialWriteQueue _writes = SerialWriteQueue();
  DayPlan _day;

  static Future<SqliteDayRepository> open(
    WaydayDatabase database, {
    GooglePinResolver? resolveGooglePin,
  }) async {
    final settings = await database
        .select(database.daySettings)
        .getSingleOrNull();
    final defaults = DayPlan(errands: const []);
    if (settings == null) {
      await database
          .into(database.daySettings)
          .insert(
            DaySettingsCompanion.insert(
              id: const Value(1),
              fromPlace: defaults.from,
              toPlace: defaults.to,
              departure: defaults.departure,
              deadline: defaults.deadline,
              profile: defaults.profile.name,
            ),
          );
    }

    final rows = await (database.select(
      database.dayErrands,
    )..orderBy([(row) => OrderingTerm.asc(row.position)])).get();
    final details = settings?.placeDetails == null
        ? null
        : jsonDecode(settings!.placeDetails!) as Map<String, dynamic>;
    return SqliteDayRepository._(
      database,
      DayPlan(
        from: settings?.fromPlace ?? defaults.from,
        to: settings?.toPlace ?? defaults.to,
        departure: settings?.departure ?? defaults.departure,
        deadline: settings?.deadline ?? defaults.deadline,
        fromPlace: details?['fromPlace'] == null
            ? null
            : PlaceIntent.fromJson(
                details!['fromPlace'] as Map<String, dynamic>,
                resolveGooglePin: resolveGooglePin,
              ),
        toPlace: details?['toPlace'] == null
            ? null
            : PlaceIntent.fromJson(
                details!['toPlace'] as Map<String, dynamic>,
                resolveGooglePin: resolveGooglePin,
              ),
        date: details?['date'] as String?,
        timeZone: details?['timeZone'] as String? ?? 'Asia/Manila',
        revision: details?['revision'] as int? ?? 0,
        profile: _parseEnum(
          TravelProfile.values,
          settings?.profile ?? defaults.profile.name,
          TravelProfile.motor,
        ),
        errands: [
          for (final row in rows)
            row.details != null
                ? Errand.fromJson(
                    jsonDecode(row.details!) as Map<String, dynamic>,
                    resolveGooglePin: resolveGooglePin,
                  )
                : Errand(
                    id: row.id,
                    title: row.title,
                    place: row.place,
                    notes: row.notes,
                    timing: _parseEnum(
                      TimingRule.values,
                      row.timing,
                      TimingRule.anytime,
                    ),
                    minute: row.minute,
                    optional: row.optional,
                    sourceGroupId: row.sourceGroupId,
                    sourceItemId: row.sourceItemId,
                  ),
        ],
      ),
    );
  }

  @override
  DayPlan read() => _day;

  @override
  Future<void> save(DayPlan day) => _writes.enqueue(() => _save(day));

  Future<void> _save(DayPlan day) async {
    await _database.transaction(() async {
      await _database
          .into(_database.daySettings)
          .insertOnConflictUpdate(
            DaySettingsCompanion.insert(
              id: const Value(1),
              fromPlace: day.from,
              toPlace: day.to,
              departure: day.departure,
              deadline: day.deadline,
              profile: day.profile.name,
              placeDetails: Value(
                jsonEncode({
                  'fromPlace': day.fromPlace.toJson(),
                  'toPlace': day.toPlace.toJson(),
                  'date': day.date,
                  'timeZone': day.timeZone,
                  'revision': day.revision,
                }),
              ),
            ),
          );
      await _database.delete(_database.dayErrands).go();
      if (day.errands.isNotEmpty) {
        await _database.batch((batch) {
          batch.insertAll(_database.dayErrands, [
            for (var position = 0; position < day.errands.length; position++)
              _toDayErrand(day.errands[position], position),
          ]);
        });
      }
    });
    _day = day;
  }
}

DayErrandsCompanion _toDayErrand(Errand errand, int position) =>
    DayErrandsCompanion.insert(
      id: errand.id,
      position: position,
      title: errand.title,
      place: errand.place,
      notes: errand.notes,
      timing: errand.timing.name,
      minute: Value(errand.minute),
      optional: errand.optional,
      sourceGroupId: Value(errand.sourceGroupId),
      sourceItemId: Value(errand.sourceItemId),
      details: Value(jsonEncode(errand.toJson())),
    );

T _parseEnum<T extends Enum>(List<T> values, String name, T fallback) =>
    values.firstWhere((value) => value.name == name, orElse: () => fallback);
