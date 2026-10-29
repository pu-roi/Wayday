import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/feedback.dart';

class SearchAttribution extends StatelessWidget {
  const SearchAttribution({required this.credits, super.key});
  final List<String> credits;
  @override
  Widget build(BuildContext context) => Wrap(
    children: [
      for (final credit in credits.toSet())
        TextButton(
          onPressed: () async {
            final uri = Uri.parse(
              credit == 'Powered by Geoapify'
                  ? 'https://www.geoapify.com/'
                  : credit == 'Search by LocationIQ.com'
                  ? 'https://locationiq.com/'
                  : credit == 'Google Maps'
                  ? 'https://maps.google.com/'
                  : 'https://www.openstreetmap.org/copyright',
            );
            try {
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
                  context.mounted) {
                showFeedback(
                  context,
                  'Could not open credits. Try again.',
                  advisory: true,
                );
              }
            } catch (_) {
              if (context.mounted) {
                showFeedback(
                  context,
                  'Could not open credits. Try again.',
                  advisory: true,
                );
              }
            }
          },
          child: Text(
            credit,
            maxLines: credit == 'Google Maps' ? 1 : null,
            style: credit == 'Google Maps'
                ? Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5E5E5E),
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.normal,
                  )
                : Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ],
  );
}
