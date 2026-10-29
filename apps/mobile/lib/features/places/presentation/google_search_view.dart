import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import '../data/google_search.dart';
import 'place_search_controller.dart';

class GoogleSearchView extends StatefulWidget {
  const GoogleSearchView({
    required this.search,
    this.visible = true,
    super.key,
  });
  final PlaceSearchController search;
  final bool visible;
  @override
  State<GoogleSearchView> createState() => GoogleSearchViewState();
}

class _ChannelBridge implements GoogleSearchBridge {
  _ChannelBridge(this.channel);
  final MethodChannel channel;
  @override
  Future<Map<Object?, Object?>> load(GoogleNativeRequest request) async {
    try {
      return (await channel.invokeMapMethod<Object?, Object?>(
            request.placeId == null ? 'search' : 'details',
            request.toJson(),
          )) ??
          {};
    } on PlatformException catch (error) {
      return {'error': error.code};
    } on MissingPluginException catch (_) {
      return {'error': 'services'};
    }
  }

  @override
  Future<void> show(int revision) async {
    try {
      await channel.invokeMethod<void>('show', revision);
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }

  @override
  Future<void> cancel() async {
    try {
      await channel.invokeMethod<void>('cancel');
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }
}

class GoogleSearchViewState extends State<GoogleSearchView> {
  @visibleForTesting
  int? nativeViewId;
  _ChannelBridge? _bridge;
  void _created(int id) {
    nativeViewId = id;
    final channel = MethodChannel('wayday/google_places/$id');
    final bridge = _ChannelBridge(channel);
    _bridge = bridge;
    channel.setMethodCallHandler((call) async {
      if (!mounted) return;
      if (call.method == 'interaction' && widget.visible) {
        widget.search.freezeResults();
      }
      if (call.method == 'selection') {
        try {
          final value = GooglePlaceSnapshot.fromJson(
            Map<Object?, Object?>.from(call.arguments as Map),
            DateTime.now(),
          );
          await widget.search.googleSelected(value);
        } on FormatException catch (_) {
          /* Invalid native records cannot be selected. */
        }
      }
    });
    widget.search.attachGoogle(bridge);
    _visibility();
  }

  Future<void> _visibility() async {
    try {
      await _bridge?.channel.invokeMethod<void>('visibility', widget.visible);
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }

  @override
  void didUpdateWidget(covariant GoogleSearchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) _visibility();
  }

  @override
  void dispose() {
    final bridge = _bridge;
    if (bridge != null) {
      widget.search.detachGoogle(bridge);
      bridge.channel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlatformViewLink(
    key: const Key('google-standard-search'),
    viewType: 'wayday/google_places',
    surfaceFactory: (context, controller) => AndroidViewSurface(
      controller: controller as AndroidViewController,
      hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
    ),
    onCreatePlatformView: (params) {
      // Native fragments must remain in the Activity's actual view hierarchy.
      final controller = PlatformViewsService.initExpensiveAndroidView(
        id: params.id,
        viewType: 'wayday/google_places',
        layoutDirection: Directionality.of(context),
        onFocus: () => params.onFocusChanged(true),
      );
      controller.addOnPlatformViewCreatedListener(params.onPlatformViewCreated);
      controller.addOnPlatformViewCreatedListener(_created);
      controller.create();
      return controller;
    },
  );
}
