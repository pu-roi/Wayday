import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../features/maps/presentation/map_credits_page.dart';
import '../core/widgets/section_surface.dart';
import 'theme.dart';
import '../core/widgets/build_identity.dart';

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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            const SectionSurface(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Settings are not available yet.'),
              ),
            ),
            const SizedBox(height: 32),
            Image.asset(
              'assets/branding/wayday-logo.png',
              width: 72,
              height: 72,
              semanticLabel: 'Wayday logo',
            ),
            const SizedBox(height: 16),
            Text(
              'Wayday',
              style: context.type.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text('About Wayday', style: context.type.titleMedium),
            const BuildIdentity(),
            const SizedBox(height: 12),
            Text(
              kIsWeb
                  ? 'This browser preview keeps changes for this session. Add recurring lists to Today whenever you choose; they are not added automatically.'
                  : 'Your errands, recurring lists, saved trips, and saved places stay on this device. Add recurring lists to Today whenever you choose; they are not added automatically.',
              style: context.type.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Place search, maps, and route updates use online services.',
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
