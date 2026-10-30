import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../places/presentation/search_attribution.dart';
import '../../places/presentation/google_place_attribution.dart';
import '../../today/domain/day.dart';
import 'planning_controller.dart';
import 'plan_map.dart';

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({
    required this.model,
    required this.onChange,
    required this.onContinue,
    super.key,
  });
  final PlanningController model;
  final ValueChanged<Errand> onChange;
  final VoidCallback onContinue;
  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  late final scroll = ScrollController(
    initialScrollOffset: widget.model.recommendationScrollOffset,
  );
  Timer? save;
  bool showMap = true, traffic = false;
  bool expandCompactMap = false;
  final rowKeys = <String, GlobalKey>{};
  PlanningController get model => widget.model;
  @override
  void initState() {
    super.initState();
    scroll.addListener(storePosition);
  }

  void storePosition() {
    model.recommendationScrollOffset = scroll.offset.clamp(0, 1000000);
    save?.cancel();
    save = Timer(
      const Duration(milliseconds: 350),
      model.saveRecommendationDraft,
    );
  }

  @override
  void dispose() {
    save?.cancel();
    scroll.dispose();
    super.dispose();
  }

  void select(String id, {bool reveal = false}) {
    setState(() => model.selectedErrand = id);
    unawaited(model.saveRecommendationDraft());
    final target = rowKeys[id]?.currentContext;
    if (reveal && target != null) {
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = model.result!;
    final stops = plan.schedule.stops;
    final places = {for (final p in model.points) p.key: p};
    final items = {for (final e in model.reviewOrder.items) e.id: e};
    final selected = stops.indexWhere(
      (s) => s.tasks.any((t) => t.errandId == model.selectedErrand),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxHeight < 520 ||
                MediaQuery.textScalerOf(context).scale(14) > 21;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${stops.length} ${stops.length == 1 ? 'stop' : 'stops'} · ${(plan.schedule.travelSeconds / 60).ceil()} min travel',
                          style: context.type.bodyMedium,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          if (compact) {
                            expandCompactMap = !expandCompactMap;
                          } else {
                            showMap = !showMap;
                          }
                        }),
                        icon: const Icon(Icons.map_outlined),
                        label: Text(
                          showMap && (!compact || expandCompactMap)
                              ? 'Hide map'
                              : 'Map',
                        ),
                      ),
                    ],
                  ),
                ),
                if (showMap && (!compact || expandCompactMap))
                  SizedBox(
                    height: compact
                        ? 155
                        : (constraints.maxHeight * .29).clamp(170, 240),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: PlanMap(
                            key: ValueKey(plan.calculatedAt ?? plan),
                            places: [
                              model.day.fromPlace,
                              for (final s in stops) places[s.placeKey]!.place,
                              model.day.toPlace,
                            ],
                            labels: [
                              'Start',
                              for (final s in stops)
                                model.displayPlace(places[s.placeKey]!.place),
                              'Destination',
                            ],
                            geometry: plan.geometry,
                            selected: selected < 0 ? null : selected + 1,
                            traffic: traffic,
                            onSelect: (i) {
                              if (i > 0 && i <= stops.length) {
                                select(
                                  stops[i - 1].tasks.first.errandId,
                                  reveal: true,
                                );
                              }
                            },
                          ),
                        ),
                        if (model.roads.traffic(model.day.profile))
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(18),
                              child: TextButton.icon(
                                onPressed: () =>
                                    setState(() => traffic = !traffic),
                                icon: Icon(
                                  traffic
                                      ? Icons.traffic
                                      : Icons.traffic_outlined,
                                ),
                                label: Text(
                                  traffic ? 'Traffic now: on' : 'Traffic now',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    children: [
                      for (var i = 0; i < stops.length; i++) ...[
                        for (final task in stops[i].tasks)
                          Builder(
                            builder: (context) {
                              final stop = stops[i],
                                  e = items[task.errandId]!,
                                  place = places[stop.placeKey]!.place;
                              final metadata = model.discovery?.metadata(place);
                              final before = i == 0
                                  ? '@start'
                                  : stops[i - 1].placeKey;
                              final after = i == stops.length - 1
                                  ? '@end'
                                  : stops[i + 1].placeKey;
                              final legs = plan.legs.where(
                                (leg) =>
                                    leg.from == before &&
                                    leg.to == stop.placeKey,
                              );
                              final leg = legs.isEmpty ? null : legs.first;
                              final detour = model.detourFor(
                                stop.placeKey,
                                before,
                                after,
                              );
                              final expanded = e.id == model.selectedErrand;
                              final category =
                                  metadata?.types.join(' ') ??
                                  model.effectiveNeed(e)?.category ??
                                  '';
                              final icon =
                                  category.contains('gym') ||
                                      category.contains('fitness')
                                  ? Icons.fitness_center
                                  : category.contains('cafe') ||
                                        category.contains('coffee')
                                  ? Icons.local_cafe_outlined
                                  : category.contains('laundry')
                                  ? Icons.local_laundry_service_outlined
                                  : category.contains('grocery') ||
                                        category.contains('supermarket')
                                  ? Icons.shopping_basket_outlined
                                  : Icons.place_outlined;
                              return Column(
                                key: rowKeys.putIfAbsent(e.id, GlobalKey.new),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    selected: expanded,
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor:
                                          context.colors.secondaryContainer,
                                      child: Text(
                                        '${i + 1}',
                                        style: context.type.labelMedium,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Icon(
                                          icon,
                                          size: 16,
                                          color: context.colors.secondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            e.title,
                                            style: context.type.titleSmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          model.displayPlace(place),
                                          style: context.type.bodyLarge,
                                        ),
                                        if (metadata?.locality.isNotEmpty ==
                                            true)
                                          Text(metadata!.locality),
                                        Text(
                                          leg == null
                                              ? 'Travel estimate unavailable'
                                              : '${(leg.seconds / 60).ceil()} min${leg.meters == null ? '' : ' · ${(leg.meters! / 1000).toStringAsFixed(1)} km'} from ${i == 0 ? 'start' : 'stop $i'}',
                                        ),
                                        if (places[stop.placeKey]!
                                            .reason
                                            .isNotEmpty)
                                          Text(
                                            places[stop.placeKey]!.reason,
                                            style: context.type.bodySmall,
                                          ),
                                      ],
                                    ),
                                    trailing: Icon(
                                      expanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: context.colors.secondary,
                                    ),
                                    onTap: () => select(e.id),
                                  ),
                                  if (expanded)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 42,
                                        bottom: 8,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (metadata?.address.isNotEmpty ==
                                              true)
                                            Text(metadata!.address),
                                          if (metadata?.types.isNotEmpty ==
                                              true)
                                            Text(
                                              metadata!.types.first.replaceAll(
                                                '_',
                                                ' ',
                                              ),
                                            ),
                                          if (stop.tasks.length > 1)
                                            const Text(
                                              'Shared visit · errands remain separate',
                                            ),
                                          if (detour != null)
                                            Text(
                                              '${(detour.abs() / 60).ceil()} min ${detour < 0 ? 'less' : 'extra'} travel · approximate',
                                            ),
                                          const Text(
                                            'Opening hours and availability unconfirmed',
                                          ),
                                          if (plan.calculatedAt != null)
                                            Text(
                                              'Calculated ${TimeOfDay.fromDateTime(plan.calculatedAt!.toLocal()).format(context)}',
                                            ),
                                          TextButton(
                                            onPressed: () => widget.onChange(e),
                                            child: const Text('Change place'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Divider(
                                    height: 1,
                                    color: context.colors.outlineVariant,
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                      if (plan.fallback)
                        const Text(
                          'Some road estimates have limited traffic data.',
                        ),
                      if (plan.schedule.omitted.isNotEmpty)
                        Text(
                          'Not included: ${plan.schedule.omitted.keys.map((id) => items[id]?.title ?? id).join(', ')}',
                        ),
                      for (final entry in model.deferred.entries)
                        Text(
                          '${items[entry.key]?.title ?? entry.key}: ${entry.value}',
                        ),
                      if (places.values.any((p) => p.place.isGoogle))
                        GooglePlaceAttribution(
                          showGoogleMaps: false,
                          credits: [
                            for (final p in places.values.where(
                              (p) => p.place.isGoogle,
                            ))
                              ...?model.discovery
                                  ?.metadata(p.place)
                                  ?.attributions,
                          ],
                        ),
                      SearchAttribution(
                        credits: [
                          for (final p in places.values.where(
                            (p) => !p.place.isGoogle,
                          ))
                            ...p.place.attributions,
                        ],
                      ),
                      if (model.recommendationStorageError != null) ...[
                        Text(model.recommendationStorageError!),
                        TextButton(
                          onPressed: () async {
                            await model.saveRecommendationDraft();
                            if (mounted) setState(() {});
                          },
                          child: const Text('Retry saving choices'),
                        ),
                      ],
                    ],
                  ),
                ),
                if (places.values.any((p) => p.place.isGoogle))
                  const GoogleMapsAttributionLabel(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: model.recommendationStorageError == null
                          ? widget.onContinue
                          : null,
                      child: const Text('Next: see my day'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
