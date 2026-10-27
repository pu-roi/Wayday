import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../app/theme.dart';
import '../data/regional_map_repository.dart';
import 'map_credits_page.dart';

final mapPlatformSupportedProvider = Provider(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
);
typedef RegionalMapRenderer =
    Widget Function(
      BuildContext context,
      RegionalMapPackage package,
      VoidCallback onReady,
    );
final regionalMapRendererProvider = Provider<RegionalMapRenderer>(
  (ref) =>
      (context, package, onReady) =>
          NativeRegionalMap(package: package, onReady: onReady),
);

/// One map surface shared by every manual-label picker. It never selects a place.
class RegionalMap extends ConsumerWidget {
  const RegionalMap({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(mapPlatformSupportedProvider)) {
      return const _MapMessage(
        title: 'Map available on Android',
        message:
            'Enter a place name below. This preview keeps manual labels only.',
      );
    }
    return ref
        .watch(regionalMapPackageProvider)
        .when(
          loading: () => const _MapMessage(
            title: 'Preparing regional map',
            message:
                'You can enter a place name while the offline map is checked.',
          ),
          error: (error, stack) => const _MapMessage(
            title: 'Map unavailable',
            message:
                'The regional package could not be loaded. You can still enter a place name.',
          ),
          data: (package) => _ReadyMap(package: package),
        );
  }
}

class _ReadyMap extends ConsumerStatefulWidget {
  const _ReadyMap({required this.package});
  final RegionalMapPackage package;
  @override
  ConsumerState<_ReadyMap> createState() => _ReadyMapState();
}

class _ReadyMapState extends ConsumerState<_ReadyMap> {
  bool _ready = false;
  bool _failed = false;
  Timer? _timeout;
  @override
  void initState() {
    super.initState();
    _timeout = Timer(const Duration(seconds: 30), () {
      if (mounted && !_ready) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _onReady() {
    _timeout?.cancel();
    if (mounted && !_ready) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const _MapMessage(
        title: 'Map unavailable',
        message:
            'The map renderer could not load this package. You can still enter a place name.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 1.35,
            child: Semantics(
              label:
                  'Regional map. Pan and zoom to explore; place labels are entered separately.',
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ref.watch(regionalMapRendererProvider)(
                      context,
                      widget.package,
                      _onReady,
                    ),
                  ),
                  if (!_ready)
                    const Positioned(
                      left: 12,
                      top: 12,
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Loading map…'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Open map credits and licenses',
          child: InkWell(
            onTap: () => openMapCredits(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '© OpenStreetMap contributors · Protomaps',
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.secondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Native adapter. Callbacks also allow device verification to inspect the real
/// controller without adding verification markers to the production picker.
class NativeRegionalMap extends StatefulWidget {
  const NativeRegionalMap({
    required this.package,
    required this.onReady,
    this.onCreated,
    this.onIdle,
    super.key,
  });
  final RegionalMapPackage package;
  final VoidCallback onReady;
  final ValueChanged<MapLibreMapController>? onCreated;
  final VoidCallback? onIdle;
  @override
  State<NativeRegionalMap> createState() => _NativeRegionalMapState();
}

class _NativeRegionalMapState extends State<NativeRegionalMap> {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  bool _checking = false;
  bool _pendingCheck = false;
  bool _verified = false;
  Size _size = Size.zero;

  Future<void> _checkRenderedMap() async {
    final controller = _controller;
    if (!mounted ||
        !_styleLoaded ||
        controller == null ||
        _verified ||
        _size.isEmpty) {
      return;
    }
    if (_checking) {
      _pendingCheck = true;
      return;
    }
    _checking = true;
    try {
      // The Android plugin passes query bounds to native screen pixels unchanged.
      final ratio = MediaQuery.devicePixelRatioOf(context);
      final rect =
          Offset.zero & Size(_size.width * ratio, _size.height * ratio);
      final roads = await controller.queryRenderedFeaturesInRect(rect, [
        'roads',
        'major-roads',
      ], null);
      if (!mounted) return;
      final labels = await controller.queryRenderedFeaturesInRect(rect, [
        'road-labels',
        'place-labels',
        'poi-labels',
      ], null);
      if (mounted && roads.isNotEmpty && labels.isNotEmpty) {
        _verified = true;
        widget.onReady();
      }
    } catch (_) {
      // Resource/native failures remain pending until the enclosing timeout
      // presents an unavailable map without affecting the manual label form.
    } finally {
      _checking = false;
      // An idle event can arrive while an earlier style-load query still sees
      // empty tiles. Preserve that event for one recheck after this query.
      if (mounted && !_verified && _pendingCheck) {
        _pendingCheck = false;
        unawaited(_checkRenderedMap());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final package = widget.package;
    final b = package.bounds;
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return MapLibreMap(
          key: const Key('native-regional-map'),
          styleString: package.style,
          initialCameraPosition: CameraPosition(
            target: LatLng((b[1] + b[3]) / 2, (b[0] + b[2]) / 2),
            zoom: (package.maxZoom - 2).clamp(package.minZoom, package.maxZoom),
          ),
          cameraTargetBounds: CameraTargetBounds(
            LatLngBounds(
              southwest: LatLng(b[1], b[0]),
              northeast: LatLng(b[3], b[2]),
            ),
          ),
          minMaxZoomPreference: MinMaxZoomPreference(
            (package.maxZoom - 4).clamp(package.minZoom, package.maxZoom),
            package.maxZoom,
          ),
          trackCameraPosition: true,
          // This slice explores the basemap without user annotations. Avoid
          // starting optional annotation managers while picker routes open/close.
          annotationOrder: const [],
          tiltGesturesEnabled: false,
          rotateGesturesEnabled: false,
          // Eager ownership lets the map pan within the surrounding scrollable form.
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
          onMapCreated: (controller) {
            _controller = controller;
            widget.onCreated?.call(controller);
          },
          onStyleLoadedCallback: () {
            _styleLoaded = true;
            unawaited(_checkRenderedMap());
          },
          onMapIdle: () {
            widget.onIdle?.call();
            unawaited(_checkRenderedMap());
          },
        );
      },
    );
  }
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.map_outlined),
          const SizedBox(height: 12),
          Text(title, style: context.type.titleMedium),
          const SizedBox(height: 8),
          Text(message),
        ],
      ),
    ),
  );
}
