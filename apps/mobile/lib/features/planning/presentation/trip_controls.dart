import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import 'trip_session.dart';
import 'finish_trip.dart';

class TripChecklist extends StatelessWidget {
  const TripChecklist({required this.model, required this.onFinish, super.key});
  final TripSession model;
  final VoidCallback onFinish;
  @override
  Widget build(BuildContext context) {
    final id = model.currentErrandId;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.outlineVariant)),
      ),
      child: ConstrainedBox(
        key: const ValueKey('trip-checklist'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .32,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (id != null)
                _CurrentErrand(model: model, id: id)
              else
                Text(
                  model.current.finalDestination
                      ? 'Final destination'
                      : 'This stop is complete',
                  style: context.type.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              if (model.current.finalDestination &&
                  model.currentErrands.every(
                    model.plan.completed.contains,
                  )) ...[
                const SizedBox(height: 8),
                Text(
                  model.plan.day.toPlace.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                FinishTripAction(
                  plan: model.plan,
                  enabled: !model.busy,
                  onFinished: onFinish,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentErrand extends StatelessWidget {
  const _CurrentErrand({required this.model, required this.id});
  final TripSession model;
  final String id;

  @override
  Widget build(BuildContext context) {
    final title = model.plan.day.errands.firstWhere((e) => e.id == id).title;
    final heading = Semantics(
      liveRegion: true,
      child: Text(title, style: context.type.titleLarge),
    );
    final done = FilledButton.icon(
      onPressed: model.busy || !model.active ? null : () => model.complete(id),
      icon: const Icon(Icons.check, size: 20),
      label: Text(
        model.saving ? 'Saving…' : 'Done',
        semanticsLabel: model.saving
            ? 'Saving completion for $title'
            : 'Mark $title as done',
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          model.arrived ? 'You have arrived' : 'Current errand',
          style: context.type.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 320 ||
                MediaQuery.textScalerOf(context).scale(14) > 18) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading,
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: done),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: heading),
                const SizedBox(width: 16),
                done,
              ],
            );
          },
        ),
      ],
    );
  }
}

class TripStatus extends StatelessWidget {
  const TripStatus({
    required this.model,
    required this.onResume,
    this.onProviders,
    super.key,
  });
  final TripSession model;
  final VoidCallback onResume;
  final VoidCallback? onProviders;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .22,
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              (model.switching
                      ? 'Preparing your selected map and navigation…'
                      : null) ??
                  model.error ??
                  (model.gpsLost
                      ? 'Searching for GPS. Your position is uncertain; the route is kept.'
                      : switch (model.stage) {
                          TripStage.terms => 'Preparing navigation…',
                          TripStage.location =>
                            'Finding your navigation location…',
                          TripStage.map => 'Opening navigation map…',
                          TripStage.route => 'Loading your remaining route…',
                          _ => 'Guidance is paused. Your progress is saved.',
                        }),
            ),
          ),
          if (model.busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (!model.busy && (!model.active || model.placeDetailsUnavailable))
            TextButton(
              onPressed: onResume,
              child: Text(
                model.active ? 'Retry place details' : 'Resume guidance',
              ),
            ),
          if (!model.busy && model.error != null && onProviders != null)
            TextButton(
              onPressed: onProviders,
              child: const Text('Map & navigation'),
            ),
        ],
      ),
    ),
  );
}

Future<void> showNavigationInfo(
  BuildContext context,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Navigation info',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Arrival does not complete errands. Mark the current errand when done to see the next one. If another errand is at the same place, finish it there before guidance advances.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Traffic rerouting updates navigation. It does not recheck your whole schedule, appointments or business hours. Navigation travel estimates do not include time spent doing errands.',
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  ),
);
