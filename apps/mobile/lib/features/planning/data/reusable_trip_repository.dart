import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/local_repositories.dart';
import '../../../core/data/wayday_database.dart';
import '../../places/data/google_pin_cache.dart';
import '../../places/domain/place_intent.dart';
import '../../today/domain/day.dart';
import '../domain/planning_models.dart';

String newTripIdentity() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x100000000).toRadixString(16)}';

/// User-owned inputs and validated meaning; provider text/roads stay transient.
class ReusableTrip {
  ReusableTrip({
    required this.id,
    required this.name,
    required this.day,
    required this.meaning,
    required this.choices,
    this.answers = const {},
    this.lightPickupConfirmed = false,
  }) {
    if (id.isEmpty ||
        name.trim().isEmpty ||
        name.length > 80 ||
        day.errands.isEmpty ||
        day.errands.length > 12) {
      throw const FormatException('Invalid reusable trip');
    }
    Interpretation.fromJson({
      'needs': meaning.map((n) => n.toJson()).toList(),
    }, day);
    final ids = day.errands.map((e) => e.id).toSet();
    if (choices.keys.toSet().difference(ids).isNotEmpty ||
        ids.difference(choices.keys.toSet()).isNotEmpty ||
        answers.keys.any((id) => !ids.contains(id))) {
      throw const FormatException('Invalid saved place assignments');
    }
    if (meaning.any((n) => n.question != null)) {
      throw const FormatException('Resolve questions before saving for reuse');
    }
  }
  final String id, name;
  final DayPlan day;
  final List<ErrandNeed> meaning;
  final Map<String, PlaceIntent> choices;
  final Map<String, Map<String, String>> answers;
  final bool lightPickupConfirmed;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'name': name,
    'day': day.toJson(),
    'needs': meaning.map((n) => n.toJson()).toList(),
    'choices': choices.map((k, v) => MapEntry(k, v.toJson())),
    'answers': answers,
    'lightPickupConfirmed': lightPickupConfirmed,
  };
  factory ReusableTrip.fromJson(
    Map<String, dynamic> json,
    GooglePinResolver resolver,
  ) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported reusable trip');
    }
    final day = DayPlan.fromJson(
      Map<String, dynamic>.from(json['day'] as Map),
      resolveGooglePin: resolver,
    );
    return ReusableTrip(
      id: json['id'] as String,
      name: json['name'] as String,
      day: day,
      meaning: Interpretation.fromJson({'needs': json['needs']}, day).needs,
      choices: (json['choices'] as Map).map(
        (k, v) => MapEntry(
          k as String,
          PlaceIntent.fromJson(
            Map<String, dynamic>.from(v as Map),
            resolveGooglePin: resolver,
          ),
        ),
      ),
      answers: (json['answers'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, Map<String, String>.from(v as Map)),
      ),
      lightPickupConfirmed: json['lightPickupConfirmed'] == true,
    );
  }
  ReusableTrip copyForRun({
    required String date,
    required int departure,
    required int deadline,
    String? runId,
  }) {
    final run = runId ?? newTripIdentity();
    final ids = {for (final e in day.errands) e.id: '$run:${e.id}'};
    final copied = day.errands
        .map((e) => e.copyForToday(newId: ids[e.id]!, groupId: id, idMap: ids))
        .toList();
    return ReusableTrip(
      id: id,
      name: name,
      day: day.copyWith(
        errands: copied,
        date: date,
        departure: departure,
        deadline: deadline,
        revision: 0,
      ),
      meaning: [
        for (final n in meaning)
          ErrandNeed.fromJson({
            ...n.toJson(),
            'id': ids[n.id],
            'after': n.after.map((id) => ids[id]!).toList(),
          }),
      ],
      choices: choices.map((k, v) => MapEntry(ids[k]!, v)),
      answers: answers.map((k, v) => MapEntry(ids[k]!, v)),
      lightPickupConfirmed: lightPickupConfirmed,
    );
  }
}

abstract interface class ReusableTripRepository {
  Future<List<ReusableTrip>> read();
  Future<void> save(ReusableTrip trip);
  Future<void> delete(String id);
}

class MemoryReusableTripRepository implements ReusableTripRepository {
  final _values = <String, ReusableTrip>{};
  @override
  Future<List<ReusableTrip>> read() async => _values.values.toList();
  @override
  Future<void> save(ReusableTrip trip) async {
    _values[trip.id] = trip;
  }

  @override
  Future<void> delete(String id) async {
    _values.remove(id);
  }
}

class SqliteReusableTripRepository implements ReusableTripRepository {
  SqliteReusableTripRepository(this.database, this.resolver);
  final WaydayDatabase database;
  final GooglePinResolver resolver;
  @override
  Future<List<ReusableTrip>> read() async =>
      (await database.select(database.reusableTrips).get())
          .map(
            (row) => ReusableTrip.fromJson(
              jsonDecode(row.payload) as Map<String, dynamic>,
              resolver,
            ),
          )
          .toList();
  @override
  Future<void> save(ReusableTrip trip) async {
    final json = trip.toJson();
    ReusableTrip.fromJson(json, resolver);
    await database
        .into(database.reusableTrips)
        .insertOnConflictUpdate(
          ReusableTripsCompanion.insert(
            id: trip.id,
            name: trip.name,
            payload: jsonEncode(json),
          ),
        );
  }

  @override
  Future<void> delete(String id) async {
    await (database.delete(
      database.reusableTrips,
    )..where((t) => t.id.equals(id))).go();
  }
}

final reusableTripRepositoryProvider = Provider<ReusableTripRepository>((ref) {
  final local = ref.watch(localRepositoriesProvider);
  return local == null
      ? MemoryReusableTripRepository()
      : SqliteReusableTripRepository(
          local.database,
          ref.read(googlePinCacheProvider).lease,
        );
});
final reusableTripsProvider = FutureProvider(
  (ref) => ref.watch(reusableTripRepositoryProvider).read(),
  retry: (_, _) => null,
);
