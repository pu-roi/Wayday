import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../places/domain/place_intent.dart';
import '../../today/domain/day.dart';
import '../domain/planning_models.dart';
import 'planning_controller.dart';
import 'place_hours.dart';

class PlanStopRow extends StatelessWidget {
  const PlanStopRow({
    required this.model,
    required this.e,
    required this.place,
    required this.index,
    required this.ready,
    required this.busy,
    required this.expanded,
    required this.onChange,
    required this.onSelect,
    required this.onExpand,
    super.key,
  });
  final PlanningController model;
  final Errand e;
  final PlaceIntent? place;
  final int index;
  final bool ready, busy, expanded;
  final VoidCallback onChange, onSelect, onExpand;
  @override
  Widget build(BuildContext context) {
    final place = this.place;
    String clock(int seconds) => TimeOfDay(
      hour: (seconds ~/ 3600) % 24,
      minute: (seconds ~/ 60) % 60,
    ).format(context);
    final plan = model.result;
    final stop = ready
        ? plan!.schedule.stops
              .where((s) => s.tasks.any((t) => t.errandId == e.id))
              .firstOrNull
        : null;
    final leg = stop == null
        ? null
        : plan!.legs.where((l) => l.to == stop.placeKey).firstOrNull;
    final metadata = place == null ? null : model.discovery?.metadata(place);
    final category = metadata?.types.contains('gym') == true
        ? Icons.fitness_center
        : switch (model.effectiveNeed(e)?.category) {
            'grocery' ||
            'marketplace' ||
            'convenience' => Icons.shopping_basket_outlined,
            'food' => Icons.restaurant_outlined,
            'pharmacy' => Icons.local_pharmacy_outlined,
            _ => Icons.location_on_outlined,
          };
    final open = expanded;
    final stackActions = MediaQuery.textScalerOf(context).scale(14) > 21;
    final task = stop?.tasks.where((t) => t.errandId == e.id).firstOrNull;
    final change = TextButton(
      key: ValueKey('change-${e.id}'),
      onPressed: busy ? null : onChange,
      child: const Text('Change'),
    );
    return Material(
      color: model.selectedErrand == e.id
          ? context.colors.secondaryContainer.withValues(alpha: .4)
          : Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    child: Text('${index + 1}', style: context.type.labelSmall),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.title, style: context.type.titleSmall),
                  ),
                  if (!stackActions) change,
                ],
              ),
              if (stackActions)
                Align(alignment: Alignment.centerRight, child: change),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(category, size: 18, color: context.wayday.link),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      place == null
                          ? 'Choose a place'
                          : model.displayPlace(place),
                      style: context.type.bodyLarge,
                    ),
                  ),
                ],
              ),
              if (metadata != null) Text(metadata.locality),
              if (stop != null && task != null)
                Text(
                  'Arrive ${clock(stop.arrival)} · Visit ${e.durationMinutes} min${e.durationConfirmed ? '' : ' estimated'}',
                ),
              if (leg != null)
                Text(
                  'From previous stop: ${(leg.seconds / 60).ceil()} min${leg.meters == null ? '' : ' · ${(leg.meters! / 1000).toStringAsFixed(1)} km'}',
                ),
              if (open) ...[
                if (metadata != null && metadata.address.isNotEmpty)
                  Text(metadata.address),
                if (stop != null)
                  Text('Leave ${clock(stop.departure)} · 5 min buffer'),
                if (task != null && stop != null && task.start > stop.arrival)
                  Text(
                    'Wait ${(task.start - stop.arrival) ~/ 60} min before this errand',
                  ),
                Text(
                  model.candidates[e.id]
                          ?.where(
                            (p) => place != null && p.key == placeKey(place),
                          )
                          .firstOrNull
                          ?.reason ??
                      'Your selected location.',
                ),
                if (plan?.calculatedAt != null && ready)
                  Text(
                    'Calculated ${TimeOfDay.fromDateTime(plan!.calculatedAt!.toLocal()).format(context)}',
                  ),
                if (place != null) PlaceHours(model: model, place: place),
              ],
              TextButton(
                onPressed: onExpand,
                child: Text(open ? 'Less detail' : 'Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
