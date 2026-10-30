import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../domain/planning_models.dart';

/// Local usage limits are intentionally absent. Provider failures, interrupted
/// work and missing saved understanding each retain their own explanation.
class UnderstandingFailureView extends StatelessWidget {
  const UnderstandingFailureView({
    required this.onSaved,
    required this.onRetry,
    this.failure,
    this.error,
    super.key,
  });
  final PlanningFailure? failure;
  final String? error;
  final VoidCallback onSaved, onRetry;

  @override
  Widget build(BuildContext context) {
    final title = switch (failure?.kind) {
      'quota' => 'Gemini is temporarily limited',
      'connection' => 'Check your internet connection',
      'cache_miss' => 'No saved understanding',
      'configuration' || 'access' => 'Gemini setup needs attention',
      'recovery' ||
      'interrupted' ||
      'previous_failure' => 'Understanding needs a retry',
      _ => 'Couldn’t understand your errands',
    };
    final detail = switch (failure?.kind) {
      'quota' =>
        'Google is limiting requests for this project. Check its billing and quota settings, then try again.',
      'cache_miss' =>
        'These errands need a new interpretation. Retry Gemini to continue.',
      'recovery' =>
        'The saved answer is unavailable after recovery. Retry Gemini to understand these errands again.',
      'interrupted' =>
        'The previous request may still have a saved answer. Check it before starting another request.',
      'previous_failure' =>
        'The previous attempt did not leave a usable answer. You can retry when you’re ready.',
      _ =>
        error ?? failure?.message ?? 'Check for a saved answer or try again.',
    };
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                failure?.kind == 'connection'
                    ? Icons.wifi_off_outlined
                    : Icons.info_outline,
                size: 32,
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(title, style: context.type.titleLarge),
            ),
            const SizedBox(height: 8),
            Text(detail),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onSaved,
                child: const Text(
                  'Check saved understanding',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRetry,
                child: const Text('Retry Gemini', textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Checking saved understanding sends no new request. Retrying may use API credit.',
              style: context.type.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
