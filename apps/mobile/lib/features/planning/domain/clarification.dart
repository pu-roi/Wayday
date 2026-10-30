import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../today/domain/day.dart';
import 'planning_models.dart';
import '../../errands/domain/errand_order.dart';

String clarificationHash(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

/// Only interpretation facts: never coordinates, endpoints or route settings.
class ClarificationContext {
  ClarificationContext(Map<String, dynamic> facts)
    : facts = Map.unmodifiable(facts);
  final Map<String, dynamic> facts;
  String get id => facts['id'] as String;
  String get question => facts['question'] as String;
  late final String key = clarificationHash(facts);
  late final String preferenceKey = clarificationHash({
    for (final k in [
      'id',
      'question',
      'title',
      'notes',
      'query',
      'category',
      'items',
      'placePreference',
    ])
      k: facts[k],
  });
  factory ClarificationContext.create(
    Errand e,
    ErrandNeed n,
    List<Errand> related,
  ) => ClarificationContext({
    'id': e.id,
    'question': n.question ?? '',
    'kind': n.questionKind,
    'title': e.title,
    'notes': e.notes,
    'timing': e.timing.name,
    'minute': e.minute,
    'durationMinutes': e.durationMinutes,
    'durationConfirmed': e.durationConfirmed,
    'after': (e.afterErrandIds.toList()..sort()),
    'optional': e.optional,
    'confirmedFields': (e.confirmedFields.toList()..sort()),
    'fixedPlace': n.meeting || n.requiresSpecificLocation,
    'placePreference': e.placeIntent.kind.name == 'search'
        ? {
            'label': e.placeIntent.label,
            'brand': e.placeIntent.brand,
            'category': e.placeIntent.category,
          }
        : null,
    'hasConfirmedLocation': e.placeIntent.hasCoordinates,
    'query': n.query,
    'category': n.category,
    'items': n.items,
    'related': {for (final x in related) x.id: x.title},
    'dependencies': {
      for (final x in related) x.id: (x.afterErrandIds.toList()..sort()),
    },
  });
}

class ClarificationResolution {
  const ClarificationResolution({
    required this.outcome,
    required this.kind,
    required this.summary,
    this.query,
    this.category,
    this.items = const [],
    this.followUp,
    this.timing,
    this.minute,
    this.after,
  });
  final String outcome, kind, summary;
  final String? query, category, followUp, timing;
  final int? minute;
  final List<String> items;
  final List<String>? after;
  bool get resolved => outcome != 'unresolved';
  bool get hasRules => timing != null || after != null;
  Map<String, dynamic> toJson() => {
    'outcome': outcome,
    'kind': kind,
    'summary': summary,
    'query': query,
    'category': category,
    'items': items,
    'followUp': followUp,
    'timing': timing,
    'minute': minute,
    'after': after,
  };
  factory ClarificationResolution.fromJson(
    Map<String, dynamic> j,
    ClarificationContext c,
  ) {
    const fields = {
      'id',
      'outcome',
      'kind',
      'summary',
      'query',
      'category',
      'items',
      'followUp',
      'timing',
      'minute',
      'after',
    };
    final related = c.facts['related'] as Map;
    if (j.keys.any((k) => !fields.contains(k)) ||
        j['id'] != c.id ||
        !{'resolved', 'flexible', 'unresolved'}.contains(j['outcome']) ||
        !{
          'preference',
          'location',
          'timing',
          'dependency',
          'other',
        }.contains(j['kind']) ||
        j['summary'] is! String ||
        (j['summary'] as String).trim().isEmpty ||
        (j['summary'] as String).length > 240 ||
        (j['query'] != null &&
            (j['query'] is! String ||
                (j['query'] as String).trim().isEmpty ||
                (j['query'] as String).length > 100)) ||
        (j['category'] != null &&
            !ErrandNeed.categories.contains(j['category'])) ||
        j['items'] is! List ||
        (j['items'] as List).length > 40 ||
        (j['items'] as List).any(
          (x) => x is! String || x.trim().isEmpty || x.length > 120,
        ) ||
        (j['followUp'] != null &&
            (j['followUp'] is! String ||
                (j['followUp'] as String).length > 240)) ||
        (j['outcome'] == 'unresolved' &&
            (j['followUp'] is! String ||
                (j['followUp'] as String).trim().isEmpty)) ||
        (j['timing'] != null &&
            !TimingRule.values.any((t) => t.name == j['timing'])) ||
        (j['minute'] != null &&
            (j['minute'] is! int ||
                (j['minute'] as int) < 0 ||
                (j['minute'] as int) > 1439)) ||
        (j['timing'] != null &&
            j['timing'] != 'anytime' &&
            j['minute'] == null) ||
        (j['after'] != null &&
            (j['after'] is! List ||
                (j['after'] as List).any(
                  (id) => id == c.id || !related.containsKey(id),
                )))) {
      throw const FormatException('Invalid clarification result');
    }
    return ClarificationResolution(
      outcome: j['outcome'] as String,
      kind: j['kind'] as String,
      summary: (j['summary'] as String).trim(),
      query: j['query'] as String?,
      category: j['category'] as String?,
      items: List<String>.from(j['items'] as List),
      followUp: j['followUp'] as String?,
      timing: j['timing'] as String?,
      minute: j['minute'] as int?,
      after: _validatedAfter(j['after'], c),
    );
  }

  static List<String>? _validatedAfter(dynamic value, ClarificationContext c) {
    if (value == null) return null;
    final after = {
      ...(c.facts['after'] as List).cast<String>(),
      ...(value as List).cast<String>(),
    }.toList();
    final graph = c.facts['dependencies'] as Map? ?? {};
    final tasks = [
      for (final id in (c.facts['related'] as Map).keys)
        Errand(
          id: id as String,
          title: id,
          afterErrandIds: id == c.id
              ? after
              : List<String>.from(graph[id] as List? ?? []),
        ),
    ];
    if (ErrandOrder.reconcile(tasks).issue != null) {
      throw const FormatException('Invalid proposed ordering');
    }
    return after;
  }

  ErrandNeed refine(ErrandNeed n) => n.copyWith(
    query: query,
    category: n.meeting ? n.category : category,
    items: {...n.items, ...items}.toList(),
    requiresSpecificLocation:
        n.requiresSpecificLocation ||
        (kind == 'location' && n.questionRequired != false),
  );
  Errand applyRules(Errand e) => e.copyWith(
    timing: timing == null ? null : TimingRule.values.byName(timing!),
    minute: minute,
    clearTime: timing == 'anytime',
    afterErrandIds: after,
    confirmedFields: {
      ...e.confirmedFields,
      if (timing != null) 'timing',
      if (after != null) 'dependencies',
    },
  );
}

class ClarificationRecord {
  ClarificationRecord({
    required this.context,
    this.answer = '',
    this.history = const [],
    this.status = 'draft',
    this.resolution,
    this.rulesApproved = false,
    this.draft,
    this.revision = 0,
    this.updatedAt = 0,
    this.draftRevision = 0,
  });
  final ClarificationContext context;
  String answer, status;
  List<String> history;
  ClarificationResolution? resolution;
  bool rulesApproved;
  String? draft;
  int revision, updatedAt, draftRevision;
  bool get proposesRules {
    final r = resolution;
    if (r == null) return false;
    final oldAfter = Set<String>.from(context.facts['after'] as List);
    return (r.timing != null &&
            (r.timing != context.facts['timing'] ||
                r.minute != context.facts['minute'])) ||
        (r.after != null &&
            (r.after!.toSet().length != oldAfter.length ||
                !r.after!.every(oldAfter.contains)));
  }

  bool get applied =>
      {'resolved', 'flexible'}.contains(status) && resolution?.resolved == true;
  Map<String, dynamic> toJson() => {
    'facts': context.facts,
    'answer': answer,
    'history': history,
    'status': status,
    'resolution': resolution == null
        ? null
        : {'id': context.id, ...resolution!.toJson()},
    'rulesApproved': rulesApproved,
    'draft': draft,
    'revision': revision,
    'updatedAt': updatedAt,
    'draftRevision': draftRevision,
  };
  factory ClarificationRecord.fromJson(Map<String, dynamic> j) {
    final c = ClarificationContext(
      Map<String, dynamic>.from(j['facts'] as Map),
    );
    final status = j['status'];
    if (!{
          'draft',
          'processing',
          'resolved',
          'flexible',
          'unresolved',
          'failed',
        }.contains(status) ||
        j['answer'] is! String ||
        (j['answer'] as String).length > 8000) {
      throw const FormatException('Invalid saved answer');
    }
    return ClarificationRecord(
      context: c,
      answer: j['answer'] as String,
      status: status as String,
      history: List<String>.from(j['history'] as List? ?? []),
      resolution: j['resolution'] == null
          ? null
          : ClarificationResolution.fromJson(
              Map<String, dynamic>.from(j['resolution'] as Map),
              c,
            ),
      rulesApproved: j['rulesApproved'] == true,
      draft: j['draft'] as String?,
      revision: j['revision'] as int? ?? 0,
      updatedAt: j['updatedAt'] as int? ?? 0,
      draftRevision: j['draftRevision'] as int? ?? 0,
    );
  }
}

class ClarificationSession {
  ClarificationSession({
    Map<String, ClarificationRecord>? records,
    Map<String, Map<String, String>>? deferrals,
    Map<String, int>? deferralRevisions,
    Map<String, Map<String, dynamic>>? places,
  }) : records = records ?? {},
       deferrals = deferrals ?? {},
       deferralRevisions = deferralRevisions ?? {},
       places = places ?? {};
  final Map<String, ClarificationRecord> records;
  final Map<String, Map<String, String>> deferrals;
  final Map<String, int> deferralRevisions;
  final Map<String, Map<String, dynamic>> places;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'records': records.map((k, v) => MapEntry(k, v.toJson())),
    'deferrals': deferrals,
    'deferralRevisions': deferralRevisions,
    'places': places,
  };
  factory ClarificationSession.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) {
      throw const FormatException('Invalid clarification session');
    }
    final records = (j['records'] as Map).map(
      (k, v) => MapEntry(
        k as String,
        ClarificationRecord.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
    );
    if (records.entries.any((x) => x.key != x.value.context.key)) {
      throw const FormatException('Invalid question identity');
    }
    return ClarificationSession(
      records: records,
      places: (j['places'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map)),
      ),
      deferralRevisions: Map<String, int>.from(
        j['deferralRevisions'] as Map? ?? {},
      ),
      deferrals: (j['deferrals'] as Map).map(
        (k, v) => MapEntry(k as String, Map<String, String>.from(v as Map)),
      ),
    );
  }
}

