import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../data/regional_map_repository.dart';
import 'package:flutter/services.dart';

void openMapCredits(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const MapCreditsPage()));
}

class MapCreditsPage extends ConsumerWidget {
  const MapCreditsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Map credits and licenses')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Online map and place search',
              style: context.type.titleMedium,
            ),
            const SizedBox(height: 8),
            const SelectableText(
              '© OpenStreetMap contributors · OpenFreeMap · OpenMapTiles\n'
              'OpenStreetMap data: https://www.openstreetmap.org/copyright\n'
              'Open Database License: https://opendatacommons.org/licenses/odbl/1-0/\n'
              'OpenMapTiles: https://openmaptiles.org/\n'
              'OpenFreeMap: https://openfreemap.org/',
            ),
            const SizedBox(height: 24),
            ref
                .watch(regionalMapCreditsProvider)
                .when(
                  loading: () => const CircularProgressIndicator(),
                  error: (_, _) => const Text(
                    'Offline map credits and licenses are unavailable on this device.',
                  ),
                  data: (credits) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Offline map', style: context.type.titleMedium),
                      const SizedBox(height: 8),
                      Text(credits.region ?? 'Region unavailable'),
                      Text(
                        credits.sourceDate == null
                            ? 'Source date unavailable'
                            : 'Source ${credits.sourceDate}',
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Attribution and licenses',
                        style: context.type.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      SelectableText(credits.notices),
                    ],
                  ),
                ),
            Text('Place search', style: context.type.titleMedium),
            const SelectableText(
              'Google Maps · Powered by Geoapify · Search by LocationIQ.com · Photon / OpenStreetMap contributors',
            ),
            const SizedBox(height: 12),
            const Text(
              'Philippine brand vocabulary: OpenStreetMap Name Suggestion Index 8.0.20260918. No logos or branch coordinates are bundled.',
            ),
            FutureBuilder<String>(
              future: rootBundle.loadString('assets/notices/nsi/LICENSE.txt'),
              builder: (context, snapshot) => snapshot.hasData
                  ? SelectableText(snapshot.data!)
                  : const Text('NSI BSD-3-Clause notice is loading.'),
            ),
            const SizedBox(height: 24),
            const SelectableText(
              'Philippine search eligibility: Made with Natural Earth, public-domain country data (v5.1.2). Cartographic land mask; coastal precision and small-island coverage are limited. https://www.naturalearthdata.com/about/terms-of-use/',
            ),
            const SizedBox(height: 24),
            const Text('Figtree font · SIL Open Font License 1.1'),
            FutureBuilder<String>(
              future: rootBundle.loadString('assets/fonts/OFL.txt'),
              builder: (context, snapshot) => snapshot.hasData
                  ? SelectableText(snapshot.data!)
                  : const Text('Font license is loading.'),
            ),
          ],
        ),
      ),
    ),
  );
}
