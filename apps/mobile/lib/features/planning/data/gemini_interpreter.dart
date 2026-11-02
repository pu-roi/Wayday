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

abstract interface class FreshErrandInterpreter implements ErrandInterpreter {
  Future<Interpretation> analyze(
    DayPlan day, {
    required String runId,
    required String body,
    bool retry = false,
    bool savedOnly = false,
  });
}

class GeminiInterpreter
    implements
        ConfirmedRetryInterpreter,
        SavedErrandInterpreter,
        FreshErrandInterpreter {
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
  @override
  Future<Interpretation> analyze(
    DayPlan day, {
    required String runId,
    required String body,
    bool retry = false,
    bool savedOnly = false,
  }) => _start(
    day,
    retry: retry,
    savedOnly: savedOnly,
    runId: runId,
    requestBody: body,
  );
  Future<Interpretation> _start(
    DayPlan day, {
    bool retry = false,
    bool savedOnly = false,
    String? runId,
    String? requestBody,
  }) async {
    final body = requestBody ?? interpretationRequest(day);
    final memoryKey = '${runId ?? ''}:$body';
    if (_lastInput == memoryKey && _lastResult != null) return _lastResult!;
    final reply = await client.request(
      body,
      legacyBodies: [
        transportInterpretationRequest(day),
        searchIntentInterpretationRequest(day),
        locationInterpretationRequest(day),
        previousInterpretationRequest(day),
        legacyInterpretationRequest(day),
      ],
      retry: retry,
      savedOnly: savedOnly,
      runId: runId,
    );
    try {
      final usage = reply.envelope['usageMetadata'] as Map?;
      lastInputTokens = usage?['promptTokenCount'] as int?;
      lastOutputTokens =
          (usage?['candidatesTokenCount'] as int? ?? 0) +
          (usage?['thoughtsTokenCount'] as int? ?? 0);
      final result = Interpretation.fromJson(reply.value, day);
      if (reply.body == body &&
          [
            ...result.needs,
            ...result.additions,
          ].any((n) => n.locationIntent == null)) {
        throw const FormatException(
          'Current understanding omitted destination intent',
        );
      }
      _lastInput = memoryKey;
      _lastResult = result;
      return result;
    } catch (_) {
      try {
        await client.invalidate(reply.body, 'interpretation', runId: runId);
      } catch (_) {}
      throw const PlanningFailure(
        'The saved answer could not be validated against these errands. An explicit retry may use another request.',
        kind: 'interpretation',
      );
    }
  }
}
