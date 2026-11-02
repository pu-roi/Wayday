import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/planning_models.dart';

class GeminiReply {
  const GeminiReply(this.body, this.raw);
  final String body, raw;
  Map<String, dynamic> get envelope => jsonDecode(raw) as Map<String, dynamic>;
  Map<String, dynamic> get value {
    final candidate = (envelope['candidates'] as List).single as Map;
    if (candidate['finishReason'] != 'STOP') {
      throw const FormatException('Incomplete answer');
    }
    final parts = ((candidate['content'] as Map)['parts'] as List)
        .cast<Map<String, dynamic>>();
    return jsonDecode(
          parts
              .where((p) => p['thought'] != true)
              .map((p) => p['text'] as String? ?? '')
              .join(),
        )
        as Map<String, dynamic>;
  }
}

/// Both workflows share durable lookup, coalescing and explicit retry policy.
class GeminiRequestClient {
  GeminiRequestClient({this.channel = const MethodChannel('wayday/planning')});
  static final shared = GeminiRequestClient();
  final MethodChannel channel;
  final _flights = <String, Future<GeminiReply>>{};
  Future<GeminiReply> request(
    String body, {
    String purpose = 'interpretation',
    String? legacyBody,
    List<String> legacyBodies = const [],
    bool retry = false,
    bool savedOnly = false,
    String? runId,
  }) {
    final key = '$purpose:${runId ?? ''}:$body';
    final existing = _flights[key];
    if (existing != null) return existing;
    final result = _request(
      body,
      purpose,
      [?legacyBody, ...legacyBodies],
      retry,
      savedOnly,
      runId,
    );
    _flights[key] = result;
    return result.whenComplete(() {
      if (identical(_flights[key], result)) _flights.remove(key);
    });
  }

  Future<Map<String, dynamic>> _status(
    String body,
    String purpose,
    bool retry, [
    String? runId,
  ]) async {
    try {
      final status = await channel
          .invokeMapMethod<String, dynamic>('interpretationStatus', {
            'body': body,
            'purpose': purpose,
            'runId': ?runId,
          })
          .timeout(const Duration(seconds: 40));
      if (status == null) {
        throw const PlanningFailure(
          'Saved understanding could not be checked.',
          kind: 'cache',
        );
      }
      return status;
    } on PlatformException catch (e) {
      if (retry && e.code == 'cache') return {'state': 'corrupt'};
      rethrow;
    }
  }

  Future<GeminiReply> _request(
    String body,
    String purpose,
    List<String> historical,
    bool retry,
    bool savedOnly,
    String? runId,
  ) async {
    try {
      var status = await _status(body, purpose, retry, runId);
      if (status['state'] == 'completed') {
        return GeminiReply(body, status['response'] as String);
      }
      for (final legacy
          in (runId == null ? historical : <String>[]).toSet().where(
            (value) => value != body,
          )) {
        final old = await _status(legacy, purpose, retry);
        if (old['state'] == 'completed') {
          return GeminiReply(legacy, old['response'] as String);
        }
        if ({'missing', 'recovery'}.contains(status['state']) &&
            old['state'] != 'missing') {
          status = old;
        }
      }
      final state = status['state'];
      if (state != 'missing' && !retry) {
        if (state == 'failed') {
          final failure = _providerFailure(status['failure']);
          if (failure != null) throw failure;
        }
        throw PlanningFailure(
          state == 'pending'
              ? 'The previous request may still be processing. Check for its saved answer before retrying.'
              : state == 'recovery'
              ? 'Saved understanding was lost during installation recovery. Retry Gemini only when you want to use another request.'
              : 'The previous request did not leave a usable answer. An explicit retry may use API credit.',
          kind: state == 'pending'
              ? 'interrupted'
              : state == 'recovery'
              ? 'recovery'
              : 'previous_failure',
        );
      }
      if (savedOnly) {
        throw const PlanningFailure(
          'No saved understanding matches these inputs.',
          kind: 'cache_miss',
        );
      }
      if (!await configured()) {
        throw const PlanningFailure(
          'Gemini has not been configured on this device.',
          kind: 'configuration',
        );
      }
      final raw = await channel
          .invokeMethod<String>('interpret', {
            'body': body,
            'purpose': purpose,
            'retry': retry,
            'contractVersion': 'errand-v2',
            'runId': ?runId,
          })
          .timeout(const Duration(seconds: 40));
      if (raw == null) {
        throw const PlanningFailure(
          'No saved answer was returned. Check again before retrying.',
          kind: 'interrupted',
        );
      }
      return GeminiReply(body, raw);
    } on PlatformException catch (e) {
      final failure = _providerFailure(e.code);
      if (failure != null) throw failure;
      throw PlanningFailure(switch (e.code) {
        'cache' =>
          'Saved understanding could not be read or saved. No automatic retry was sent.',
        'connection' =>
          'Gemini could not be reached. Check your phone’s internet connection.',
        'configuration' => 'Gemini has not been configured on this device.',
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
        'Understanding was interrupted. Check for a saved answer before retrying.',
        kind: 'interrupted',
      );
    }
  }

  /// Allowlisted diagnostics only. Never display native/provider message text.
  PlanningFailure? _providerFailure(Object? code) {
    final status =
        code is String && RegExp(r'^http_[1-5][0-9]{2}$').hasMatch(code)
        ? int.parse(code.substring(5))
        : null;
    if (code == 'access' || status == 401 || status == 403) {
      return const PlanningFailure(
        'Gemini access was denied. Check the device configuration.',
        kind: 'access',
      );
    }
    if (code == 'quota' || status == 429) {
      return const PlanningFailure(
        'Google has temporarily limited Gemini requests.',
        kind: 'quota',
      );
    }
    if (status == 400 || status == 422) {
      return PlanningFailure(
        'Gemini rejected the app’s request (HTTP $status). The request format needs investigation; repeating the same request may fail again.',
        kind: 'request_rejected',
      );
    }
    if (status == 404) {
      return const PlanningFailure(
        'The configured Gemini model or endpoint was not found (HTTP 404). The app configuration needs investigation.',
        kind: 'model_unavailable',
      );
    }
    if (status != null) {
      return PlanningFailure(
        'Gemini returned HTTP $status without a usable answer. Your errands are kept. Retry only when you’re ready.',
        kind: 'provider_failure',
      );
    }
    return null;
  }

  Future<bool> configured() async =>
      (await channel.invokeMapMethod<String, dynamic>(
        'geminiStatus',
      ))?['configured'] ==
      true;
  Future<void> invalidate(String body, String purpose, {String? runId}) async {
    await channel.invokeMethod<void>('invalidateInterpretation', {
      'body': body,
      'purpose': purpose,
      'runId': ?runId,
    });
  }
}
