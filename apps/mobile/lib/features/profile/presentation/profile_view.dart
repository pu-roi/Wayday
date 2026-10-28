import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/section_surface.dart';
import '../../places/presentation/saved_places_page.dart';

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
                CircleAvatar(
                  radius: 34,
                  backgroundColor: context.colors.secondaryContainer,
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 32,
                    color: context.wayday.link,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your profile', style: context.type.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        'On this device',
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
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Profile details are not available yet.'),
              ),
            ),
            const SizedBox(height: 24),
            SectionSurface(
              child: ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('Saved places'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SavedPlacesPage(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Your privacy', style: context.type.titleMedium),
            const SizedBox(height: 12),
            const Text(
              'Your errands and saved places stay on this device. Search requests use an online service.',
            ),
          ],
        ),
      ),
    ),
  );
}
