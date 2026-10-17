import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../app/theme.dart';
import '../../places/domain/place_intent.dart';

String _color(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

const _mapStyle = String.fromEnvironment(
  'WAYDAY_MAP_STYLE',
  defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
);

class MapPin {
  const MapPin(this.label, this.place);
  final String label;
  final PlaceIntent place;
  @override
  bool operator ==(Object other) =>
      other is MapPin &&
      label == other.label &&
      place.latitude == other.place.latitude &&
      place.longitude == other.place.longitude;
  @override
  int get hashCode => Object.hash(label, place.latitude, place.longitude);
}

class PlaceMapRequest {
  const PlaceMapRequest({
    this.pins = const [],
    this.onSelect,
    this.interactive = true,
    this.centerPicker = false,
    this.focus,
    this.focusRevision = 0,
  });
  final List<MapPin> pins;
  final void Function(double latitude, double longitude)? onSelect;
  final bool interactive;
  final bool centerPicker;
  final PlaceIntent? focus;
  final int focusRevision;
}

typedef PlaceMapBuilder = Widget Function(PlaceMapRequest request);

/// Tests inject a map double; production always uses the native map renderer.
final placeMapBuilderProvider = Provider<PlaceMapBuilder>(
  (ref) =>
      (request) => PlaceMap(request: request),
);

class PlaceMap extends StatefulWidget {
  const PlaceMap({required this.request, super.key});
  final PlaceMapRequest request;
  @override
  State<PlaceMap> createState() => _PlaceMapState();
}

class _PlaceMapState extends State<PlaceMap> {
  MapLibreMapController? _controller;
  bool _ready = false;
  bool _slow = false;
  int _attempt = 0;
  Timer? _timer;
  Future<void> _pending = Future.value();
  LatLng? _cameraTarget;
  LatLng get _initialTarget => widget.request.focus?.hasCoordinates == true
      ? LatLng(
          widget.request.focus!.latitude!,
          widget.request.focus!.longitude!,
        )
      : _pins.isEmpty
      ? const LatLng(14.5764, 121.0851)
      : LatLng(_pins.first.place.latitude!, _pins.first.place.longitude!);

  void _focus() {
    final place = widget.request.focus;
    if (place == null || !place.hasCoordinates || _controller == null) return;
    unawaited(
      _controller!
          .moveCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(place.latitude!, place.longitude!),
              16,
            ),
          )
          .timeout(const Duration(seconds: 3))
          .catchError((Object _) {
            if (mounted) setState(() => _slow = true);
            return false;
          }),
    );
  }

  List<MapPin> get _pins =>
      widget.request.pins.where((p) => p.place.hasCoordinates).toList();

  @override
  void initState() {
    super.initState();
    _watchLoading();
  }

  void _watchLoading() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_ready) setState(() => _slow = true);
    });
  }

  Map<String, dynamic> get _geoJson => {
    'type': 'FeatureCollection',
    'features': [
      for (final pin in _pins)
        {
          'type': 'Feature',
          'properties': {'label': pin.label},
          'geometry': {
            'type': 'Point',
            'coordinates': [pin.place.longitude, pin.place.latitude],
          },
        },
    ],
  };

  void _sync({bool initialize = false}) {
    final controller = _controller;
    final attempt = _attempt;
    final markerColor = _color(context.wayday.link);
    final markerText = _color(context.colors.surface);
    _pending = _pending.catchError((Object _) {}).then((_) async {
      if (!mounted ||
          controller == null ||
          controller != _controller ||
          attempt != _attempt) {
        return;
      }
      try {
        if (initialize) {
          await controller.addGeoJsonSource('wayday-stops', _geoJson);
          await controller.addCircleLayer(
            'wayday-stops',
            'wayday-dots',
            CircleLayerProperties(
              circleRadius: 15,
              circleColor: markerColor,
              circleStrokeWidth: 3,
              circleStrokeColor: markerText,
            ),
          );
          await controller.addSymbolLayer(
            'wayday-stops',
            'wayday-labels',
            SymbolLayerProperties(
              textField: ['get', 'label'],
              textSize: 13,
              textColor: markerText,
              textAllowOverlap: true,
              textFont: ['Noto Sans Regular'],
            ),
          );
        } else {
          await controller.setGeoJsonSource('wayday-stops', _geoJson);
        }
        if (!mounted || controller != _controller || attempt != _attempt) {
          return;
        }
        final pins = _pins;
        if (pins.isNotEmpty) {
          var south = pins.first.place.latitude!, north = south;
          var west = pins.first.place.longitude!, east = west;
          for (final pin in pins) {
            final lat = pin.place.latitude!, lon = pin.place.longitude!;
            if (lat < south) south = lat;
            if (lat > north) north = lat;
            if (lon < west) west = lon;
            if (lon > east) east = lon;
          }
          await controller.moveCamera(
            north - south < .00001 && east - west < .00001
                ? CameraUpdate.newLatLngZoom(LatLng(south, west), 16)
                : CameraUpdate.newLatLngBounds(
                    LatLngBounds(
                      southwest: LatLng(south, west),
                      northeast: LatLng(north, east),
                    ),
                    left: 32,
                    right: 32,
                    top: 40,
                    bottom: 48,
                  ),
          );
        }
      } catch (_) {
        if (mounted && attempt == _attempt) setState(() => _slow = true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PlaceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready && widget.request.centerPicker) {
      if (oldWidget.request.focusRevision != widget.request.focusRevision) {
        _focus();
      }
      return;
    }
    if (_ready && !listEquals(oldWidget.request.pins, widget.request.pins)) {
      _sync();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    // MapLibreMap owns and disposes its native controller.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !widget.request.interactive,
                child: MapLibreMap(
                  key: ValueKey(_attempt),
                  styleString: _mapStyle,
                  initialCameraPosition: CameraPosition(
                    target: _initialTarget,
                    zoom: widget.request.centerPicker ? 16 : 13,
                  ),
                  gestureRecognizers: widget.request.interactive
                      ? {
                          Factory<OneSequenceGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                          ),
                        }
                      : const {},
                  scrollGesturesEnabled: widget.request.interactive,
                  zoomGesturesEnabled: widget.request.interactive,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  compassEnabled: false,
                  trackCameraPosition: widget.request.centerPicker,
                  featureTapsTriggersMapClick: true,
                  onCameraMove: (position) => _cameraTarget = position.target,
                  onCameraIdle: () {
                    if (_ready && widget.request.centerPicker) {
                      final target = _cameraTarget ?? _initialTarget;
                      widget.request.onSelect?.call(
                        target.latitude,
                        target.longitude,
                      );
                    }
                  },
                  attributionButtonPosition:
                      AttributionButtonPosition.bottomRight,
                  onMapCreated: (controller) => _controller = controller,
                  onStyleLoadedCallback: () {
                    if (!mounted) return;
                    _timer?.cancel();
                    setState(() {
                      _ready = true;
                      _slow = false;
                    });
                    if (widget.request.centerPicker) {
                      final target = _cameraTarget ?? _initialTarget;
                      widget.request.onSelect?.call(
                        target.latitude,
                        target.longitude,
                      );
                    } else {
                      _sync(initialize: true);
                    }
                  },
                  onMapClick: (_, point) {
                    if (widget.request.centerPicker) {
                      unawaited(
                        _controller
                            ?.moveCamera(CameraUpdate.newLatLng(point))
                            .timeout(const Duration(seconds: 3))
                            .catchError((Object _) => false),
                      );
                    } else {
                      widget.request.onSelect?.call(
                        point.latitude,
                        point.longitude,
                      );
                    }
                  },
                ),
              ),
            ),
            if (widget.request.centerPicker)
              Center(
                child: IgnorePointer(
                  child: Transform.translate(
                    offset: const Offset(0, -20),
                    child: Icon(
                      Icons.location_pin,
                      size: 48,
                      color: context.wayday.link,
                      shadows: [
                        Shadow(color: context.colors.surface, blurRadius: 3),
                      ],
                    ),
                  ),
                ),
              ),
            if (!_ready || _slow)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Material(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _slow
                                ? 'Map unavailable or slow. Retry or choose a saved place.'
                                : 'Loading map…',
                            style: context.type.bodySmall,
                          ),
                        ),
                        if (_slow)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _attempt++;
                                _ready = false;
                                _slow = false;
                                _controller = null;
                              });
                              _watchLoading();
                            },
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '© OpenFreeMap · OpenMapTiles · OpenStreetMap',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11),
        ),
      ),
    ],
  );
}
