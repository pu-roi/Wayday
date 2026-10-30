import 'package:flutter/material.dart';
import '../../../core/widgets/place_picker.dart';
import '../../places/domain/place_intent.dart';
import '../../places/presentation/search_attribution.dart';
import '../../places/presentation/google_place_attribution.dart';
import '../domain/planning_models.dart';
import '../domain/errand_location_review.dart';
import 'planning_controller.dart';

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
  bool loading = false;
  String? error;
  int revision = 0;
  final loaded = <String, List<PlanCandidate>>{};
  PlanningController get model => widget.model;
  bool get canDiscover {
    final errand = model.activeErrands.firstWhere((e) => e.id == id);
    return needsPlaceRecommendation(errand, model.effectiveNeed(errand));
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool discover = false}) async {
    final epoch = ++revision, current = id;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final saved = loaded[current] ?? model.candidates[current] ?? [];
      if (!discover || !canDiscover || model.discovery == null) {
        loaded[current] = saved;
      } else {
        // An explicit alternatives search is bounded to two nearby route anchors.
        final stops = model.result?.schedule.stops ?? [];
        final index = stops.indexWhere(
          (s) => s.tasks.any((t) => t.errandId == current),
        );
        final points = {for (final p in model.points) p.key: p.place};
        loaded[current] = await model.discovery!.discover(
          model.effectiveNeed(
            model.activeErrands.firstWhere((e) => e.id == current),
          )!,
          polyline: null,
          anchors: [
            index > 0
                ? points[stops[index - 1].placeKey]!
                : model.day.fromPlace,
            index >= 0 && index < stops.length - 1
                ? points[stops[index + 1].placeKey]!
                : model.day.toPlace,
          ],
          limit: 3,
          cancelled: () => !mounted || epoch != revision,
        );
      }
    } catch (e) {
      if (mounted && epoch == revision) error = e.toString();
    }
    if (mounted && epoch == revision) setState(() => loading = false);
  }

  Future<void> manual() async {
    final errand = model.activeErrands.firstWhere((e) => e.id == id);
    final place = await choosePlace(
      context,
      title: 'Choose place',
      initial: errand.title,
      forPlanning: true,
    );
    if (!mounted || place == null) return;
    if (!place.hasCoordinates) {
      setState(() => error = 'Choose a place with a map location.');
      return;
    }
    try {
      if (place.isGoogle) await model.discovery?.hydrate(place);
      if (mounted) Navigator.pop(context, AlternativeChoice(id, place));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  String comparison(PlanCandidate candidate) {
    final stops = model.result?.schedule.stops ?? [];
    final index = stops.indexWhere((s) => s.tasks.any((t) => t.errandId == id));
    if (index < 0) return 'Road estimates will be checked after selection';
    final before = index == 0 ? '@start' : stops[index - 1].placeKey;
    final after = index == stops.length - 1
        ? '@end'
        : stops[index + 1].placeKey;
    final detour = model.detourFor(candidate.key, before, after);
    return detour == null
        ? 'Road estimates will be checked after selection'
        : '${(detour.abs() / 60).ceil()} min ${detour < 0 ? 'less' : 'extra'} travel · approximate';
  }

  @override
  Widget build(BuildContext context) {
    final errands = model.activeErrands,
        index = errands.indexWhere((e) => e.id == id);
    final values = loaded[id] ?? model.candidates[id] ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a place')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous errand',
                        onPressed: index > 0
                            ? () {
                                setState(() => id = errands[index - 1].id);
                                load();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          '${index + 1} of ${errands.length} · ${errands[index].title}',
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next errand',
                        onPressed: index < errands.length - 1
                            ? () {
                                setState(() => id = errands[index + 1].id);
                                load();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                if (loading) const LinearProgressIndicator(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      for (final candidate in values)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(model.displayPlace(candidate.place)),
                          subtitle: Text(
                            [
                              model.discovery
                                      ?.metadata(candidate.place)
                                      ?.locality ??
                                  candidate.reason,
                              comparison(candidate),
                            ].where((s) => s.isNotEmpty).join('\n'),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: loading
                              ? null
                              : () => Navigator.pop(
                                  context,
                                  AlternativeChoice(id, candidate.place),
                                ),
                        ),
                      if (!loading && values.isEmpty)
                        const Text(
                          'No suitable alternatives yet. Search for a specific place or choose on the map.',
                        ),
                      if (error != null) Text(error!),
                      if (values.any((p) => p.place.isGoogle))
                        GooglePlaceAttribution(
                          showGoogleMaps: false,
                          credits: [
                            for (final p in values.where(
                              (p) => p.place.isGoogle,
                            ))
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
                      if (canDiscover)
                        TextButton(
                          onPressed: loading
                              ? null
                              : () => load(discover: true),
                          child: const Text('Find more along this trip'),
                        ),
                    ],
                  ),
                ),
                if (values.any((p) => p.place.isGoogle))
                  const GoogleMapsAttributionLabel(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : manual,
                      icon: const Icon(Icons.search),
                      label: const Text('Search for a place'),
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
