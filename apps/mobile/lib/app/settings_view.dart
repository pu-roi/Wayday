import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/feedback.dart';
import '../features/today/presentation/today_controller.dart';
import 'theme.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.route_rounded, size: 36, color: context.wayday.link),
            const SizedBox(height: 16),
            Text(
              'Wayday',
              style: context.type.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your list. A little more on the way.',
              style: context.type.bodyLarge?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Text('Try an example', style: context.type.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restart_alt_rounded),
              title: const Text('Reload example day'),
              onTap: () {
                ref.read(todayProvider.notifier).loadExample();
                showFeedback(context, 'Example day restored.');
              },
            ),
            const SizedBox(height: 24),
            Text('About this preview', style: context.type.titleMedium),
            const SizedBox(height: 12),
            Text(
              'Errands and recurring lists work in memory. Changes reset when the app restarts. Add recurring lists to Today whenever you choose; they are not added automatically.',
              style: context.type.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Maps are visual placeholders. Search, route planning, saved data, and reminders come later.',
              style: context.type.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
