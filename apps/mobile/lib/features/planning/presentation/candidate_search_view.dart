import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../places/data/combined_place_search.dart';
import '../../places/data/google_pin_cache.dart';
import '../../places/data/google_search.dart';
import '../../places/domain/place_intent.dart';
import '../../places/domain/place_search.dart';
import '../../places/presentation/place_search_controller.dart';
import '../../places/presentation/place_search_panel.dart';
import '../domain/planning_models.dart';

/// Standard visible provider components own candidate presentation/attribution.
/// No background Places catalog or custom replacement Google search cards.
class CandidateSearchView extends ConsumerStatefulWidget {
  const CandidateSearchView({
    required this.query,
    required this.anchor,
    required this.onFound,
    this.reference,
    this.onMap,
    this.limit = 3,
    super.key,
  });
  final String query;
  final PlaceIntent anchor;
  final PlaceIntent? reference;
  final VoidCallback? onMap;
  final int limit;
  final ValueChanged<List<PlanCandidate>> onFound;
  @override
  ConsumerState<CandidateSearchView> createState() => _CandidateSearchState();
}

class _CandidateSearchState extends ConsumerState<CandidateSearchView>
    with WidgetsBindingObserver {
  late final PlaceSearchController search;
  late final TextEditingController text;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    text = TextEditingController(text: widget.query);
    search = PlaceSearchController(
      ref.read(combinedPlaceSearchProvider),
      google: ref.read(googleSearchProvider),
      sourceChoice: SearchSourceChoice(),
      pins: ref.read(googlePinCacheProvider),
    );
    search.open();
    search.onGoogleSelection = (p) => widget.onFound([
      PlanCandidate(key: placeKey(p), place: p, errandIds: {}),
    ]);
    if (widget.anchor.hasCoordinates) {
      search.updateArea(
        SearchArea(widget.anchor.latitude!, widget.anchor.longitude!, 13),
      );
    }
    if (widget.reference != null) {
      search.refreshGoogleReference(widget.reference!);
    } else {
      search.change(widget.query);
      search.submit();
    }
    search.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    search.removeListener(changed);
    final choice = search.sourceChoice;
    search.dispose();
    choice?.dispose();
    text.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      search.suspend();
    }
  }

  Future<void> collect() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final values = <PlanCandidate>[];
      if (search.usesGoogle) {
        if (!search.googleCandidatesCurrent) {
          throw const FormatException('Stale candidate batch');
        }
        final pins = ref.read(googlePinCacheProvider);
        for (final s in search.googleCandidates.take(widget.limit)) {
          await pins.put(s.placeId, s.latitude!, s.longitude!, s.retrievedAt);
          final p = PlaceIntent(
            kind: PlaceKind.providerReference,
            label: search.googleCandidateQuery,
            provider: 'google_ui_kit',
            source: 'google_ui_kit',
            providerPlaceId: s.placeId,
            googlePin: pins.lease(s.placeId),
            attributions: const ['Google Maps'],
          );
          values.add(PlanCandidate(key: placeKey(p), place: p, errandIds: {}));
        }
      } else {
        for (final s
            in search.results.where((s) => !s.street).take(widget.limit)) {
          final p = PlaceIntent(
            kind: PlaceKind.specific,
            label: s.name,
            latitude: s.latitude,
            longitude: s.longitude,
            provider: s.provider,
            source: s.sourceId,
            providerPlaceId: s.osmId ?? s.sourceId,
            address: s.address,
            attributions: s.attributions,
            retrievedAt: s.retrievedAt?.toIso8601String(),
          );
          values.add(PlanCandidate(key: placeKey(p), place: p, errandIds: {}));
        }
      }
      if (!mounted) return;
      if (values.isEmpty) {
        setState(
          () => error =
              'No eligible places yet. Search again or choose a location.',
        );
      } else {
        widget.onFound(values);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'These temporary locations could not be saved. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (widget.reference == null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: TextField(
            controller: text,
            onChanged: search.change,
            onSubmitted: (_) => search.submit(),
            decoration: InputDecoration(
              labelText: 'Find suitable places',
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: search.submit,
                icon: const Icon(Icons.search),
              ),
            ),
          ),
        ),
      Expanded(
        child: PlaceSearchPanel(
          search: search,
          saved: const [],
          onSelect: (p) => widget.onFound([
            PlanCandidate(key: placeKey(p), place: p, errandIds: {}),
          ]),
          onNameOnly: () {
            setState(() => error = 'Choose a place with a map location.');
          },
          onClose: widget.onMap ?? () => Navigator.maybePop(context),
        ),
      ),
      if (error != null)
        Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
      if (widget.reference == null)
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: saving || search.loading ? null : collect,
              child: Text(
                saving
                    ? 'Keeping temporary locations…'
                    : 'Compare these places',
              ),
            ),
          ),
        ),
    ],
  );
}
