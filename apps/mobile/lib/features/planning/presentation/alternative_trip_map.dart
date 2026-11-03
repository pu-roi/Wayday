import 'dart:async';
import 'dart:math' show Point;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:url_launcher/url_launcher.dart';
import '../../today/domain/day.dart';
import '../data/alternative_navigation_driver.dart';
import '../data/trip_navigation.dart';
import 'trip_session.dart';

const _style = String.fromEnvironment(
  'WAYDAY_MAP_STYLE',
  defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
);

class AlternativeTripMap extends StatefulWidget {
  const AlternativeTripMap({
    required this.model,
    required this.driver,
    required this.session,
    this.style = _style,
    super.key,
  });
  final TripSession model;
  final AlternativeNavigationDriver driver;
  final int session;
  final String style;
  @override
  State<AlternativeTripMap> createState() => _AlternativeTripMapState();
}

class _AlternativeTripMapState extends State<AlternativeTripMap>
    implements TripMapPort {
  ml.MapLibreMapController? _controller;
  StreamSubscription<void>? _changes;
  bool _ready = false, _syncing = false, _pending = false;
  List<NavigationLeg>? _drawn;
  final List<ml.Line> _lines = [];
  final List<ml.Circle> _destinations = [];
  @override
  void initState() {
    super.initState();
    _changes = widget.driver.changes.listen((_) {
      if (mounted) {
        setState(() {});
        unawaited(_sync());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  bool get _valid => mounted && widget.model.mapSession == widget.session;
  @override
  Future<NavigationCoordinate?> location() async =>
      widget.driver.position ?? widget.model.initialPosition;
  @override
  Future<void> enable() async {
    await _sync();
  }

  @override
  Future<void> disable() async {
    // The manual map source owns no device feed. The navigator releases GPS.
  }

  @override
  Future<void> follow(TravelProfile profile) async {
    widget.model.cameraFollowing(true);
    await _camera();
  }

  Future<void> _camera() async {
    final fix = await location();
    if (!_valid ||
        !_ready ||
        fix == null ||
        !widget.model.following ||
        widget.model.overview) {
      return;
    }
    await _controller!.moveCamera(
      ml.CameraUpdate.newCameraPosition(
        ml.CameraPosition(
          target: ml.LatLng(fix.latitude, fix.longitude),
          zoom: 16,
          bearing: widget.model.plan.day.profile == TravelProfile.walk
              ? 0
              : widget.driver.progress?.bearing ?? 0,
          tilt: widget.model.plan.day.profile == TravelProfile.walk ? 0 : 35,
        ),
      ),
    );
  }

  Future<void> _sync() async {
    if (!_valid || !_ready) return;
    if (_syncing) {
      _pending = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _pending = false;
        final legs = await widget.driver.segments();
        if (!_valid) return;
        if (_drawn == null ||
            _drawn!.length != legs.length ||
            (_drawn!.isNotEmpty &&
                legs.isNotEmpty &&
                !identical(_drawn!.first, legs.first))) {
          for (final line in _lines) {
            await _controller!.removeLine(line);
          }
          _lines.clear();
          for (final circle in _destinations) {
            await _controller!.removeCircle(circle);
          }
          _destinations.clear();
          for (final leg in legs) {
            if (!_valid) return;
            _lines.add(
              await _controller!.addLine(
                ml.LineOptions(
                  geometry: leg.coordinates
                      .map((p) => ml.LatLng(p.latitude, p.longitude))
                      .toList(),
                  lineColor: '#6084eb',
                  lineWidth: 6,
                  lineOpacity: .95,
                ),
              ),
            );
          }
          for (final point in widget.model.remaining) {
            if (!_valid) return;
            _destinations.add(
              await _controller!.addCircle(
                ml.CircleOptions(
                  geometry: ml.LatLng(
                    point.coordinate!.latitude,
                    point.coordinate!.longitude,
                  ),
                  circleRadius: 6,
                  circleColor: '#6084eb',
                  circleStrokeColor: '#ffffff',
                  circleStrokeWidth: 2,
                ),
              ),
            );
          }
          _drawn = legs;
        }
        final fix = await location();
        if (fix != null && _valid) {
          await _controller!.updateManualLocation(
            ml.ManualLocationUpdate(
              target: ml.LatLng(fix.latitude, fix.longitude),
              horizontalAccuracy: widget.driver.progress?.accuracy,
              bearing: widget.driver.progress?.bearing,
            ),
          );
        }
        if (_valid) await _camera();
      } while (_pending && _valid);
    } catch (_) {
      if (_valid) widget.model.mapFailure(widget.session);
    } finally {
      _syncing = false;
    }
  }

  @override
  Future<void> overview(
    List<NavigationLeg> segments,
    List<TripWaypoint> points,
  ) async {
    final coords = [for (final leg in segments) ...leg.coordinates];
    if (!_valid ||
        !_ready ||
        coords.isEmpty ||
        segments.length != points.length) {
      throw StateError('Missing road geometry');
    }
    double min(Iterable<double> values) =>
        values.reduce((a, b) => a < b ? a : b);
    double max(Iterable<double> values) =>
        values.reduce((a, b) => a > b ? a : b);
    // Stop following before fitting; movement cannot overwrite the overview.
    widget.model.cameraFollowing(false);
    await _controller!.moveCamera(
      ml.CameraUpdate.newLatLngBounds(
        ml.LatLngBounds(
          southwest: ml.LatLng(
            min(coords.map((p) => p.latitude)) - .0001,
            min(coords.map((p) => p.longitude)) - .0001,
          ),
          northeast: ml.LatLng(
            max(coords.map((p) => p.latitude)) + .0001,
            max(coords.map((p) => p.longitude)) + .0001,
          ),
        ),
        left: 40,
        top: 130,
        right: 40,
        bottom: 80,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fix = widget.model.initialPosition;
    final progress = widget.driver.progress;
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            onPointerMove: (_) => widget.model.cameraGesture(),
            child: ml.MapLibreMap(
              key: ValueKey('alternative-map-${widget.session}'),
              styleString: widget.style,
              initialCameraPosition: ml.CameraPosition(
                target: ml.LatLng(
                  fix?.latitude ?? 14.58,
                  fix?.longitude ?? 121.06,
                ),
                zoom: 16,
              ),
              locationSource: const ml.ManualLocationSource(),
              myLocationEnabled: true,
              myLocationTrackingMode: ml.MyLocationTrackingMode.none,
              compassEnabled: true,
              compassViewPosition: ml.CompassViewPosition.topRight,
              compassViewMargins: const Point(12, 12),
              attributionButtonEnabled: true,
              onMapCreated: (controller) => _controller = controller,
              onStyleLoadedCallback: () {
                if (!_valid) return;
                _ready = true;
                widget.model.attach(this, session: widget.session);
                unawaited(_sync());
              },
              onCameraTrackingDismissed: widget.model.cameraGesture,
              onMapClick: (_, _) => widget.model.cameraGesture(),
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 64,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .25,
            ),
            child: Card(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress?.instruction ?? 'Waiting for GPS guidance…',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (progress != null)
                      Text(
                        '${(progress.duration / 60).ceil()} min · ${(progress.distance / 1000).toStringAsFixed(1)} km · ETA ${TimeOfDay.fromDateTime(DateTime.now().add(Duration(seconds: progress.duration.round()))).format(context)}',
                      ),
                    const Text(
                      'Approximate traffic. Lane and speed-limit guidance unavailable.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 64,
          right: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                tooltip: widget.driver.voiceAvailable
                    ? (widget.driver.muted ? 'Enable voice' : 'Mute voice')
                    : 'Voice unavailable; visual instructions remain',
                onPressed: widget.model.active && widget.driver.voiceAvailable
                    ? () => widget.driver.setMuted(!widget.driver.muted)
                    : null,
                icon: Icon(
                  widget.driver.muted || !widget.driver.voiceAvailable
                      ? Icons.volume_off_outlined
                      : Icons.volume_up_outlined,
                ),
              ),
              const SizedBox(height: 8),
              IconButton.filledTonal(
                tooltip: 'Recenter',
                onPressed: widget.model.active
                    ? () => follow(widget.model.plan.day.profile)
                    : null,
                icon: const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
        Positioned(
          left: 4,
          right: 4,
          bottom: 2,
          child: Material(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: .95),
            child: Wrap(
              children: [
                _credit(
                  '© OpenStreetMap',
                  'https://www.openstreetmap.org/copyright',
                ),
                _credit('OpenFreeMap', 'https://openfreemap.org/'),
                _credit('Geoapify', 'https://www.geoapify.com/'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _credit(String label, String url) => TextButton(
    onPressed: () =>
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    child: Text(label, style: const TextStyle(fontSize: 11)),
  );
}
