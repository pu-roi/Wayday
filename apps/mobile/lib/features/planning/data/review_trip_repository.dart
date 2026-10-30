import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import '../../../core/data/wayday_database.dart';
import '../../../core/data/serial_write_queue.dart';
import '../../today/domain/day.dart';
import '../domain/review_timing_edit.dart';

/// Only manual trip settings, bound to the unchanged Today source. No model
/// output, route content, coordinates or free-text task edits are stored here.
class ReviewTrip {
  ReviewTrip(
    this.date,
    this.departure,
    this.deadline, {
    Map<String, ReviewTimingEdit> timingEdits = const {},
  }) : timingEdits = Map.unmodifiable(timingEdits) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null ||
        calendarDate(parsed) != date ||
        departure < 0 ||
        departure > 1439 ||
        deadline < 0 ||
        deadline > 1439) {
      throw const FormatException('Invalid saved review trip');
    }
  }
  final String date;
  final int departure, deadline;
  final Map<String, ReviewTimingEdit> timingEdits;
  factory ReviewTrip.fromDay(DayPlan day, {DayPlan? source}) {
    final original = {for (final e in source?.errands ?? <Errand>[]) e.id: e};
    return ReviewTrip(
      day.date,
      day.departure,
      day.deadline,
      timingEdits: {
        for (final e in day.errands)
          if (original.containsKey(e.id) &&
              e.confirmedFields.contains('timing') &&
              (e.timing != original[e.id]!.timing ||
                  e.minute != original[e.id]!.minute))
            e.id: ReviewTimingEdit(e.timing, e.minute),
      },
    );
  }
  DayPlan applyTripSettings(DayPlan day) =>
      day.copyWith(date: date, departure: departure, deadline: deadline);
  DayPlan apply(DayPlan day) {
    final ids = day.errands.map((e) => e.id).toSet();
    if (timingEdits.keys.any((id) => !ids.contains(id))) {
      throw const FormatException(
        'Saved errand time no longer matches the source',
      );
    }
    return applyTripSettings(day).copyWith(
      errands: [for (final e in day.errands) timingEdits[e.id]?.apply(e) ?? e],
    );
  }

  Map<String, Object> toJson() => {
    'date': date,
    'departure': departure,
    'deadline': deadline,
    if (timingEdits.isNotEmpty)
      'errandTimes': {
        for (final entry in timingEdits.entries)
          entry.key: entry.value.toJson(),
      },
  };
  factory ReviewTrip.fromJson(Map<String, dynamic> json) {
    final raw = json['errandTimes'];
    if (raw != null && raw is! Map) {
      throw const FormatException('Invalid saved errand times');
    }
    final edits = <String, ReviewTimingEdit>{};
    for (final entry in (raw as Map? ?? {}).entries) {
      if (entry.key is! String || entry.value is! Map) {
        throw const FormatException('Invalid saved errand times');
      }
      edits[entry.key as String] = ReviewTimingEdit.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    return ReviewTrip(
      json['date'] as String,
      json['departure'] as int,
      json['deadline'] as int,
      timingEdits: edits,
    );
  }
}

String reviewTripSourceKey(DayPlan source) =>
    sha256.convert(utf8.encode(jsonEncode(source.toJson()))).toString();

abstract interface class ReviewTripRepository {
  Future<ReviewTrip?> read(DayPlan source);
  Future<void> save(DayPlan source, DayPlan draft);
}

class MemoryReviewTripRepository implements ReviewTripRepository {
  String? _key;
  ReviewTrip? _value;
  @override
  Future<ReviewTrip?> read(DayPlan source) async =>
      _key == reviewTripSourceKey(source) ? _value : null;
  @override
  Future<void> save(DayPlan source, DayPlan draft) async {
    final value = ReviewTrip.fromDay(draft, source: source);
    _key = reviewTripSourceKey(source);
    _value = value;
  }
}

class SqliteReviewTripRepository implements ReviewTripRepository {
  SqliteReviewTripRepository(this.database);
  final WaydayDatabase database;
  final _writes = SerialWriteQueue();
  @override
  Future<ReviewTrip?> read(DayPlan source) async {
    ReviewTrip? value;
    await _writes.enqueue(() async {
      final row = await (database.select(
        database.reviewTrips,
      )..where((r) => r.id.equals(1))).getSingleOrNull();
      if (row != null && row.sourceKey == reviewTripSourceKey(source)) {
        value = ReviewTrip.fromJson(
          jsonDecode(row.payload) as Map<String, dynamic>,
        );
      }
    });
    return value;
  }

  @override
  Future<void> save(DayPlan source, DayPlan draft) => _writes.enqueue(() async {
    final value = ReviewTrip.fromDay(draft, source: source);
    await database
        .into(database.reviewTrips)
        .insertOnConflictUpdate(
          ReviewTripsCompanion.insert(
            id: const Value(1),
            sourceKey: reviewTripSourceKey(source),
            payload: jsonEncode(value.toJson()),
          ),
        );
  });
}
