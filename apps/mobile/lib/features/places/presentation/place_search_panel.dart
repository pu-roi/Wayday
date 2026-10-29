import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../domain/place_intent.dart';
import '../domain/search_ranking.dart';
import 'place_search_controller.dart';
import 'search_attribution.dart';
import '../data/google_search.dart';
import 'google_search_view.dart';

class PlaceSearchPanel extends StatefulWidget {
  const PlaceSearchPanel({
    required this.search,
    required this.saved,
    required this.onSelect,
    required this.onNameOnly,
    required this.onClose,
    this.savedError = false,
    this.onRetrySaved,
    this.onUseLocation,
    this.onOpenSettings,
    this.locating = false,
    this.locationMessage,
    super.key,
  });
  final PlaceSearchController search;
  final List<SavedPlace> saved;
  final ValueChanged<PlaceIntent> onSelect;
  final VoidCallback onNameOnly, onClose;
  final bool savedError;
  final VoidCallback? onRetrySaved;
  final VoidCallback? onUseLocation, onOpenSettings;
  final bool locating;
  final String? locationMessage;
  @override
  State<PlaceSearchPanel> createState() => _PlaceSearchPanelState();
}

class _PlaceSearchPanelState extends State<PlaceSearchPanel> {
  bool _googleMounted = false;
  Widget? _otherContent;
  List<Widget> _googleControls = [];
  PlaceSearchController get search => widget.search;
  List<SavedPlace> get saved => widget.saved;
  ValueChanged<PlaceIntent> get onSelect => widget.onSelect;
  VoidCallback get onNameOnly => widget.onNameOnly;
  VoidCallback get onClose => widget.onClose;
  bool get savedError => widget.savedError;
  VoidCallback? get onRetrySaved => widget.onRetrySaved;
  VoidCallback? get onUseLocation => widget.onUseLocation;
  VoidCallback? get onOpenSettings => widget.onOpenSettings;
  bool get locating => widget.locating;
  String? get locationMessage => widget.locationMessage;
  // Both source groups keep these controls and rows when the keyboard opens.
  List<Widget> _controls(BuildContext context, List<SavedPlace> matches) => [
    _SearchSourceButtons(search: search),
    if (onUseLocation != null) ...[
      Text(
        search.originLabel,
        key: const Key('search-origin'),
        style: context.type.labelLarge,
      ),
      Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: locating ? null : onUseLocation,
            icon: const Icon(Icons.my_location_rounded),
            label: Text(
              locating
                  ? 'Updating location…'
                  : search.nearMe
                  ? 'Near me'
                  : 'Use my location',
            ),
          ),
          TextButton.icon(
            onPressed: search.area?.local == true
                ? search.searchThisArea
                : null,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Search this area'),
          ),
        ],
      ),
      if (search.origin == null)
        const Text(
          'Find places near you and sort matching branches by distance.',
        ),
      if (locationMessage != null) Text(locationMessage!),
      if (onOpenSettings != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onOpenSettings,
            child: const Text('Open settings'),
          ),
        ),
    ],
    for (final suggestion in search.interpretation.suggestions)
      TextButton(
        onPressed: () => search.chooseSuggestion(suggestion),
        child: Text('Did you mean $suggestion?'),
      ),
    if (matches.isNotEmpty)
      Text('Saved places', style: context.type.titleSmall),
    for (final place in matches)
      ListTile(
        key: ValueKey('saved-${place.id}'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.bookmark_outline),
        title: Text(place.place.label),
        subtitle: Text(place.place.address ?? 'Saved pin'),
        onTap: () => onSelect(place.intent),
      ),
    if (savedError)
      TextButton(
        onPressed: onRetrySaved,
        child: const Text('Retry loading saved places'),
      ),
    if (search.suggestion != null && search.category == null)
      ListTile(
        leading: const Icon(Icons.category_outlined),
        title: Text(
          'Find ${search.suggestion!.label.toLowerCase()} in this area',
        ),
        onTap: () => search.chooseCategory(search.suggestion!),
      ),
    if (search.needsLocalArea)
      const Text(
        'Zoom into the area you want to search, then search this area.',
      ),
    SizedBox(
      height: 4,
      child: search.loading ? const LinearProgressIndicator() : null,
    ),
    if (search.failed) ...[
      Text(
        search.usesGoogle
            ? 'Google search is unavailable. Choose Other sources or use the map.'
            : search.results.isEmpty
            ? 'Place search is unavailable.'
            : 'Some search sources are unavailable.',
      ),
      if (!search.hasUpdates)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: search.loading ? null : search.retry,
            child: const Text('Retry search'),
          ),
        ),
    ] else if (search.emptySuccess)
      const Text('No matching places found. Try another name or move the map.'),
    if (search.usesGoogle && search.googleMessage != null)
      Text(search.googleMessage!),
  ];

  List<Widget> _fallbackActions() => [
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
  ];

  Widget _googlePanel(
    BuildContext context,
    List<Widget> controls,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      // Let complete controls fit on a normal phone, retaining a 180-unit
      // native viewport. Short panels reserve 45% for native attribution/results.
      final controlsBudget = constraints.maxHeight > 400
          ? constraints.maxHeight - 180
          : constraints.maxHeight * .55;
      return Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: controlsBudget * .65),
            child: SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                key: const PageStorageKey('google-search-controls'),
                primary: false,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: controls,
                ),
              ),
            ),
          ),
          Expanded(
            // Preserve this position through IME/status changes so layout
            // cannot recreate the fragment and rebind a paid request.
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: search.googleSupported
                  ? GoogleSearchView(
                      key: const ValueKey('google-search-host'),
                      search: search,
                      visible: search.usesGoogle,
                    )
                  : const SingleChildScrollView(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Google search is unavailable in this build. Choose Other sources.',
                      ),
                    ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: controlsBudget * .35),
            child: SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                key: const PageStorageKey('google-search-fallback'),
                primary: false,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(children: _fallbackActions()),
              ),
            ),
          ),
        ],
      );
    },
  );
  Widget _otherPanel(List<Widget> rows) => Listener(
    onPointerDown: (_) => search.freezeResults(),
    child: NotificationListener<ScrollStartNotification>(
      onNotification: (_) {
        search.freezeResults();
        return false;
      },
      child: CustomScrollView(
        key: const Key('place-search-results'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => rows[index],
                childCount: rows.length,
                findChildIndexCallback: (key) {
                  final index = rows.indexWhere((w) => w.key == key);
                  return index < 0 ? null : index;
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            sliver: SliverList.list(children: _fallbackActions()),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (search.usesGoogle) _googleMounted = true;
    final matches = saved
        .where(
          (p) =>
              p.place.label.toLowerCase().contains(search.query.toLowerCase()),
        )
        .toList();
    final controls = _controls(context, matches);
    final rows = <Widget>[
      ...controls,
      for (final result in search.results)
        Semantics(
          key: ValueKey('result-${result.sourceId}'),
          onDidGainAccessibilityFocus: search.freezeResults,
          child: InkWell(
            onTap: () => onSelect(
              PlaceIntent(
                kind: PlaceKind.specific,
                label: result.name,
                latitude: result.latitude,
                longitude: result.longitude,
                source: result.sourceId,
                category: result.category,
                address: result.address,
                provider: result.provider,
                retrievedAt: result.retrievedAt?.toIso8601String(),
                attributions: result.attributions,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(result.name, style: context.type.bodyLarge),
                            Text(
                              [
                                result.address ?? 'Address not recorded',
                                ?searchDistanceLabel(
                                  result,
                                  search.visibleOrigin,
                                ),
                              ].join('\n'),
                              style: context.type.bodyMedium?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: context.colors.outlineVariant),
              ],
            ),
          ),
        ),
      SearchAttribution(
        credits: {
          for (final result in search.results) ...result.attributions,
        }.toList(),
      ),
    ];
    if (search.usesGoogle) {
      _googleControls = controls;
    } else {
      _otherContent = KeyedSubtree(
        key: ValueKey(search.contextRevision),
        child: _otherPanel(rows),
      );
    }
    return Material(
      color: context.colors.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeFocus(
              excluding: !search.usesGoogle,
              child: Offstage(
                offstage: !search.usesGoogle,
                child: _googleMounted
                    ? _googlePanel(context, _googleControls)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned.fill(
            child: ExcludeFocus(
              excluding: search.usesGoogle,
              child: Offstage(
                offstage: search.usesGoogle,
                child: _otherContent ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSourceButtons extends StatelessWidget {
  const _SearchSourceButtons({required this.search});
  final PlaceSearchController search;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (search.sourceChoice != null)
        for (final source in SearchSource.values)
          Expanded(
            flex: source == SearchSource.google ? 1 : 2,
            child: Semantics(
              selected: source == search.source,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  foregroundColor: source == search.source
                      ? context.colors.secondary
                      : context.colors.onSurfaceVariant,
                  backgroundColor: Colors.transparent,
                ),
                onPressed: () => search.chooseSource(source),
                child: Text(
                  source == SearchSource.google ? 'Google' : 'Other sources',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: source == search.source
                        ? FontWeight.w700
                        : FontWeight.w500,
                    decoration: source == search.source
                        ? TextDecoration.underline
                        : TextDecoration.none,
                    decorationThickness: 2,
                  ),
                ),
              ),
            ),
          ),
      SizedBox(
        width: 88,
        height: 48,
        child: search.hasUpdates
            ? TextButton(
                key: const Key('updated-search-results'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                onPressed: search.applyUpdates,
                child: const Text('Updates'),
              )
            : search.canRefresh && !search.failed
            ? Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Refresh results',
                  onPressed: search.refreshResults,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              )
            : null,
      ),
    ],
  );
}
