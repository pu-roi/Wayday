import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../maps/data/location_reader.dart';
import '../../places/domain/place_intent.dart';
import '../../today/domain/day.dart';
import '../data/itinerary_repository.dart';
import '../domain/planning_models.dart';
import 'planning_controller.dart';
import 'planning_view.dart';
import 'trip_view.dart';
import 'finish_trip.dart';
export 'trip_view.dart' show TripView;

final savedItineraryProvider = FutureProvider<AcceptedItinerary?>(
  (ref) => ref.watch(itineraryRepositoryProvider).read(),
);

class SavedPlanView extends ConsumerStatefulWidget {
  const SavedPlanView({required this.initial, super.key});
  final AcceptedItinerary initial;
  @override
  ConsumerState<SavedPlanView> createState() => _SavedPlanState();
}

class _SavedPlanState extends ConsumerState<SavedPlanView> {
  late AcceptedItinerary plan = widget.initial;
  bool saving = false;
  String? error;
  Future<void> complete(String id) async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final next = plan.complete(id);
      await ref.read(itineraryRepositoryProvider).updateProgress(next);
      ref.invalidate(savedItineraryProvider);
      if (mounted) setState(() => plan = next);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is PlanningFailure
              ? e.message
              : 'Progress could not be saved. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> start() async {
    final updated = await Navigator.push<TripExit>(
      context,
      MaterialPageRoute(builder: (_) => TripView(initial: plan)),
    );
    if (!mounted || updated == null) return;
    if (updated.finished) {
      Navigator.pop(context);
    } else if (updated.plan != null) {
      setState(() => plan = updated.plan!);
    }
  }

  Future<void> replan() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final location = ref.read(searchLocationProvider);
      if (plan.day.profile == TravelProfile.truck &&
          !plan.lightPickupConfirmed) {
        throw const PlanningFailure(
          'This plan needs explicit light-pickup confirmation before driving guidance.',
        );
      }
      final fix = await location.refresh(requestPermission: true);
      if (fix == null) {
        throw PlanningFailure(
          location.message ?? 'A current location is needed to replan.',
        );
      }
      final now = DateTime.now().toUtc().add(const Duration(hours: 8));
      final remaining = plan.day.errands
          .where((e) => !plan.completed.contains(e.id))
          .map(
            (e) => e.copyWith(
              afterErrandIds: e.afterErrandIds
                  .where((id) => !plan.completed.contains(id))
                  .toList(),
            ),
          )
          .toList();
      if (remaining.isEmpty) {
        throw const PlanningFailure(
          'All planned errands are complete. Start guidance to the final destination.',
        );
      }
      final day = plan.day.copyWith(
        errands: remaining,
        date: calendarDate(now),
        departure: now.hour * 60 + now.minute,
        from: 'Current location',
        fromPlace: PlaceIntent(
          kind: PlaceKind.specific,
          label: 'Current location',
          source: 'device',
          latitude: fix.latitude,
          longitude: fix.longitude,
        ),
      );
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PlanningView(initial: day, history: plan),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is PlanningFailure
              ? e.message
              : 'Replanning could not start. Your saved plan is kept.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Current trip')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${plan.day.date} · ${plan.day.profile == TravelProfile.truck ? 'Light pickup · ordinary driving estimate' : plan.day.profile.label}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Your accepted stops and progress are saved on this phone. Fresh road estimates require another calculation. Check business hours and item availability.',
          ),
          for (var i = 0; i < plan.stops.length; i++) ...[
            const Divider(height: 28),
            Text(
              '${i + 1}. ${plan.stops[i].place.label}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (plan.stops[i].place.isGoogle)
              const Text(
                'Google Maps place reference · refresh if its temporary pin expires',
              ),
            for (final id in plan.stops[i].errandIds)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: plan.completed.contains(id),
                title: Text(
                  plan.day.errands.firstWhere((e) => e.id == id).title,
                ),
                subtitle: Text(
                  plan.completed.contains(id)
                      ? 'Completed'
                      : plan.clarifications[id]?['resolution']?['summary']
                                as String? ??
                            'Mark complete after finishing this errand',
                ),
                onChanged: saving || plan.completed.contains(id)
                    ? null
                    : (_) => complete(id),
              ),
          ],
          const Divider(height: 28),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined),
            title: Text(plan.day.toPlace.label),
            subtitle: const Text('Final destination'),
          ),
          for (final e in plan.deferred.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.pause_circle_outline),
              title: Text(
                '${plan.day.errands.firstWhere((x) => x.id == e.key).title} · Left out',
              ),
              subtitle: Text(e.value),
            ),
          for (final e in plan.omitted.entries)
            Text(
              '${plan.day.errands.firstWhere((x) => x.id == e.key).title}: ${e.value}',
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(error!),
            ),
          const SizedBox(height: 20),
          if (allTripErrandsComplete(plan))
            FinishTripAction(
              plan: plan,
              enabled: !saving,
              onFinished: () => Navigator.pop(context),
            ),
          FilledButton.icon(
            onPressed: saving ? null : start,
            icon: const Icon(Icons.navigation_outlined),
            label: const Text('Start trip in Wayday'),
          ),
          TextButton(
            onPressed: saving ? null : replan,
            child: const Text('Replan unfinished errands from here'),
          ),
        ],
      ),
    ),
  );
}
