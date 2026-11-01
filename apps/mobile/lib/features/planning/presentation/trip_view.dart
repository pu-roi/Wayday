import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;
import '../../maps/data/location_reader.dart';
import '../data/itinerary_repository.dart';
import '../data/trip_navigation.dart';
import '../domain/planning_models.dart';
import 'planning_controller.dart';
import 'saved_plan_view.dart' show savedItineraryProvider;
import 'trip_session.dart';
import 'trip_controls.dart';
import 'trip_map.dart';
import 'finish_trip.dart';

final tripNavigationProvider = Provider<TripNavigation>(
  (ref) => TripNavigation(ref.read(planningBudgetProvider)),
);

typedef TripMapBuilder =
    Widget Function(
      BuildContext context,
      ValueChanged<TripMapPort> ready,
      nav.LatLng? position,
    );

class TripView extends ConsumerStatefulWidget {
  const TripView({
    required this.initial,
    this.session,
    this.mapBuilder,
    super.key,
  });
  final AcceptedItinerary initial;
  final TripSession? session;
  final TripMapBuilder? mapBuilder;
  @override
  ConsumerState<TripView> createState() => _TripState();
}

class _TripState extends ConsumerState<TripView> with WidgetsBindingObserver {
  late final TripSession model;
  bool closing = false;
  @override
  void initState() {
    super.initState();
    final container = ProviderScope.containerOf(context, listen: false);
    model =
        widget.session ??
        TripSession(
          plan: widget.initial,
          navigation: ref.read(tripNavigationProvider),
          acquireLocation: () async {
            final location = ref.read(searchLocationProvider);
            final fix = await location.refresh(requestPermission: true);
            if (fix == null) {
              throw PlanningFailure(switch (location.phase) {
                LocationPhase.denied || LocationPhase.permanentlyDenied =>
                  'Location permission is needed for guidance. Allow it in phone settings and retry.',
                LocationPhase.servicesOff =>
                  'Phone location services are off. Turn them on and retry.',
                _ =>
                  'Your location is unavailable. Move where GPS is available and retry.',
              }, kind: 'location_${location.phase.name}');
            }
            return nav.LatLng(latitude: fix.latitude, longitude: fix.longitude);
          },
          save: (plan) async {
            await ref.read(itineraryRepositoryProvider).updateProgress(plan);
            container.invalidate(savedItineraryProvider);
          },
        );
    model.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _start() {
    final colors = Theme.of(context).colorScheme;
    unawaited(
      model.start(
        colors: nav.TermsAndConditionsUIParams(
          backgroundColor: colors.surface,
          titleColor: colors.onSurface,
          mainTextColor: colors.onSurface,
          acceptButtonTextColor: colors.secondary,
          cancelButtonTextColor: colors.secondary,
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(model.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    model.removeListener(_changed);
    model.dispose();
    super.dispose();
  }

  void _exit() {
    if (closing || ref.read(tripFinishProvider)) return;
    closing = true;
    unawaited(model.pause());
    Navigator.pop(context, TripExit.paused(model.plan));
  }

  void _finished() {
    closing = true;
    unawaited(model.pause());
    Navigator.pop(context, const TripExit.finished());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compactToolbar =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(14) > 18;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your trip'),
          leading: IconButton(
            tooltip: 'Stop guidance and view plan',
            onPressed: _exit,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            if (compactToolbar)
              IconButton(
                tooltip: 'Whole trip',
                icon: const Icon(Icons.route_outlined),
                onPressed: model.active ? model.showWholeTrip : null,
              )
            else
              TextButton(
                onPressed: model.active ? model.showWholeTrip : null,
                child: const Text('Whole trip'),
              ),
            PopupMenuButton<String>(
              tooltip: 'Trip options',
              onSelected: (value) {
                if (value == 'plan') {
                  _exit();
                } else {
                  showNavigationInfo(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'plan', child: Text('View plan')),
                PopupMenuItem(value: 'info', child: Text('Navigation info')),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (!model.active || model.error != null || model.gpsLost)
                TripStatus(model: model, onResume: _start),
              Expanded(
                child: model.mapRequested
                    ? widget.mapBuilder?.call(
                            context,
                            model.attach,
                            model.initialPosition,
                          ) ??
                          nav.GoogleMapsNavigationView(
                            key: const ValueKey('trip-navigation-map'),
                            onViewCreated: (controller) =>
                                model.attach(GoogleTripMapPort(controller)),
                            initialCameraPosition: nav.CameraPosition(
                              target:
                                  model.initialPosition ??
                                  nav.LatLng(
                                    latitude:
                                        model.current.place.latitude ?? 14.58,
                                    longitude:
                                        model.current.place.longitude ?? 121.06,
                                  ),
                              zoom: 16,
                            ),
                            initialForceNightMode:
                                nav.NavigationForceNightMode.auto,
                            initialMapToolbarEnabled: false,
                            onCameraStartedFollowingLocation: (_) =>
                                model.cameraFollowing(true),
                            onCameraStoppedFollowingLocation: (_) =>
                                model.cameraFollowing(false),
                            onCameraMoveStarted: (_, gesture) {
                              if (gesture) model.cameraGesture();
                            },
                          )
                    : ColoredBox(
                        color: colors.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.navigation_outlined, size: 40),
                        ),
                      ),
              ),
              TripChecklist(model: model, onFinish: _finished),
            ],
          ),
        ),
      ),
    );
  }
}
