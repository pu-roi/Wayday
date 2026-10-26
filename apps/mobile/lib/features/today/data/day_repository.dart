import 'package:drift/drift.dart';

import '../../../core/data/serial_write_queue.dart';
import '../domain/day.dart';
import '../../../core/data/wayday_database.dart';

abstract interface class DayRepository {
  DayPlan read();
  Future<void> save(DayPlan day);
}

class MemoryDayRepository implements DayRepository {
  DayPlan _day = exampleDay();
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
    required DayPlan? initialData,
  }) async {
    final settings = await database
        .select(database.daySettings)
        .getSingleOrNull();
    if (settings == null) {
      final seed = initialData;
      if (seed == null) {
        throw StateError('Today data is missing from an initialized database.');
      }
      final repository = SqliteDayRepository._(database, seed);
      await repository.save(seed);
      return repository;
    }

    final rows = await (database.select(
      database.dayErrands,
    )..orderBy([(row) => OrderingTerm.asc(row.position)])).get();
    return SqliteDayRepository._(
      database,
      DayPlan(
        from: settings.fromPlace,
        to: settings.toPlace,
        departure: settings.departure,
        deadline: settings.deadline,
        profile: _parseEnum(
          TravelProfile.values,
          settings.profile,
          TravelProfile.motor,
        ),
        errands: [
          for (final row in rows)
            Errand(
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
    );

T _parseEnum<T extends Enum>(List<T> values, String name, T fallback) =>
    values.firstWhere((value) => value.name == name, orElse: () => fallback);

DayPlan exampleDay() => DayPlan(
  errands: const [
    Errand(
      id: 'registrar',
      title: 'Get documents from the registrar',
      place: 'PLP · Pasig',
      timing: TimingRule.finishBefore,
      minute: 960,
    ),
    Errand(
      id: 'pitch',
      title: 'Capstone presentation',
      place: 'PLP · Pasig',
      timing: TimingRule.at,
      minute: 660,
    ),
    Errand(
      id: 'pickup',
      title: 'Pick up in Ortigas',
      place: 'Ortigas Center',
      timing: TimingRule.arriveBy,
      minute: 900,
    ),
    Errand(id: 'lunch', title: 'Grab a late lunch', place: 'Choose a place'),
    Errand(
      id: 'groceries',
      title: 'Groceries for home',
      place: 'Choose a place',
      optional: true,
    ),
  ],
);
