import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;
import '../../maps/data/location_reader.dart';
import '../../places/domain/place_intent.dart';
import '../../today/domain/day.dart';
import '../data/itinerary_repository.dart';
import '../data/trip_navigation.dart';
import '../domain/planning_models.dart';
import 'planning_controller.dart';
import 'planning_view.dart';

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
      await ref.read(itineraryRepositoryProvider).save(next);
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
    final updated = await Navigator.push<AcceptedItinerary>(
      context,
      MaterialPageRoute(builder: (_) => TripView(initial: plan)),
    );
    if (updated != null && mounted) setState(() => plan = updated);
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
    appBar: AppBar(title: const Text('Your plan')),
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

class TripView extends ConsumerStatefulWidget {
  const TripView({required this.initial, super.key});
  final AcceptedItinerary initial;
  @override
  ConsumerState<TripView> createState() => _TripState();
}

class _TripState extends ConsumerState<TripView> with WidgetsBindingObserver {
  late AcceptedItinerary plan = widget.initial;
  late final navigation = TripNavigation(ref.read(planningBudgetProvider));
  bool active = false, busy = false, closing = false;
  int epoch = 0;
  String? error;
  ItineraryStop? get next => plan.stops
      .where((s) => s.errandIds.any((id) => !plan.completed.contains(id)))
      .firstOrNull;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => resume());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    epoch++;
    unawaited(navigation.stop().catchError((Object _) {}));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      epoch++;
      active = false;
      unawaited(navigation.stop().catchError((Object _) {}));
    }
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  Future<void> resume() async {
    if (busy || closing) return;
    final request = ++epoch;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (plan.day.profile == TravelProfile.truck &&
          !plan.lightPickupConfirmed) {
        throw const PlanningFailure(
          'Confirm a compatible light pickup before starting ordinary driving guidance.',
        );
      }
      final location = ref.read(searchLocationProvider);
      if (await location.refresh(requestPermission: true) == null) {
        throw PlanningFailure(
          location.message ?? 'Location access is needed for guidance.',
        );
      }
      if (!mounted || request != epoch) return;
      await navigation.initialize();
      if (!mounted || request != epoch) {
        await navigation.stop();
        return;
      }
      await navigation.guide(next?.place ?? plan.day.toPlace, plan.day.profile);
      if (!mounted || request != epoch) {
        await navigation.stop();
        return;
      }
      setState(() => active = true);
    } catch (e) {
      await navigation.stop().catchError((Object _) {});
      if (mounted && request == epoch) {
        setState(
          () => error = e is PlanningFailure
              ? e.message
              : 'Embedded guidance could not start. Check Google navigation access and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> done(String id) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final before = next;
      final updated = plan.complete(id);
      await ref.read(itineraryRepositoryProvider).save(updated);
      ref.invalidate(savedItineraryProvider);
      if (!mounted) return;
      setState(() => plan = updated);
      if (active && before != next) {
        await navigation.guide(
          next?.place ?? plan.day.toPlace,
          plan.day.profile,
        );
      }
    } catch (e) {
      await navigation.stop().catchError((Object _) {});
      if (mounted) setState(() => active = false);
      if (mounted) {
        setState(
          () => error = e is PlanningFailure
              ? e.message
              : 'Progress or the next route could not be updated. Check your saved plan.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> exit() async {
    closing = true;
    epoch++;
    await navigation.stop().catchError((Object _) {});
    if (mounted) Navigator.pop(context, plan);
  }

  @override
  Widget build(BuildContext context) {
    final stop = next;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) exit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your trip'),
          leading: IconButton(
            tooltip: 'Stop guidance',
            onPressed: exit,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: active
                    ? nav.GoogleMapsNavigationView(
                        onViewCreated: (_) {},
                        initialMapColorScheme: nav.MapColorScheme.light,
                        initialMapToolbarEnabled: false,
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (busy) const CircularProgressIndicator(),
                              if (error != null) Text(error!),
                              if (!busy)
                                FilledButton(
                                  onPressed: resume,
                                  child: const Text('Resume guidance'),
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .4,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop?.place.label ?? plan.day.toPlace.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text(
                        'Arrival does not complete errands. Mark each one when done. Traffic rerouting does not recheck your whole schedule.',
                      ),
                      if (active && error != null) Text(error!),
                      if (stop != null)
                        for (final id in stop.errandIds)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: plan.completed.contains(id),
                            title: Text(
                              plan.day.errands
                                  .firstWhere((e) => e.id == id)
                                  .title,
                            ),
                            onChanged: busy || plan.completed.contains(id)
                                ? null
                                : (_) => done(id),
                          ),
                      TextButton(
                        onPressed: exit,
                        child: Text(
                          stop == null
                              ? 'Finish trip'
                              : 'Stop guidance and view plan',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
