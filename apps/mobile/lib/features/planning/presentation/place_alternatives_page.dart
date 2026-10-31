import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/place_picker.dart';
import '../../places/domain/place_intent.dart';
import '../../places/presentation/search_attribution.dart';
import '../../places/presentation/google_place_attribution.dart';
import '../domain/planning_models.dart';
import '../domain/recommendation.dart';
import '../domain/errand_location_review.dart';
import 'planning_controller.dart';
import 'place_hours.dart';

class AlternativeChoice {
  const AlternativeChoice(this.errandId, this.place);
  final String errandId;
  final PlaceIntent place;
}

class PlaceAlternativesPage extends StatefulWidget {
  const PlaceAlternativesPage({
    required this.model,
    required this.errandId,
    super.key,
  });
  final PlanningController model;
  final String errandId;
  @override
  State<PlaceAlternativesPage> createState() => _PlaceAlternativesPageState();
}

class _PlaceAlternativesPageState extends State<PlaceAlternativesPage> {
  late String id = widget.errandId;
  final scrolls = <String, ScrollController>{};
  bool manualBusy = false;
  String? manualError;
  PlanningController get model => widget.model;
  ScrollController get scroll => scrolls.putIfAbsent(
    id,
    () => ScrollController(
      initialScrollOffset: model.alternativesFor(id).scrollOffset,
    ),
  );
  @override
  void initState() {
    super.initState();
    model.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    model.removeListener(changed);
    for (final s in scrolls.values) {
      s.dispose();
    }
    super.dispose();
  }

  void page(String next) {
    if (scroll.hasClients) {
      model.alternativesFor(id).scrollOffset = scroll.offset;
    }
    setState(() {
      id = next;
      manualError = null;
    });
  }

