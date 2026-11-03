import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/feedback.dart';
import 'bundled_license_notice.dart';

void openMapCredits(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const MapCreditsPage()));
}

class MapCreditsPage extends StatelessWidget {
  const MapCreditsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: MediaQuery.textScalerOf(context).scale(14) > 17
          ? 80
          : kToolbarHeight,
      title: const Text(
        'Map credits and licenses',
        maxLines: 2,
        softWrap: true,
      ),
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: const [
            _CreditsSection(
              title: 'Online maps',
              children: [
                _CreditLink(
                  label: '© OpenStreetMap contributors',
                  url: 'https://www.openstreetmap.org/copyright',
                ),
                _CreditLink(
                  label: 'Open Database License (ODbL)',
                  url: 'https://opendatacommons.org/licenses/odbl/1-0/',
                ),
                _CreditLink(
                  label: 'OpenFreeMap',
                  url: 'https://openfreemap.org/',
                ),
                _CreditLink(
                  label: 'OpenMapTiles',
                  url: 'https://openmaptiles.org/',
                ),
              ],
            ),
            _CreditsSection(
              title: 'Place search',
              children: [
                _CreditLink(
                  label: 'Google Maps',
                  url: 'https://maps.google.com/',
                ),
                _CreditLink(
                  label: 'Powered by Geoapify',
                  url: 'https://www.geoapify.com/',
                ),
                _CreditLink(
                  label: 'Search by LocationIQ.com',
                  url: 'https://locationiq.com/',
                ),
                _CreditLink(
                  label: 'Photon / OpenStreetMap contributors',
                  url: 'https://photon.komoot.io/',
                ),
              ],
            ),
            _CreditsSection(
              title: 'Supporting datasets',
              children: [
                Text(
                  'Philippine brand vocabulary uses OpenStreetMap Name Suggestion Index 8.0.20260918. No logos or branch coordinates are bundled.',
                ),
                SizedBox(height: 8),
                BundledLicenseNotice(
                  title: 'Name Suggestion Index · BSD 3-Clause',
                  asset: 'assets/notices/nsi/LICENSE.txt',
                ),
                SizedBox(height: 16),
                Text(
                  'Philippine search eligibility: Made with Natural Earth, public-domain country data (v5.1.2). Cartographic land mask; coastal precision and small-island coverage are limited.',
                ),
                _CreditLink(
                  label: 'Natural Earth · public domain',
                  url: 'https://www.naturalearthdata.com/about/terms-of-use/',
                ),
              ],
            ),
            _CreditsSection(
              title: 'Fonts',
              children: [
                BundledLicenseNotice(
                  title: 'Figtree · SIL Open Font License 1.1',
                  asset: 'assets/fonts/OFL.txt',
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _CreditsSection extends StatelessWidget {
  const _CreditsSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: context.type.titleMedium),
        ),
        const SizedBox(height: 8),
        DefaultTextStyle(
          style: context.type.bodyMedium!.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );
}

class _CreditLink extends StatelessWidget {
  const _CreditLink({required this.label, required this.url});
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 48,
      title: Text(
        label,
        style: context.type.bodyMedium?.copyWith(color: context.wayday.link),
      ),
      trailing: Icon(
        Icons.open_in_new_rounded,
        size: 18,
        color: context.wayday.link,
      ),
      onTap: () async {
        var opened = false;
        try {
          opened = await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {
          // Keep the credit visible when no external browser is available.
        }
        if (!opened && context.mounted) {
          showFeedback(context, 'This link could not open. Try again.');
        }
      },
    ),
  );
}
