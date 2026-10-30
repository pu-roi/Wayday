import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../today/domain/day.dart';
import '../domain/recommendation.dart';
import 'planning_controller.dart';
import 'plan_map.dart';

/// A paused build retains real choices without pretending it is a valid trip.
class RecommendationRecovery extends StatefulWidget {
  const RecommendationRecovery({
    required this.model,
    required this.onManual,
    super.key,
  });
  final PlanningController model;
  final ValueChanged<Errand> onManual;
  @override
  State<RecommendationRecovery> createState() => _RecommendationRecoveryState();
}

class _RecommendationRecoveryState extends State<RecommendationRecovery> {
  PlanningController get model => widget.model;
  int? focused;
  @override
  Widget build(BuildContext context) {
    final failure = model.recommendationFailure;
    final retryable = failure is RecommendationFailure
        ? failure.retryable
        : !{
            'configuration',
            'access',
            'quota',
            'invalid_request',
            'accounting',
            'no_candidates',
            'candidates_rejected',
            'missing_location',
            'needs_clarification',
          }.contains(failure?.kind);
    final selected = [
      for (final e in model.activeErrands)
        if (model.candidates[e.id]?.isNotEmpty == true)
          (e, model.candidates[e.id]!.first.place),
    ];
    Widget mapView({VoidCallback? refresh}) => PlanMap(
      places: [
        model.day.fromPlace,
        for (final pair in selected) pair.$2,
        model.day.toPlace,
      ],
      labels: [
        'Start',
        for (final pair in selected) model.displayPlace(pair.$2),
        'Destination',
      ],
      geometry: const [],
      selected: focused,
      onSelect: (i) {
        setState(() => focused = i);
        refresh?.call();
      },
    );
    final failed = model.activeErrands
        .where((e) => e.id == model.failedRecommendationErrand)
        .firstOrNull;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              model.error == null
                  ? 'Update your plan'
                  : 'Plan paused',
              style: context.type.titleLarge,
            ),
            const SizedBox(height: 12),
            if (failed != null)
              Text(failed.title, style: context.type.titleMedium),
            Text(
              model.error ??
                  'Place choices changed. Rebuild the trip before continuing.',
            ),
            if (model.recommendationStorageError != null)
              Text(model.recommendationStorageError!),
            const SizedBox(height: 16),
            if (retryable)
              FilledButton(
                onPressed: model.buildRecommendations,
                child: Text(
                  failure == null
                      ? 'Build recommendations'
                      : 'Retry recommendations',
                ),
              ),
            if (selected.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Places kept for this trip',
                style: context.type.titleMedium,
              ),
              const Text('The complete route and timing still need checking.'),
              const SizedBox(height: 12),
              if (MediaQuery.textScalerOf(context).scale(14) <= 21 &&
                  MediaQuery.sizeOf(context).height > 650)
                SizedBox(height: 170, child: mapView())
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Map'),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      useSafeArea: true,
                      builder: (_) => StatefulBuilder(
                        builder: (_, update) => SizedBox(
                          height: MediaQuery.sizeOf(context).height * .6,
                          child: mapView(refresh: () => update(() {})),
                        ),
                      ),
                    ),
                  ),
                ),
              for (var i = 0; i < selected.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(selected[i].$1.title),
                  subtitle: Text(model.displayPlace(selected[i].$2)),
                  selected: focused == i + 1,
                  onTap: () => setState(() => focused = i + 1),
                ),
            ],
            if (model.unresolved.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Still needed', style: context.type.titleMedium),
              for (final e in model.unresolved)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, style: context.type.titleMedium),
                      const Text('No place selected yet'),
                      TextButton(
                        onPressed: () => widget.onManual(e),
                        child: const Text('Search for a place'),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: model.review,
              child: const Text('Review errands'),
            ),
          ],
        ),
      ),
    );
  }
}
