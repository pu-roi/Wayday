import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;
import '../../../app/theme.dart';
import '../../places/domain/place_intent.dart';

class PlanMap extends StatefulWidget {
  const PlanMap({
    required this.places,
    required this.geometry,
    required this.onSelect,
    this.selected,
    super.key,
  });
  final List<PlaceIntent> places;
  final List<List<List<double>>> geometry;
  final ValueChanged<int> onSelect;
  final int? selected;
  @override
  State<PlanMap> createState() => _PlanMapState();
}

class _PlanMapState extends State<PlanMap> {
  nav.GoogleMapViewController? controller;
  final indices = <String, int>{};
  String? error;
  nav.LatLng point(PlaceIntent p) =>
      nav.LatLng(latitude: p.latitude!, longitude: p.longitude!);
  Future<void> created(nav.GoogleMapViewController value) async {
    controller = value;
    try {
      final eligible = widget.places.where((p) => p.hasCoordinates).toList();
      final markers = await value.addMarkers([
        for (var i = 0; i < widget.places.length; i++)
          if (widget.places[i].hasCoordinates)
            nav.MarkerOptions(
              position: point(widget.places[i]),
              infoWindow: nav.InfoWindow(
                title: '${i + 1}. ${widget.places[i].label}',
              ),
            ),
      ]);
      for (var i = 0; i < markers.length; i++) {
        final marker = markers[i];
        if (marker != null) indices[marker.markerId] = i;
      }
      if (!mounted) return;
      await value.addPolylines([
        for (final leg in widget.geometry)
          nav.PolylineOptions(
            points: leg
                .map((p) => nav.LatLng(latitude: p[0], longitude: p[1]))
                .toList(),
            strokeColor: context.wayday.link,
            strokeWidth: 5,
          ),
      ]);
      if (eligible.isNotEmpty) {
        final lat = eligible.map((p) => p.latitude!).toList(),
            lon = eligible.map((p) => p.longitude!).toList();
        await value.moveCamera(
          nav.CameraUpdate.newLatLngBounds(
            nav.LatLngBounds(
              southwest: nav.LatLng(
                latitude: lat.reduce(math.min) - .001,
                longitude: lon.reduce(math.min) - .001,
              ),
              northeast: nav.LatLng(
                latitude: lat.reduce(math.max) + .001,
                longitude: lon.reduce(math.max) + .001,
              ),
            ),
            padding: 44,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error = 'The Google map is unavailable. Your stop list is below.',
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant PlanMap old) {
    super.didUpdateWidget(old);
    final selected = widget.selected;
    if (selected != null &&
        selected != old.selected &&
        selected < widget.places.length &&
        widget.places[selected].hasCoordinates) {
      controller
          ?.moveCamera(
            nav.CameraUpdate.newLatLngZoom(point(widget.places[selected]), 15),
          )
          .catchError((Object _) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        const String.fromEnvironment('GOOGLE_MAPS_ANDROID_API_KEY').isEmpty ||
        error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error ??
                'The Google route map is available in the configured Android app. Your stop list is below.',
          ),
        ),
      );
    }
    return nav.GoogleMapsMapView(
      onViewCreated: created,
      initialMapToolbarEnabled: false,
      initialMapColorScheme: nav.MapColorScheme.light,
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      onMarkerClicked: (id) {
        final i = indices[id];
        if (i != null) widget.onSelect(i);
      },
    );
  }
}
