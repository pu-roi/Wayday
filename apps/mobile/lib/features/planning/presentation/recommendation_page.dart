import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../places/domain/place_intent.dart';
import '../../places/presentation/google_place_attribution.dart';
import '../../places/presentation/search_attribution.dart';
import '../../today/domain/day.dart';
import '../domain/planning_models.dart' show placeKey;
import 'planning_controller.dart';
import 'plan_map.dart';
import 'plan_stop_row.dart';

/// Places, schedule and route are one review surface, including partial recovery.
class RecommendationPage extends StatefulWidget {
  const RecommendationPage({
    required this.model,
    required this.onChange,
    required this.onContinue,
    this.onSave,
    this.saving = false,
    this.actionError,
    super.key,
  });
  final PlanningController model;
  final ValueChanged<Errand> onChange;
  final VoidCallback onContinue;
  final VoidCallback? onSave;
  final bool saving;
  final String? actionError;
  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  late final scroll = ScrollController(
    initialScrollOffset: widget.model.recommendationScrollOffset,
  );
  Timer? save;
  bool showMap = true, traffic = false, expandedMap = false;
  final expanded = <String>{};
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

  void select(String id) {
    setState(() => model.selectedErrand = id);
    unawaited(model.saveRecommendationDraft());
  }

  String clock(int seconds) => TimeOfDay(
    hour: (seconds ~/ 3600) % 24,
    minute: (seconds ~/ 60) % 60,
  ).format(context);
  Widget map({bool interactive = false, VoidCallback? refresh}) {
    return ListenableBuilder(
      listenable: model,
      builder: (_, child) {
        final plan = model.result, choices = model.displayChoices;
        final order = [
          if (plan != null)
            for (final stop in plan.schedule.stops)
              for (final task in stop.tasks) task.errandId,
          ...model.activeErrands.map((e) => e.id),
        ];
        final seen = <String>{};
        final located = [
          for (final id in order)
            if (choices[id] != null && seen.add(placeKey(choices[id]!))) id,
        ];
        final ready = model.proposalReady;
        final chosen = choices[model.selectedErrand];
        final selection = chosen == null
            ? -1
            : located.indexWhere(
                (id) => placeKey(choices[id]!) == placeKey(chosen),
              );
        return PlanMap(
          key: ValueKey('plan-map-$interactive'),
          places: [
            model.day.fromPlace,
            for (final id in located) choices[id]!,
            model.day.toPlace,
          ],
          labels: [
            'Start',
            for (final id in located) model.displayPlace(choices[id]!),
            'Destination',
          ],
          geometry: ready ? plan!.geometry : const [],
          interactive: interactive,
          traffic: traffic,
          selected: selection < 0 ? null : selection + 1,
          onSelect: (i) {
            if (i > 0 && i <= located.length) {
              select(located[i - 1]);
              refresh?.call();
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = model.result;
    final choices = model.displayChoices;
    final errands = {for (final e in model.activeErrands) e.id: e};
    final order = plan == null
        ? errands.keys.toList()
        : [
            for (final s in plan.schedule.stops)
              for (final t in s.tasks) t.errandId,
            ...errands.keys.where(
              (id) => !plan.schedule.stops.any(
                (s) => s.tasks.any((t) => t.errandId == id),
              ),
            ),
          ];
    final uniquePlaces = <String>{};
    final located = [
      for (final id in order)
        if (choices[id] != null && uniquePlaces.add(placeKey(choices[id]!))) id,
    ];
    final ready = model.proposalReady;
    final updating =
        model.routeRefreshState == RouteRefreshState.queued ||
        model.routeRefreshState == RouteRefreshState.refreshing;
    final busy =
        model.busy ||
        widget.saving ||
        updating ||
        (model.recommendationSavePending &&
            model.recommendationStorageError == null &&
            model.error == null &&
            model.routeRefreshState != RouteRefreshState.failed);
    final failure = model.recommendationFailure;
    final mayUpdate = !{
      'testing_budget',
      'accounting',
      'access',
      'configuration',
      'quota',
      'unsupported_profile',
    }.contains(failure?.kind);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(20),
                children: [
                  if (ready)
                    Text(
                      'Arrive at destination ${clock(plan!.schedule.endArrival)} · ${(plan.schedule.travelSeconds / 60).ceil()} min road travel',
                    ),
                  if (busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                    Text(
                      updating
                          ? 'Updating route…'
                          : model.recommendationSavePending
                          ? 'Saving your choices…'
                          : model.progress,
                      semanticsLabel: updating
                          ? 'Updating route and schedule'
                          : model.progress,
                    ),
                  ] else if (!ready) ...[
                    const SizedBox(height: 12),
                    Text(
                      model.error == null ? 'Update your plan' : 'Plan paused',
                      style: context.type.titleLarge,
                    ),
                    Text(
                      model.error ??
                          'The route and schedule need checking before starting.',
                    ),
                    const Text(
                      'Your choices are kept. Route and times are not confirmed.',
                    ),
                  ],
                  if (model.orderChanged)
                    const Text(
                      'Stop order updated to fit your selected places.',
                    ),
                  const SizedBox(height: 20),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < order.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          stopRow(
                            errands[order[i]]!,
                            choices[order[i]],
                            choices[order[i]] == null
                                ? i
                                : located.indexWhere(
                                    (id) =>
                                        placeKey(choices[id]!) ==
                                        placeKey(choices[order[i]]!),
                                  ),
                            ready,
                            widget.saving,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Route preview',
                          style: context.type.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => showMap = !showMap),
                        child: Text(showMap ? 'Hide map' : 'Map'),
                      ),
                    ],
                  ),
                  if (showMap && located.isNotEmpty) ...[
                    SizedBox(
                      key: const ValueKey('inline-plan-map'),
                      height: MediaQuery.textScalerOf(context).scale(14) > 21
                          ? 160
                          : 220,
                      child: expandedMap ? const SizedBox.shrink() : map(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.open_in_full),
                        label: const Text('Expand map'),
                        onPressed: () async {
                          setState(() => expandedMap = true);
                          await WidgetsBinding.instance.endOfFrame;
                          if (!context.mounted) return;
                          try {
                            await showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              sheetAnimationStyle:
                                  MediaQuery.disableAnimationsOf(context)
                                  ? AnimationStyle.noAnimation
                                  : null,
                              builder: (_) => StatefulBuilder(
                                builder: (sheetContext, refresh) => SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height * .8,
                                  child: map(
                                    interactive: true,
                                    refresh: () => refresh(() {}),
                                  ),
                                ),
                              ),
                            );
                          } finally {
                            if (mounted) setState(() => expandedMap = false);
                          }
                        },
                      ),
                    ),
                  ],
                  if (model.roads.traffic(model.day.profile))
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Traffic now'),
                      subtitle: const Text(
                        'Current traffic layer; scheduled estimates may differ.',
                      ),
                      value: traffic,
                      onChanged: (v) => setState(() => traffic = v),
                    ),
                  if (ready) ...[
                    for (final warning in plan!.warnings) Text(warning),
                    if (plan.fallback)
                      const Text(
                        'Some road estimates have limited traffic information.',
                      ),
                    if (plan.schedule.timeLimited)
                      const Text(
                        'A feasible plan was found within the calculation limit; other plans may be better.',
                      ),
                    Text(
                      'Final destination: ${model.day.toPlace.label} · Arrive ${clock(plan.schedule.endArrival)} · Home by ${clock(model.day.deadline * 60)}',
                    ),
                  ],
                  if (model.day.profile == TravelProfile.truck)
                    const Text(
                      'Light pickup · ordinary driving estimate. Truck restrictions and clearance are not verified.',
                    ),
                  const Text(
                    'Visit estimates include a five-minute buffer after each stop.',
                  ),
                  for (final e in model.deferred.entries)
                    Text(
                      '${model.reviewInput(model.day.errands.firstWhere((x) => x.id == e.key)).title} · Left out: ${e.value}',
                    ),
                  for (final e
                      in plan?.schedule.omitted.entries ??
                          <MapEntry<String, String>>[])
                    Text(
                      '${errands[e.key]?.title ?? e.key} · Not included: ${e.value}',
                    ),
                  if (choices.values.any((p) => p.isGoogle))
                    GooglePlaceAttribution(
                      showGoogleMaps: true,
                      credits: [
                        for (final p in choices.values)
                          ...?model.discovery?.metadata(p)?.attributions,
                      ],
                    ),
                  SearchAttribution(
                    credits: [
                      for (final p in choices.values.where((p) => !p.isGoogle))
                        ...p.attributions,
                    ],
                  ),
                  if (model.recommendationStorageError != null) ...[
                    Text(model.recommendationStorageError!),
                    TextButton(
                      onPressed: model.saveRecommendationDraft,
                      child: const Text('Retry saving choices'),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.actionError != null)
                    Text(
                      widget.actionError!,
                      semanticsLabel: widget.actionError,
                    ),
                  FilledButton(
                    onPressed: busy || model.recommendationStorageError != null
                        ? null
                        : ready
                        ? widget.onContinue
                        : mayUpdate
                        ? model.retryRouteRefresh
                        : null,
                    child: Text(
                      busy
                          ? 'Updating route…'
                          : ready
                          ? 'Start trip'
                          : 'Retry route update',
                    ),
                  ),
                  TextButton(
                    onPressed: busy || !model.canSaveReusable
                        ? null
                        : widget.onSave,
                    child: const Text('Save for reuse'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget stopRow(
    Errand e,
    PlaceIntent? place,
    int index,
    bool ready,
    bool busy,
  ) => PlanStopRow(
    model: model,
    e: e,
    place: place,
    index: index,
    ready: ready,
    busy: busy,
    expanded: expanded.contains(e.id),
    onChange: () => widget.onChange(e),
    onSelect: () => select(e.id),
    onExpand: () {
      select(e.id);
      setState(() {
        if (!expanded.add(e.id)) expanded.remove(e.id);
      });
    },
  );
}
