import 'package:flutter/material.dart';
import '../core/widgets/section_surface.dart';
import 'theme.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 64,
      title: Text('Settings', style: context.type.headlineLarge),
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('On this device', style: context.type.titleMedium),
            const SizedBox(height: 12),
            SectionSurface(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your lists stay with you',
                      style: context.type.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Errands, notes, recurring lists and saved places are stored locally.',
                      style: context.type.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text('Trip time zone', style: context.type.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Asia/Manila',
                      style: context.type.bodyMedium?.copyWith(
                        color: context.wayday.link,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Uninstalling Wayday or clearing its storage removes this data. Recurring lists are added to Today only when you choose.',
              style: context.type.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Text('About Wayday', style: context.type.titleMedium),
            const SizedBox(height: 12),
            Text(
              'Search places in the Pasig/Ortigas pilot, choose a map pin and review your stop order. Place search uses a local development service. Routes and reminders are not connected yet. Times use Asia/Manila.',
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
