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
import '../data/alternative_navigation_driver.dart';
import '../data/alternative_route_client.dart';
import 'alternative_trip_map.dart';
import 'trip_provider_sheet.dart';
import '../data/navigation_target_resolver.dart';
import '../../places/data/search_quota.dart';
import 'trip_place_details.dart';

final tripNavigationProvider = Provider<TripNavigation>(
  (ref) => TripNavigation(ref.read(planningBudgetProvider)),
);

typedef TripMapBuilder =
    Widget Function(
      BuildContext context,
      ValueChanged<TripMapPort> ready,
      NavigationCoordinate? position,
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
  TripPlaceDetailsController? _details;
  String? _presentedTargetId;
  bool closing = false;
  @override
  void initState() {
    super.initState();
    final container = ProviderScope.containerOf(context, listen: false);
    if (uiKitNavigationTargetsEnabled && AlternativeRouteClient().enabled) {
      _details = TripPlaceDetailsController(
        ref.read(searchQuotaLedgerProvider),
      );
      _details!.onPresentationFailure = () {
        if (!mounted) return;
        model.placeDetailsAvailability(false);
      };
      _details!.onPresentationSuccess = (id) {
        if (mounted &&
            model.active &&
            model.provider == TripMapProvider.openStreetMap &&
            model.current.target?.placeId == id &&
            model.placeDetailsUnavailable) {
          model.placeDetailsAvailability(true);
        }
      };
    }
    Future<NavigationCoordinate> acquire() async {
      final location = ref.read(searchLocationProvider);
      final fix = await location.refresh(requestPermission: true);
      if (fix == null) {
        throw const PlanningFailure(
          'Your location is unavailable. Check phone location services and permissions, then retry.',
          kind: 'location',
        );
      }
      final acquired = fix.acquiredAt;
      if (fix.approximate ||
          fix.accuracy > 100 ||
          acquired == null ||
          DateTime.now().difference(acquired).isNegative ||
          DateTime.now().difference(acquired) > const Duration(seconds: 15)) {
        throw const PlanningFailure(
          'A fresh, precise GPS fix is needed for alternative guidance. Enable precise location, move where GPS is available and retry.',
          kind: 'location_accuracy',
        );
      }
      return NavigationCoordinate(
        latitude: fix.latitude,
        longitude: fix.longitude,
      );
    }

    TripNavigation create(TripMapProvider provider) => TripNavigation(
      ref.read(planningBudgetProvider),
      provider: provider,
      driver: provider == TripMapProvider.google
          ? GoogleNavigationDriver()
          : AlternativeNavigationDriver(
              client: AlternativeRouteClient(),
              acquireLocation: acquire,
              tripId: widget.initial.runId,
            ),
    );
    model =
        widget.session ??
        TripSession(
          plan: widget.initial,
          navigation:
              widget.initial.navigationProvider == TripMapProvider.google
              ? ref.read(tripNavigationProvider)
              : create(widget.initial.navigationProvider),
          createNavigation: create,
          targetResolver: _details == null
              ? null
              : NavigationTargetResolver(load: _details!.load),
          acquireAlternativeLocation: acquire,
          persistProvider: (run, provider) async {
            final changed = await ref
                .read(itineraryRepositoryProvider)
                .updateNavigationProvider(run, provider);
            container.invalidate(savedItineraryProvider);
            return changed;
          },
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
            return NavigationCoordinate(
              latitude: fix.latitude,
              longitude: fix.longitude,
            );
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
    if (!mounted) return;
    if (!model.switching) {
      final id = model.provider == TripMapProvider.openStreetMap && model.active
          ? model.current.target?.placeId
          : null;
      if (id != _presentedTargetId) {
        _presentedTargetId = id;
        unawaited(_details?.present(id));
      }
      if (id == null) _details?.hide();
    }
    setState(() {});
  }

  void _start({bool explicit = false}) {
    if (explicit && model.active && _details != null) {
      model.placeDetailsAvailability(true);
      unawaited(_details!.present(model.current.target?.placeId, retry: true));
      return;
    }
    final colors = Theme.of(context).colorScheme;
    unawaited(
      model.start(
        allowTargetFetch: explicit,
        colors: NavigationAppearance(
          backgroundColor: colors.surface,
          titleColor: colors.onSurface,
          mainTextColor: colors.onSurface,
          acceptButtonTextColor: colors.secondary,
          cancelButtonTextColor: colors.secondary,
        ),
      ),
    );
  }

  Future<void> _providers() async {
    final selected = await showTripProviders(
      context,
      model,
      alternativeEnabled: AlternativeRouteClient().enabled,
    );
    if (!mounted || selected == null) return;
    final colors = Theme.of(context).colorScheme;
    await model.switchProvider(
      selected,
      colors: NavigationAppearance(
        backgroundColor: colors.surface,
        titleColor: colors.onSurface,
        mainTextColor: colors.onSurface,
        acceptButtonTextColor: colors.secondary,
        cancelButtonTextColor: colors.secondary,
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
    _details?.dispose();
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
    final mapSession = model.mapSession;
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
                } else if (value == 'provider') {
                  unawaited(_providers());
                } else {
                  showNavigationInfo(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'plan', child: Text('View plan')),
                PopupMenuItem(
                  value: 'provider',
                  child: Text('Map & navigation'),
                ),
                PopupMenuItem(value: 'info', child: Text('Navigation info')),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (!model.active ||
                  model.error != null ||
                  model.gpsLost ||
                  model.switching)
                TripStatus(
                  model: model,
                  onResume: () => _start(explicit: true),
                  onProviders: _providers,
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    children: [
                      Expanded(
                        child: model.mapRequested
                            ? widget.mapBuilder?.call(
                                    context,
                                    (map) =>
                                        model.attach(map, session: mapSession),
                                    model.initialPosition,
                                  ) ??
                                  (model.navigation.driver
                                          is AlternativeNavigationDriver
                                      ? AlternativeTripMap(
                                          key: ValueKey(
                                            'alternative-trip-$mapSession',
                                          ),
                                          model: model,
                                          driver:
                                              model.navigation.driver
                                                  as AlternativeNavigationDriver,
                                          session: mapSession,
                                        )
                                      : nav.GoogleMapsNavigationView(
                                          key: ValueKey(
                                            'trip-navigation-map-$mapSession',
                                          ),
                                          onViewCreated: (controller) =>
                                              model.attach(
                                                GoogleTripMapPort(controller),
                                                session: mapSession,
                                              ),
                                          initialCameraPosition:
                                              nav.CameraPosition(
                                                target:
                                                    (model.initialPosition ==
                                                            null
                                                        ? null
                                                        : nav.LatLng(
                                                            latitude: model
                                                                .initialPosition!
                                                                .latitude,
                                                            longitude: model
                                                                .initialPosition!
                                                                .longitude,
                                                          )) ??
                                                    nav.LatLng(
                                                      latitude:
                                                          model
                                                              .current
                                                              .place
                                                              .latitude ??
                                                          14.58,
                                                      longitude:
                                                          model
                                                              .current
                                                              .place
                                                              .longitude ??
                                                          121.06,
                                                    ),
                                                zoom: 16,
                                              ),
                                          initialForceNightMode:
                                              nav.NavigationForceNightMode.auto,
                                          initialMapToolbarEnabled: false,
                                          onCameraStartedFollowingLocation:
                                              (_) =>
                                                  model.cameraFollowing(true),
                                          onCameraStoppedFollowingLocation:
                                              (_) =>
                                                  model.cameraFollowing(false),
                                          onCameraMoveStarted: (_, gesture) {
                                            if (gesture) model.cameraGesture();
                                          },
                                        ))
                            : ColoredBox(
                                color: colors.surfaceContainerHighest,
                                child: const Center(
                                  child: Icon(
                                    Icons.navigation_outlined,
                                    size: 40,
                                  ),
                                ),
                              ),
                      ),
                      if (_details != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight * .4,
                          ),
                          child: TripPlaceDetailsHost(controller: _details!),
                        ),
                    ],
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
