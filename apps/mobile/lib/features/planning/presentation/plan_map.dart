import 'dart:math' as math;
import 'dart:ui' as ui;
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
    this.labels,
    this.traffic = false,
    super.key,
  });
  final List<PlaceIntent> places;
  final List<List<List<double>>> geometry;
  final ValueChanged<int> onSelect;
  final int? selected;
  final List<String>? labels;
  final bool traffic;
  @override
  State<PlanMap> createState() => _PlanMapState();
}

class _PlanMapState extends State<PlanMap> {
  nav.GoogleMapViewController? controller;
  final indices = <String, int>{};
  String? error;
  final markerImages = <nav.ImageDescriptor>[];
  Future<nav.ImageDescriptor> markerIcon(String label) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(2);
    canvas.drawCircle(
      const Offset(18, 18),
      16,
      Paint()..color = context.wayday.link,
    );
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontFamily: 'Figtree',
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(18 - text.width / 2, 18 - text.height / 2));
    final picture = recorder.endRecording();
    final image = await picture.toImage(72, 72);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    final descriptor = await nav.registerBitmapImage(
      bitmap: bytes!,
      imagePixelRatio: 2,
    );
    if (!mounted) {
      await nav.unregisterImage(descriptor);
    } else {
      markerImages.add(descriptor);
    }
    return descriptor;
  }

  @override
  void dispose() {
    for (final descriptor in markerImages) {
      nav.unregisterImage(descriptor).catchError((Object _) {});
    }
    super.dispose();
  }

  nav.LatLng point(PlaceIntent p) =>
      nav.LatLng(latitude: p.latitude!, longitude: p.longitude!);
  Future<void> created(nav.GoogleMapViewController value) async {
    controller = value;
    try {
      final eligible = widget.places.where((p) => p.hasCoordinates).toList();
      final eligibleIndices = [
        for (var i = 0; i < widget.places.length; i++)
          if (widget.places[i].hasCoordinates) i,
      ];
      await value.settings.setTrafficEnabled(widget.traffic);
      final icons = <int, nav.ImageDescriptor>{};
      for (final i in eligibleIndices) {
        icons[i] = await markerIcon(
          i == 0
              ? 'A'
              : i == widget.places.length - 1
              ? 'B'
              : '$i',
        );
        if (!mounted) return;
      }
      final markers = await value.addMarkers([
        for (var i = 0; i < widget.places.length; i++)
          if (widget.places[i].hasCoordinates)
            nav.MarkerOptions(
              icon: icons[i]!,
              position: point(widget.places[i]),
              infoWindow: nav.InfoWindow(
                title:
                    '${i == 0
                        ? 'A'
                        : i == widget.places.length - 1
                        ? 'B'
                        : i}. ${widget.labels?[i] ?? widget.places[i].label}',
              ),
            ),
      ]);
      for (var i = 0; i < markers.length; i++) {
        final marker = markers[i];
        if (marker != null) indices[marker.markerId] = eligibleIndices[i];
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
    if (old.traffic != widget.traffic) {
      controller?.settings
          .setTrafficEnabled(widget.traffic)
          .catchError((Object _) {});
    }
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
