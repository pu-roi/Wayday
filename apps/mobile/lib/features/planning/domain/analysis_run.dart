import 'dart:convert';
import '../../today/domain/day.dart';
import '../../places/domain/place_intent.dart';
import 'planning_models.dart';

/// Source-bound meaning, without provider metadata or routes. The request body
/// contains no map coordinates. Uses the existing clarification JSON store.
class AnalysisRun {
  AnalysisRun({
    required this.id,
    required this.body,
    required this.errands,
    this.answerBases = const {},
  });
  final String id, body;
  final List<Errand> errands;
  final Map<String, ErrandNeed> answerBases;
  bool matches(List<Errand> current) {
    String facts(List<Errand> values) => jsonEncode(
      values
          .map(
            (e) => e.toJson()
              ..remove('confirmedFields')
              ..remove('durationConfirmed'),
          )
          .toList(),
    );
    return facts(errands) == facts(current);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'body': body,
    'errands': errands.map((e) => e.toJson()).toList(),
    'answerBases': {
      for (final entry in answerBases.entries) entry.key: entry.value.toJson(),
    },
  };
  factory AnalysisRun.fromJson(
    Map<String, dynamic> j, {
    GooglePinResolver? resolveGooglePin,
  }) {
    final id = j['id'] as String, body = j['body'] as String;
    if (!RegExp(r'^[a-z0-9-]{1,80}$').hasMatch(id) ||
        utf8.encode(body).length > 50000) {
      throw const FormatException('Invalid analysis run');
    }
    return AnalysisRun(
      id: id,
      body: body,
      answerBases: readAnswerBases(j['answerBases']),
      errands: (j['errands'] as List)
          .map(
            (e) => Errand.fromJson(
              Map<String, dynamic>.from(e as Map),
              resolveGooglePin: resolveGooglePin,
            ),
          )
          .toList(),
    );
  }
}

class AnalysisState {
  AnalysisState({
    required this.revision,
    required this.errands,
    required this.result,
    this.activeId,
    this.pending,
    this.answerBases = const {},
  });
  final int revision;
  final List<Errand> errands;
  final Interpretation result;
  final String? activeId;
  final AnalysisRun? pending;
  final Map<String, ErrandNeed> answerBases;
  Map<String, dynamic> toJson() => {
    'revision': revision,
    'activeId': activeId,
    'errands': errands.map((e) => e.toJson()).toList(),
    'result': {
      'needs': result.needs.map((n) => n.toJson()).toList(),
      'additions': result.additions.map((n) => n.toJson()).toList(),
    },
    'pending': pending?.toJson(),
    'answerBases': {
      for (final entry in answerBases.entries) entry.key: entry.value.toJson(),
    },
  };
  factory AnalysisState.fromJson(
    Map<String, dynamic> j, {
    GooglePinResolver? resolveGooglePin,
  }) {
    final errands = (j['errands'] as List)
        .map(
          (e) => Errand.fromJson(
            Map<String, dynamic>.from(e as Map),
            resolveGooglePin: resolveGooglePin,
          ),
        )
        .toList();
    return AnalysisState(
      revision: j['revision'] as int,
      activeId: j['activeId'] as String?,
      answerBases: readAnswerBases(j['answerBases']),
      errands: errands,
      result: Interpretation.fromJson(
        Map<String, dynamic>.from(j['result'] as Map),
        DayPlan(errands: errands),
      ),
      pending: j['pending'] == null
          ? null
          : AnalysisRun.fromJson(
              Map<String, dynamic>.from(j['pending'] as Map),
              resolveGooglePin: resolveGooglePin,
            ),
    );
  }
}

Map<String, ErrandNeed> readAnswerBases(Object? value) => {
  for (final entry in (value as Map? ?? const {}).entries)
    entry.key as String: ErrandNeed.fromJson(
      Map<String, dynamic>.from(entry.value as Map),
    ),
};
