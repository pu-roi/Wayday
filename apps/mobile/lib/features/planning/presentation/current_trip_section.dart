import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/section_surface.dart';
import '../data/itinerary_repository.dart';
import 'saved_plan_view.dart';

/// Recovery for the active one-time trip, never an implicit reusable template.
class CurrentTripSection extends ConsumerWidget {
  const CurrentTripSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(savedItineraryProvider)
      .when(
        data: (trip) => trip == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: CurrentTripSummary(
                  trip: trip,
                  onResume: () =>
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SavedPlanView(initial: trip),
                        ),
                      ),
                ),
              ),
        loading: () => const SizedBox.shrink(),
        error: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextButton(
            onPressed: () => ref.invalidate(savedItineraryProvider),
            child: const Text('Retry loading current trip'),
          ),
        ),
      );
}

class CurrentTripSummary extends StatelessWidget {
  const CurrentTripSummary({
    required this.trip,
    required this.onResume,
    super.key,
  });
  final AcceptedItinerary trip;
  final VoidCallback onResume;
  @override
  Widget build(BuildContext context) {
    final count = trip.stops.expand((s) => s.errandIds).toSet().length;
    return SectionSurface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.route_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current trip',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${trip.completed.length} of $count errands completed',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            TextButton(onPressed: onResume, child: const Text('Resume trip')),
          ],
        ),
      ),
    );
  }
}
