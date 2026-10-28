import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../features/maps/presentation/regional_map.dart';
import '../features/maps/presentation/map_credits_page.dart';
import '../core/widgets/section_surface.dart';
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
            const ExpansionTile(
              title: Text('Offline Pasig/Ortigas preview'),
              children: [RegionalMap()],
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
              kIsWeb
                  ? 'Search uses an online place service. The regional offline map is available on Android; browser map support may differ. Trip planning, saved trips, and reminders are coming later.'
                  : 'Search and map pin selection use online services. The offline regional map covers Pasig/Ortigas. Trip planning, saved trips, and reminders are coming later.',
              style: context.type.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            SectionSurface(
              child: ListTile(
                title: const Text('Map credits and licenses'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openMapCredits(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