/// Merge independent questions and reject completion from older submissions.
ClarificationSession mergeClarifications(
  ClarificationSession old,
  ClarificationSession incoming,
) {
  final result = ClarificationSession.fromJson(old.toJson());
  for (final entry in incoming.records.entries) {
    final prior = result.records[entry.key],
        next = ClarificationRecord.fromJson(entry.value.toJson());
    if (prior == null) {
      result.records[entry.key] = next;
      continue;
    }
    final chosen =
        next.revision > prior.revision ||
            (next.revision == prior.revision &&
                next.updatedAt >= prior.updatedAt)
        ? next
        : prior;
    final draft = next.draftRevision >= prior.draftRevision ? next : prior;
    final copy = ClarificationRecord.fromJson(chosen.toJson());
    copy.draft = draft.draft;
    copy.draftRevision = draft.draftRevision;
    result.records[entry.key] = copy;
  }
  for (final entry in incoming.places.entries) {
    if ((entry.value['revision'] as int) >=
        (result.places[entry.key]?['revision'] as int? ?? 0)) {
      result.places[entry.key] = Map.of(entry.value);
    }
  }
  for (final entry in incoming.deferrals.entries) {
    final revision = incoming.deferralRevisions[entry.key] ?? 0;
    if (revision >= (result.deferralRevisions[entry.key] ?? 0)) {
      result.deferrals[entry.key] = Map.of(entry.value);
      result.deferralRevisions[entry.key] = revision;
    }
  }
  return result;
}
