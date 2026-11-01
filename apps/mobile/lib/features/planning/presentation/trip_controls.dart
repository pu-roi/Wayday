import 'package:flutter/material.dart';
import 'trip_session.dart';
import 'finish_trip.dart';

class TripChecklist extends StatelessWidget {
  const TripChecklist({required this.model, required this.onFinish, super.key});
  final TripSession model;
  final VoidCallback onFinish;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    key: const ValueKey('trip-checklist'),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.orientationOf(context) == Orientation.landscape
          ? MediaQuery.sizeOf(context).height
          : MediaQuery.sizeOf(context).height * .32,
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            model.currentErrandId == null
                ? model.current.finalDestination
                      ? 'Final destination'
                      : 'This stop is complete'
                : model.arrived
                ? 'You have arrived. Mark this errand when done'
                : 'Mark this errand when done',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final id in [
            if (model.currentErrandId != null) model.currentErrandId!,
          ])
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: model.plan.completed.contains(id),
                title: Text(
                  model.plan.day.errands.firstWhere((e) => e.id == id).title,
                ),
                onChanged:
                    model.busy ||
                        !model.active ||
                        model.plan.completed.contains(id)
                    ? null
                    : (_) => model.complete(id),
              ),
            ),
          if (model.current.finalDestination &&
              model.currentErrands.every(model.plan.completed.contains)) ...[
            Text(
              model.plan.day.toPlace.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            FinishTripAction(
              plan: model.plan,
              enabled: !model.busy,
              onFinished: onFinish,
            ),
          ],
        ],
      ),
    ),
  );
}

class TripStatus extends StatelessWidget {
  const TripStatus({required this.model, required this.onResume, super.key});
  final TripSession model;
  final VoidCallback onResume;
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
          if (!model.busy && !model.active)
            TextButton(
              onPressed: onResume,
              child: const Text('Resume guidance'),
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
