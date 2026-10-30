import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/local_repositories.dart';
import '../../../core/data/serial_write_queue.dart';
import '../../../core/data/wayday_database.dart';
import '../../places/domain/place_intent.dart';

final recommendationDraftRepositoryProvider =
    Provider<RecommendationDraftRepository>((ref) {
      final local = ref.watch(localRepositoriesProvider);
      return local == null
          ? MemoryRecommendationDraftRepository()
          : SqliteRecommendationDraftRepository(local.database);
    });

class RecommendationDraft {
  const RecommendationDraft({
    required this.context,
    required this.choices,
    this.overrides = const {},
    this.approved = const {},
    this.additions = const {},
    this.selectedErrand,
    this.scrollOffset = 0,
    this.from,
    this.to,
  });
  final String context;
  final Map<String, PlaceIntent> choices;
  final Set<String> overrides, approved, additions;
  final String? selectedErrand;
  final double scrollOffset;
  final PlaceIntent? from, to;
  Map<String, Object?> toJson() => {
    'version': 1,
    'context': context,
    'choices': choices.map((id, place) => MapEntry(id, place.toJson())),
    'overrides': overrides.toList(),
    'approved': approved.toList(),
    'additions': additions.toList(),
    'selected': selectedErrand,
    'offset': scrollOffset,
    'from': from?.toJson(),
    'to': to?.toJson(),
  };
  factory RecommendationDraft.fromJson(
    Map<String, dynamic> json, {
    GooglePinResolver? resolver,
  }) {
    final context = json['context'],
        raw = json['choices'],
        offset = json['offset'];
    if (json['version'] != 1 ||
        context is! String ||
        raw is! Map ||
        raw.length > 12 ||
        offset is! num ||
        !offset.isFinite ||
        offset < 0 ||
        offset > 1000000) {
      throw const FormatException('Invalid recommendation draft');
    }
    Set<String> ids(String key) {
      final value = json[key] ?? <String>[];
      if (value is! List ||
          value.length > 12 ||
          value.any((e) => e is! String)) {
        throw const FormatException('Invalid draft identities');
      }
      return value.cast<String>().toSet();
    }

    final choices = raw.map(
      (id, p) => MapEntry(
        id as String,
        PlaceIntent.fromJson(
          Map<String, dynamic>.from(p as Map),
          resolveGooglePin: resolver,
        ),
      ),
    );
    final overrides = ids('overrides'), selected = json['selected'];
    if (overrides.any((id) => !choices.containsKey(id)) ||
        (selected != null &&
            (selected is! String || !choices.containsKey(selected)))) {
      throw const FormatException('Unassigned draft selection');
    }
    return RecommendationDraft(
      context: context,
      choices: Map<String, PlaceIntent>.from(choices),
      overrides: overrides,
      approved: ids('approved'),
      additions: ids('additions'),
      selectedErrand: selected as String?,
      scrollOffset: offset.toDouble(),
      from: json['from'] == null
          ? null
          : PlaceIntent.fromJson(
              Map<String, dynamic>.from(json['from'] as Map),
              resolveGooglePin: resolver,
            ),
      to: json['to'] == null
          ? null
          : PlaceIntent.fromJson(
              Map<String, dynamic>.from(json['to'] as Map),
              resolveGooglePin: resolver,
            ),
    );
  }
}

abstract interface class RecommendationDraftRepository {
  Future<RecommendationDraft?> read(
    String source,
    String? context, {
    GooglePinResolver? resolver,
  });
  Future<void> save(String source, RecommendationDraft draft);
}

class MemoryRecommendationDraftRepository
    implements RecommendationDraftRepository {
  String? _source;
  String? _payload;
  @override
  Future<RecommendationDraft?> read(
    String source,
    String? context, {
    GooglePinResolver? resolver,
  }) async {
    if (_source != source || _payload == null) return null;
    final value = RecommendationDraft.fromJson(
      jsonDecode(_payload!) as Map<String, dynamic>,
      resolver: resolver,
    );
    return context == null || value.context == context ? value : null;
  }

  @override
  Future<void> save(String source, RecommendationDraft draft) async {
    _payload = jsonEncode(draft.toJson());
    _source = source;
  }
}

class SqliteRecommendationDraftRepository
    implements RecommendationDraftRepository {
  SqliteRecommendationDraftRepository(this.database);
  final WaydayDatabase database;
  final _writes = SerialWriteQueue();
  @override
  Future<RecommendationDraft?> read(
    String source,
    String? context, {
    GooglePinResolver? resolver,
  }) async {
    RecommendationDraft? restored;
    await _writes.enqueue(() async {
      final row = await (database.select(
        database.recommendationDrafts,
      )..where((r) => r.id.equals(1))).getSingleOrNull();
      if (row == null || row.sourceKey != source) return;
      final value = RecommendationDraft.fromJson(
        jsonDecode(row.payload) as Map<String, dynamic>,
        resolver: resolver,
      );
      restored = context == null || value.context == context ? value : null;
    });
    return restored;
  }

  @override
  Future<void> save(String source, RecommendationDraft draft) =>
      _writes.enqueue(() async {
        await database
            .into(database.recommendationDrafts)
            .insertOnConflictUpdate(
              RecommendationDraftsCompanion.insert(
                id: const Value(1),
                sourceKey: source,
                payload: jsonEncode(draft.toJson()),
              ),
            );
      });
}
