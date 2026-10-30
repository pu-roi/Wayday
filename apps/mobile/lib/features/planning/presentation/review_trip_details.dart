import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/section_surface.dart';
import '../../today/domain/day.dart';

/// Review-only presentation; the existing editors own selection and saving.
class ReviewTripDetails extends StatefulWidget {
  const ReviewTripDetails({
    required this.day,
    required this.initiallyExpanded,
    required this.onDate,
    required this.onDeparture,
    required this.onDeadline,
    required this.onFrom,
    required this.onTo,
    this.vehicleConfirmation,
    super.key,
  });

  final DayPlan day;
  final bool initiallyExpanded;
  final VoidCallback onDate, onDeparture, onDeadline, onFrom, onTo;
  final Widget? vehicleConfirmation;

  @override
  State<ReviewTripDetails> createState() => _ReviewTripDetailsState();
}

class _ReviewTripDetailsState extends State<ReviewTripDetails> {
  final controller = ExpansibleController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final date = DateTime.tryParse(day.date);
    final dateLabel = date == null
        ? 'Choose a date'
        : MaterialLocalizations.of(context).formatMediumDate(date);
    final departure = _TripField(
      label: 'Departure',
      value: formatMinute(day.departure),
      onTap: widget.onDeparture,
    );
    final deadline = _TripField(
      label: 'Finish the day by',
      value: formatMinute(day.deadline),
      onTap: widget.onDeadline,
    );
    return SectionSurface(
      child: ExpansionTile(
        key: const PageStorageKey('planning-trip-details'),
        initiallyExpanded: widget.initiallyExpanded,
        controller: controller,
        expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : null,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          'Trip details',
          style: context.type.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Text(
            controller.isExpanded
                ? day.profile.label
                : '$dateLabel · ${day.profile.label}\n${formatMinute(day.departure)} – ${formatMinute(day.deadline)}',
            style: context.type.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        trailing: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (MediaQuery.textScalerOf(context).scale(14) <= 17) ...[
                Text(
                  controller.isExpanded ? 'Hide' : 'Edit',
                  style: context.type.labelLarge?.copyWith(
                    color: context.colors.secondary,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                controller.isExpanded ? Icons.expand_less : Icons.expand_more,
                color: context.colors.secondary,
              ),
            ],
          ),
        ),
        children: [
          _TripField(
            label: 'Date',
            value: date == null ? dateLabel : '$dateLabel, ${date.year}',
            icon: Icons.calendar_today_outlined,
            onTap: widget.onDate,
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= 320 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 17
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: departure),
                      const SizedBox(width: 8),
                      Expanded(child: deadline),
                    ],
                  )
                : Column(
                    children: [departure, const SizedBox(height: 8), deadline],
                  ),
          ),
          const SizedBox(height: 8),
          _TripField(
            label: 'From',
            value: day.fromPlace.label,
            hint: day.fromPlace.hasCoordinates ? null : 'Choose a map location',
            icon: Icons.trip_origin,
            onTap: widget.onFrom,
          ),
          const SizedBox(height: 8),
          _TripField(
            label: 'To',
            value: day.toPlace.label,
            hint: day.toPlace.hasCoordinates ? null : 'Choose a map location',
            icon: Icons.location_on_outlined,
            onTap: widget.onTo,
          ),
          ?widget.vehicleConfirmation,
        ],
      ),
    );
  }
}

class _TripField extends StatelessWidget {
  const _TripField({
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
    this.hint,
  });

  final String label, value;
  final String? hint;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label, $value${hint == null ? '' : ', $hint'}',
    onTapHint: 'Change $label',
    onTap: onTap,
    excludeSemantics: true,
    child: Material(
      color: context.colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: context.colors.onSurfaceVariant),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: context.type.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(value, style: context.type.bodyMedium),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: context.colors.secondary,
                          ),
                        ],
                      ),
                      if (hint != null)
                        Text(
                          hint!,
                          style: context.type.bodySmall?.copyWith(
                            color: context.colors.secondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