  Future<void> manual() async {
    final current = id,
        errand = model.activeErrands.firstWhere((e) => e.id == id);
    setState(() {
      manualBusy = true;
      manualError = null;
    });
    try {
      final place = await choosePlace(
        context,
        title: 'Choose place',
        initial: errand.title,
        forPlanning: true,
      );
      if (!mounted || place == null) return;
      if (!place.hasCoordinates) {
        throw const PlanningFailure('Choose a place with a map location.');
      }
      if (place.isGoogle) await model.discovery?.hydrate(place);
      if (mounted) Navigator.pop(context, AlternativeChoice(current, place));
    } catch (e) {
      if (mounted) {
        setState(
          () => manualError = e is PlanningFailure
              ? e.message
              : 'This place could not be selected. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => manualBusy = false);
    }
  }

  String? comparison(PlanCandidate candidate) {
    if (!model.proposalReady) return null;
    final stops = model.result!.schedule.stops;
    final index = stops.indexWhere((s) => s.tasks.any((t) => t.errandId == id));
    if (index < 0) return null;
    final before = index == 0 ? '@start' : stops[index - 1].placeKey;
    final after = index == stops.length - 1
        ? '@end'
        : stops[index + 1].placeKey;
    final current = model.displayChoices[id];
    final value = model.detourFor(candidate.key, before, after);
    final baseline = current == null
        ? null
        : model.detourFor(placeKey(current), before, after);
    if (value == null || baseline == null) return null;
    final delta = value - baseline;
    return delta == 0
        ? 'Similar road travel · approximate'
        : 'About ${(delta.abs() / 60).ceil()} min ${delta < 0 ? 'less' : 'more'} travel than current · approximate';
  }

  @override
  Widget build(BuildContext context) {
    final errands = model.activeErrands,
        index = errands.indexWhere((e) => e.id == id);
    final state = model.alternativesFor(id),
        values = state.values
            .where((p) => model.alternativeHasWindow(id, p))
            .toList();
    final current = model.displayChoices[id];
    final flexible = needsPlaceRecommendation(
      errands[index],
      model.effectiveNeed(errands[index]),
    );
    final browse = flexible && model.discovery is AlternativeDiscovery;
    final height =
        (MediaQuery.sizeOf(context).height -
            MediaQuery.paddingOf(context).vertical -
            MediaQuery.viewInsetsOf(context).bottom) *
        .9;
    return Material(
      color: context.colors.surface,
      child: SafeArea(
        top: false,
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 560, maxHeight: height),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Choose a place',
                          style: context.type.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close place alternatives',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous errand',
                        onPressed: !manualBusy && index > 0
                            ? () => page(errands[index - 1].id)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          'Errand ${index + 1} of ${errands.length} · ${errands[index].title}',
                          style: context.type.bodyMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next errand',
                        onPressed: !manualBusy && index < errands.length - 1
                            ? () => page(errands[index + 1].id)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      state.scrollOffset = notification.metrics.pixels;
                      return false;
                    },
                    child: ListView(
                      key: PageStorageKey('alternatives-$id'),
                      controller: scroll,
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      children: [
                        if (values.any((p) => comparison(p) == null))
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'The route and schedule update after you choose a different place.',
                            ),
                          ),
                        for (final candidate in values) ...[
                          Semantics(
                            selected:
                                current != null &&
                                placeKey(current) == candidate.key,
                            child: ListTile(
                              key: ValueKey('alternative-${candidate.key}'),
                              contentPadding: EdgeInsets.zero,
                              title: Text(model.displayPlace(candidate.place)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    [
                                      if (current != null &&
                                          placeKey(current) == candidate.key)
                                        'Current place',
                                      model.discovery
                                              ?.metadata(candidate.place)
                                              ?.locality ??
                                          '',
                                      if (comparison(candidate) != null)
                                        comparison(candidate)!,
                                    ].where((s) => s.isNotEmpty).join(' · '),
                                  ),
                                  PlaceHours(
                                    model: model,
                                    place: candidate.place,
                                    compact: true,
                                  ),
                                ],
                              ),
                              trailing:
                                  current != null &&
                                      placeKey(current) == candidate.key
                                  ? Icon(
                                      Icons.check_circle_outline,
                                      color: context.wayday.link,
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: manualBusy
                                  ? null
                                  : () => Navigator.pop(
                                      context,
                                      AlternativeChoice(id, candidate.place),
                                    ),
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                        if (values.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No suggestions yet. You can choose a specific place.',
                            ),
                          ),
                        if (state.loading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(
                              semanticsLabel: 'Loading more suggestions',
                            ),
                          ),
                        if (state.error != null)
                          Text(state.error!, semanticsLabel: state.error),
                        if (browse && !state.exhausted && values.length < 12)
                          TextButton.icon(
                            onPressed: state.loading || manualBusy
                                ? null
                                : () => model.showMoreAlternatives(id),
                            icon: const Icon(Icons.expand_more),
                            label: Text(
                              state.error == null
                                  ? 'Show more suggestions'
                                  : 'Retry loading suggestions',
                            ),
                          ),
                        if (browse && (state.exhausted || values.length >= 12))
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No more suggestions from these searches',
                            ),
                          ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: manualBusy ? null : manual,
                          icon: const Icon(Icons.search),
                          label: const Text('Choose a specific place'),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 8, bottom: 12),
                          child: Text(
                            'Search by name or address, use a saved place, or choose on the map.',
                          ),
                        ),
                        if (manualBusy)
                          const LinearProgressIndicator(
                            semanticsLabel: 'Checking your selected place',
                          ),
                        if (manualError != null) Text(manualError!),
                        if (values.any((p) => p.place.isGoogle))
                          GooglePlaceAttribution(
                            showGoogleMaps: true,
                            credits: [
                              for (final p in values)
                                ...?model.discovery
                                    ?.metadata(p.place)
                                    ?.attributions,
                            ],
                          ),
                        SearchAttribution(
                          credits: [
                            for (final p in values.where(
                              (p) => !p.place.isGoogle,
                            ))
                              ...p.place.attributions,
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
