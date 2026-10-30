import 'package:flutter/services.dart';
import '../../today/domain/day.dart';
import '../domain/planning_models.dart';
import 'interpretation_request.dart';
import 'gemini_request_client.dart';

abstract interface class ErrandInterpreter {
  Future<Interpretation> interpret(DayPlan day);
}

abstract interface class ConfirmedRetryInterpreter
    implements ErrandInterpreter {
  Future<Interpretation> retry(DayPlan day);
}

abstract interface class SavedErrandInterpreter implements ErrandInterpreter {
  Future<Interpretation> saved(DayPlan day);
}

class GeminiInterpreter
    implements ConfirmedRetryInterpreter, SavedErrandInterpreter {
  GeminiInterpreter({MethodChannel? channel, GeminiRequestClient? client})
    : client =
          client ??
          (channel == null
              ? GeminiRequestClient.shared
              : GeminiRequestClient(channel: channel));
  final GeminiRequestClient client;
  String? _lastInput;
  Interpretation? _lastResult;
  int? lastInputTokens, lastOutputTokens;
  @override
  Future<Interpretation> interpret(DayPlan day) => _start(day);
  @override
  Future<Interpretation> retry(DayPlan day) => _start(day, retry: true);
  @override
  Future<Interpretation> saved(DayPlan day) => _start(day, savedOnly: true);
  Future<bool> configured() => client.configured();
  Future<Interpretation> _start(
    DayPlan day, {
    bool retry = false,
    bool savedOnly = false,
  }) async {
    final body = interpretationRequest(day);
    if (_lastInput == body && _lastResult != null) return _lastResult!;
    final reply = await client.request(
      body,
      legacyBody: legacyInterpretationRequest(day),
      retry: retry,
      savedOnly: savedOnly,
    );
    try {
      final usage = reply.envelope['usageMetadata'] as Map?;
      lastInputTokens = usage?['promptTokenCount'] as int?;
      lastOutputTokens =
          (usage?['candidatesTokenCount'] as int? ?? 0) +
          (usage?['thoughtsTokenCount'] as int? ?? 0);
      final result = Interpretation.fromJson(reply.value, day);
      _lastInput = body;
      _lastResult = result;
      return result;
    } catch (_) {
      try {
        await client.invalidate(reply.body, 'interpretation');
      } catch (_) {}
      throw const PlanningFailure(
        'The saved answer could not be validated against these errands. An explicit retry may use another request.',
        kind: 'interpretation',
      );
    }
  }
}
