import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/section_surface.dart';

/// A deliberately read-only preview; this is not an authenticated identity.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 64,
      title: Text('Profile', style: context.type.headlineLarge),
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: context.colors.secondaryContainer,
                    foregroundColor: context.wayday.link,
                    child: Text('JB', style: context.type.titleLarge),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Jace Bellen', style: context.type.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        'Sample profile',
                        style: context.type.bodyMedium?.copyWith(
                          color: context.wayday.link,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text('Personal details', style: context.type.titleMedium),
            const SizedBox(height: 12),
            const SectionSurface(
              child: Column(
                children: [
                  _ProfileDetail(
                    label: 'Email',
                    icon: Icons.mail_outline_rounded,
                  ),
                  Divider(indent: 20, endIndent: 20),
                  _ProfileDetail(
                    label: 'Phone number',
                    icon: Icons.phone_outlined,
                  ),
                  Divider(indent: 20, endIndent: 20),
                  _ProfileDetail(
                    label: 'Home area',
                    icon: Icons.location_on_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Details aren’t editable in this preview.',
              style: context.type.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Text('When you share a trip', style: context.type.titleMedium),
            const SizedBox(height: 12),
            Text(
              'Your name will help people recognize your itinerary. Live sharing isn’t connected yet, and nothing is shared from this preview.',
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

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      children: [
        ExcludeSemantics(
          child: Icon(icon, size: 20, color: context.wayday.link),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.type.bodyMedium),
              const SizedBox(height: 4),
              Text(
                'Not added',
                style: context.type.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
