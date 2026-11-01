import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'planning_models.dart';

/// Source-owned language facts only. Route settings and coordinates stay out.
class LocationAssessmentContext {
  LocationAssessmentContext(Map<String, dynamic> facts)
    : facts = Map.unmodifiable(facts);
  final Map<String, dynamic> facts;
  String get id => facts['id'] as String;
  String get key => sha256.convert(utf8.encode(jsonEncode(facts))).toString();
}

class LocationAssessmentResult {
  const LocationAssessmentResult({
    required this.intent,
    required this.summary,
    this.question,
    this.query,
    this.category,
  });
  final LocationIntent intent;
  final String summary;
  final String? question, query, category;
  Map<String, dynamic> toJson() => {
    'locationIntent': intent.name,
    'summary': summary,
    'question': question,
    'query': query,
    'category': category,
  };
  factory LocationAssessmentResult.fromJson(
    Map<String, dynamic> value,
    String id,
  ) {
    const fields = {
      'id',
      'locationIntent',
      'summary',
      'question',
      'query',
      'category',
    };
    final intent = value['locationIntent'],
        summary = value['summary'],
        question = value['question'],
        query = value['query'],
        category = value['category'];
    if (value.keys.any((k) => !fields.contains(k)) ||
        value['id'] != id ||
        !LocationIntent.values.any((v) => v.name == intent) ||
        summary is! String ||
        summary.trim().isEmpty ||
        summary.length > 240 ||
        (question != null &&
            (question is! String ||
                question.trim().isEmpty ||
                question.length > 240)) ||
        (intent == 'unclear' && question == null) ||
        (query != null &&
            (query is! String || query.trim().isEmpty || query.length > 100)) ||
        (category != null && !ErrandNeed.categories.contains(category))) {
      throw const FormatException('Invalid location assessment');
    }
    return LocationAssessmentResult(
      intent: LocationIntent.values.byName(intent as String),
      summary: summary.trim(),
      question: question as String?,
      query: query as String?,
      category: category as String?,
    );
  }
}

class LocationAssessment {
  LocationAssessment({
    required this.context,
    required this.revision,
    required this.updatedAt,
    this.status = 'processing',
    this.result,
    this.persisted = false,
  });
  final LocationAssessmentContext context;
  final int revision;
  int updatedAt;
  String status;
  LocationAssessmentResult? result;
  bool persisted;
  bool get applied => persisted && status == 'completed' && result != null;
  Map<String, dynamic> toJson() => {
    'facts': context.facts,
    'revision': revision,
    'updatedAt': updatedAt,
    'status': status,
    'result': result?.toJson(),
  };
  factory LocationAssessment.fromJson(Map<String, dynamic> value) {
    final facts = Map<String, dynamic>.from(value['facts'] as Map),
        revision = value['revision'],
        at = value['updatedAt'],
        status = value['status'];
    if (facts['version'] != 1 ||
        facts['id'] is! String ||
        revision is! int ||
        revision <= 0 ||
        at is! int ||
        at < 0 ||
        !{'processing', 'completed', 'failed'}.contains(status)) {
      throw const FormatException('Invalid saved location assessment');
    }
    final context = LocationAssessmentContext(facts);
    final result = value['result'] == null
        ? null
        : LocationAssessmentResult.fromJson({
            'id': context.id,
            ...Map<String, dynamic>.from(value['result'] as Map),
          }, context.id);
    if (status == 'completed' && result == null) {
      throw const FormatException('Missing location assessment result');
    }
    return LocationAssessment(
      context: context,
      revision: revision,
      updatedAt: at,
      status: status as String,
      result: result,
      persisted: true,
    );
  }
}
