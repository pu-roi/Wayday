import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../maps/presentation/map_credits_page.dart';
import '../domain/place_intent.dart';
import 'place_search_controller.dart';

class PlaceSearchPanel extends StatelessWidget {
  const PlaceSearchPanel({
    required this.search,
    required this.saved,
    required this.onSelect,
    required this.onNameOnly,
    required this.onClose,
    this.savedError = false,
    this.onRetrySaved,
    super.key,
  });
  final PlaceSearchController search;
  final List<SavedPlace> saved;
  final ValueChanged<PlaceIntent> onSelect;
  final VoidCallback onNameOnly, onClose;
  final bool savedError;
  final VoidCallback? onRetrySaved;

  @override
  Widget build(BuildContext context) {
    final matches = saved.where(
      (place) =>
          place.place.label.toLowerCase().contains(search.query.toLowerCase()),
    );
    return Material(
      color: context.colors.surface,
      child: ListView(
        key: const Key('place-search-results'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        children: [
          if (matches.isNotEmpty) ...[
            Text('Saved places', style: context.type.titleSmall),
            for (final saved in matches)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bookmark_outline),
                title: Text(saved.place.label),
                subtitle: Text(saved.place.address ?? 'Saved pin'),
                onTap: () => onSelect(saved.intent),
              ),
            const Divider(),
          ],
          if (savedError)
            TextButton(
              onPressed: onRetrySaved,
              child: const Text('Retry loading saved places'),
            ),
          if (search.loading) const LinearProgressIndicator(),
          if (search.failed) ...[
            const Text('Place search is unavailable.'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: search.retry,
                child: const Text('Retry search'),
              ),
            ),
          ] else if (search.searched && search.results.isEmpty)
            const Text(
              'No matching places found. Try another name or move the map.',
            ),
          for (final result in search.results)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text(result.name),
              subtitle: Text(result.address ?? 'Address not recorded'),
              onTap: () => onSelect(
                PlaceIntent(
                  kind: PlaceKind.specific,
                  label: result.name,
                  latitude: result.latitude,
                  longitude: result.longitude,
                  source: result.sourceId,
                  address: result.address,
                ),
              ),
            ),
          if (search.results.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => openMapCredits(context),
                child: const Text('© OpenStreetMap contributors'),
              ),
            ),
          if (search.query.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_location_alt_outlined),
              title: const Text('Use name only'),
              subtitle: const Text('Saves this name without a map pin.'),
              onTap: onNameOnly,
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Back to map'),
            ),
          ),
        ],
      ),
    );
  }
}
