import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;
import '../../places/domain/place_intent.dart';

/// Planning's manual override stays on a Google map when SDK data is present.
class GooglePinPickerMap extends StatefulWidget {
  const GooglePinPickerMap({
    required this.focus,
    required this.revision,
    required this.onSelect,
    super.key,
  });
  final PlaceIntent? focus;
  final int revision;
  final void Function(double, double) onSelect;
  @override
  State<GooglePinPickerMap> createState() => _GooglePinPickerMapState();
}

class _GooglePinPickerMapState extends State<GooglePinPickerMap> {
  nav.GoogleMapViewController? controller;
  String? error;
  Future<void> refresh() async {
    final value = controller, place = widget.focus;
    if (value == null || place?.hasCoordinates != true) return;
    try {
      await value.clearMarkers();
      final point = nav.LatLng(
        latitude: place!.latitude!,
        longitude: place.longitude!,
      );
      await value.addMarkers([nav.MarkerOptions(position: point)]);
      await value.moveCamera(nav.CameraUpdate.newLatLngZoom(point, 16));
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'The map is unavailable. Search for a place instead.',
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant GooglePinPickerMap old) {
    super.didUpdateWidget(old);
    if (old.revision != widget.revision || old.focus != widget.focus) refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            error ??
                'The Google map is available in the Android app. Search remains available.',
          ),
        ),
      );
    }
    final focus = widget.focus;
    return nav.GoogleMapsMapView(
      initialCameraPosition: nav.CameraPosition(
        target: nav.LatLng(
          latitude: focus?.latitude ?? 14.576,
          longitude: focus?.longitude ?? 121.08,
        ),
        zoom: 14,
      ),
      initialMapToolbarEnabled: false,
      initialMapColorScheme: nav.MapColorScheme.light,
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      onViewCreated: (value) {
        controller = value;
        refresh();
      },
      onMapClicked: (point) => widget.onSelect(point.latitude, point.longitude),
    );
  }
}
