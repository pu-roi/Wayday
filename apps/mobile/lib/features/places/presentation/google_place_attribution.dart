import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:url_launcher/url_launcher.dart';
import 'search_attribution.dart';

/// Preserve provider attribution text, emphasis and links without executing HTML.
class GooglePlaceAttribution extends StatefulWidget {
  const GooglePlaceAttribution({
    required this.credits,
    this.showGoogleMaps = true,
    super.key,
  });
  final List<String> credits;
  final bool showGoogleMaps;
  @override
  State<GooglePlaceAttribution> createState() => _GooglePlaceAttributionState();
}

class _GooglePlaceAttributionState extends State<GooglePlaceAttribution> {
  final links = <String, TapGestureRecognizer>{};
  @override
  void dispose() {
    for (final link in links.values) {
      link.dispose();
    }
    super.dispose();
  }

  InlineSpan span(dom.Node node) {
    if (node is dom.Text) return TextSpan(text: node.data);
    if (node is! dom.Element || {'script', 'style'}.contains(node.localName)) {
      return const TextSpan();
    }
    if (node.localName == 'br') return const TextSpan(text: '\n');
    final uri = Uri.tryParse(node.attributes['href'] ?? '');
    final isLink =
        node.localName == 'a' &&
        uri != null &&
        {'https', 'http'}.contains(uri.scheme) &&
        uri.host.isNotEmpty;
    return TextSpan(
      children: node.nodes.map(span).toList(),
      recognizer: isLink
          ? links.putIfAbsent(
              uri.toString(),
              () => TapGestureRecognizer()
                ..onTap = () async {
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    /* The full credit stays visible. */
                  }
                },
            )
          : null,
      style: TextStyle(
        fontWeight: {'b', 'strong'}.contains(node.localName)
            ? FontWeight.bold
            : null,
        fontStyle: {'i', 'em'}.contains(node.localName)
            ? FontStyle.italic
            : null,
        decoration: isLink ? TextDecoration.underline : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.showGoogleMaps)
        const SearchAttribution(credits: ['Google Maps']),
      for (final credit in widget.credits.toSet())
        Text.rich(
          TextSpan(children: parseFragment(credit).nodes.map(span).toList()),
          style: Theme.of(context).textTheme.bodySmall,
        ),
    ],
  );
}

class GoogleMapsAttributionLabel extends StatelessWidget {
  const GoogleMapsAttributionLabel({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
    child: Text(
      'Google Maps',
      maxLines: 1,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: const Color(0xFF5E5E5E),
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.normal,
      ),
    ),
  );
}
