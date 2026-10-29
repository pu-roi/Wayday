import 'dart:convert';
import 'package:flutter/services.dart';
import '../../today/domain/day.dart';
import '../domain/planning_models.dart';
import 'planning_budget.dart';
import 'interpretation_request.dart';

abstract interface class ErrandInterpreter {
  Future<Interpretation> interpret(DayPlan day);
}

abstract interface class ConfirmedRetryInterpreter
    implements ErrandInterpreter {
  Future<Interpretation> retry(DayPlan day);
}

class GeminiInterpreter implements ConfirmedRetryInterpreter {
  GeminiInterpreter(
    this.budget, {
    this.channel = const MethodChannel('wayday/planning'),
  });
  final PlanningBudget budget;
  final MethodChannel channel;
  String? _lastInput, _flightInput;
  Interpretation? _lastResult;
  Future<Interpretation>? _flight;
  int? lastInputTokens, lastOutputTokens;

  @override
  Future<Interpretation> interpret(DayPlan day) => _start(day, false);
  @override
  Future<Interpretation> retry(DayPlan day) => _start(day, true);

  Future<Interpretation> _start(DayPlan day, bool retry) {
    final String body;
    try {
      body = interpretationRequest(day);
    } catch (e) {
      return Future.error(e);
    }
    if (_lastInput == body && _lastResult != null) {
      return Future.value(_lastResult);
    }
    if (_flightInput == body && _flight != null) return _flight!;
    if (_flight != null) {
      return Future.error(
        const PlanningFailure(
          'Another interpretation is finishing. Try again in a moment; no new request has been sent.',
        ),
      );
    }
    _flightInput = body;
    final request = _interpret(day, body, retry).then((value) {
      _lastInput = body;
      _lastResult = value;
      return value;
    });
    _flight = request;
    return request.whenComplete(() {
      _flight = null;
      _flightInput = null;
    });
  }

  Future<bool> configured() async {
    try {
      return (await channel.invokeMapMethod<String, dynamic>(
            'geminiStatus',
          ))?['configured'] ==
          true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<Interpretation> _interpret(
    DayPlan day,
    String body,
    bool retry,
  ) async {
    try {
      Map<String, dynamic>? stored;
      try {
        stored = await channel
            .invokeMapMethod<String, dynamic>('interpretationStatus', {
              'body': body,
            })
            .timeout(const Duration(seconds: 40));
      } on PlatformException catch (e) {
        if (!retry || e.code != 'cache') rethrow;
        stored = {'state': 'corrupt'};
      }
      final state = stored?['state'];
      if (state == 'completed') {
        return await _decode(stored!['response'] as String, day, body);
      }
      if (state == null) {
        throw const PlanningFailure(
          'Saved understanding could not be checked. No new request was sent.',
          kind: 'cache',
        );
      }
      if (state != 'missing' && !retry) {
        throw PlanningFailure(
          state == 'pending'
              ? 'The previous request was interrupted before an answer was saved. Check again, or explicitly retry; retrying may use another request.'
              : 'The previous request did not produce a usable saved answer. Retry only when you want to use another request.',
          kind: state == 'pending' ? 'interrupted' : 'previous_failure',
        );
      }
      final status = await channel.invokeMapMethod<String, dynamic>(
        'geminiStatus',
      );
      if (status?['configured'] != true) {
        throw const PlanningFailure(
          'Gemini has not been configured on this device. Your errands are kept.',
          kind: 'configuration',
        );
      }
      if ((status?['remainingGenerations'] as int? ?? 0) <= 0) {
        throw const PlanningFailure(
          'The approved Gemini request allowance is exhausted. Saved understanding remains available.',
          kind: 'paid_allowance',
        );
      }
      await budget.reserve('gemini', 1, daily: 3, monthly: 10);
      final raw = await channel
          .invokeMethod<String>('interpret', {'body': body, 'retry': retry})
          .timeout(const Duration(seconds: 40));
      if (raw == null) {
        throw const PlanningFailure(
          'Gemini returned no saved answer. Check again before retrying.',
          kind: 'interrupted',
        );
      }
      return await _decode(raw, day, body);
    } on PlatformException catch (e) {
      throw PlanningFailure(switch (e.code) {
        'cache' =>
          'Saved understanding could not be read or saved. No automatic retry was sent.',
        'interrupted' =>
          'The previous request may already have used credit. Check for its saved answer or explicitly retry.',
        'previous_failure' =>
          'The previous request failed. An explicit retry may use another request.',
        'quota' => 'Gemini’s quota is unavailable. Your errands are kept.',
        'access' =>
          'Gemini access was denied. Check the private device configuration.',
        'paid_allowance' =>
          'The approved Gemini request allowance is exhausted. Your errands are kept.',
        _ =>
          'Understanding is unavailable. Check for a saved answer before retrying.',
      }, kind: e.code);
    } on MissingPluginException {
      throw const PlanningFailure(
        'Gemini is available in the configured Android app.',
        kind: 'configuration',
      );
    } on PlanningFailure {
      rethrow;
    } catch (_) {
      throw const PlanningFailure(
        'Understanding was interrupted. Check for a saved answer before using another request.',
        kind: 'interrupted',
      );
    }
  }

  Future<Interpretation> _decode(String raw, DayPlan day, String body) async {
    try {
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final usage = envelope['usageMetadata'] as Map?;
      lastInputTokens = usage?['promptTokenCount'] as int?;
      lastOutputTokens =
          (usage?['candidatesTokenCount'] as int? ?? 0) +
          (usage?['thoughtsTokenCount'] as int? ?? 0);
      final candidate = (envelope['candidates'] as List).single as Map;
      if (candidate['finishReason'] != 'STOP') throw const FormatException();
      final parts = ((candidate['content'] as Map)['parts'] as List)
          .cast<Map<String, dynamic>>();
      final text = parts
          .where((p) => p['thought'] != true)
          .map((p) => p['text'] as String? ?? '')
          .join();
      return Interpretation.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
        day,
      );
    } catch (_) {
      try {
        await channel.invokeMethod<void>('invalidateInterpretation', {
          'body': body,
        });
      } catch (_) {}
      throw const PlanningFailure(
        'The saved answer could not be validated against these errands. An explicit retry may use another request.',
        kind: 'interpretation',
      );
    }
  }
}
