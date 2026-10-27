import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'theme.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
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
            Text('About Wayday', style: context.type.titleMedium),
            const SizedBox(height: 12),
            Text(
              kIsWeb
                  ? 'This browser preview keeps changes for this session. Add recurring lists to Today whenever you choose; they are not added automatically.'
                  : 'Your errands and recurring lists are saved on this device. Add recurring lists to Today whenever you choose; they are not added automatically.',
              style: context.type.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Maps are visual previews. Place search, trip planning, saved trips, and reminders are coming later.',
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
