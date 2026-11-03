import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../places/data/search_quota.dart';
import '../../places/domain/place_search.dart';
import '../domain/planning_models.dart';
import '../domain/navigation_models.dart';

/// A real, attributed UI Kit component. No hidden coordinate-only fetch API.
class TripPlaceDetailsController extends ChangeNotifier {
  TripPlaceDetailsController(this.ledger);
  final QuotaLedger ledger;
  final _ready = Completer<MethodChannel>();
  MethodChannel? _channel;
  Completer<Map<Object?, Object?>>? _selection;
  Future<Map<Object?, Object?>>? _flight;
  String? _loadingId, _loadedId, _failedPresentationId;
  Map<Object?, Object?>? _snapshot;
  bool visible = false, everVisible = false, _disposed = false;
  int _presentationRevision = 1000000;
  VoidCallback? onPresentationFailure;
  void Function(String)? onPresentationSuccess;

  void attach(MethodChannel channel) {
    if (_disposed) return;
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'selection' && _selection?.isCompleted == false) {
        _selection!.complete(Map<Object?, Object?>.from(call.arguments as Map));
      }
    });
    if (!_ready.isCompleted) _ready.complete(channel);
  }

  void _show(bool value) {
    if (_disposed) return;
    if (visible == value && (everVisible || !value)) return;
    visible = value;
    everVisible |= value;
    notifyListeners();
  }

  Future<Map<Object?, Object?>> load(String id, int revision) {
    if (_disposed) return Future.error(StateError('Place details closed'));
    _show(true);
    final timestamp = _snapshot?['retrievedAtMillis'];
    final acquired = timestamp is int
        ? DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true)
        : null;
    if (_loadedId == id &&
        _snapshot != null &&
        acquired != null &&
        !acquired.isAfter(DateTime.now()) &&
        DateTime.now().isBefore(acquired.add(const Duration(days: 30)))) {
      return Future.value({..._snapshot!, 'revision': revision});
    }
    if (_flight != null) {
      if (_loadingId != id) {
        return Future.error(
          const PlanningFailure(
            'The previous destination lookup is still finishing. Retry explicitly.',
            kind: 'target_pending',
          ),
        );
      }
      return _flight!.then((value) => {...value, 'revision': revision});
    }
    _loadingId = id;
    final work = _load(id, revision);
    _flight = work;
    unawaited(
      work.then(
        (_) {
          if (identical(_flight, work)) _flight = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_flight, work)) _flight = null;
        },
      ),
    );
    return work;
  }

  Future<Map<Object?, Object?>> _load(String id, int revision) async {
    var dispatched = false;
    try {
      final native = await _ready.future.timeout(const Duration(seconds: 10));
      if (_disposed || !visible) throw StateError('Place details closed');
      // Waiting for spacing is not a provider retry or another reservation.
      for (var attempt = 0; ; attempt++) {
        final due = await ledger.reserve(
          'google_ui_kit',
          ProviderPolicy.forId('google_ui_kit'),
          googleUnitMicros: 20000,
        );
        if (due == null) break;
        final wait = due.difference(DateTime.now());
        if (attempt >= 2 || wait > const Duration(seconds: 3)) {
          throw const PlanningFailure(
            'Google destination lookups are temporarily limited. Retry explicitly later.',
            kind: 'target_quota',
          );
        }
        await Future<void>.delayed(wait.isNegative ? Duration.zero : wait);
      }
      if (_disposed || !visible) {
        await ledger.googleBudget?.google(
          'places_20000',
          1,
          20000,
          release: true,
        );
        throw StateError('Place details closed');
      }
      _selection = Completer();
      dispatched = true;
      // Retain this actual flight after the trip caller's deadline. SDK timeout
      // is not proof of cancellation and must not authorize another dispatch.
      final result = await native.invokeMapMethod<Object?, Object?>('details', {
        'placeId': id,
        'revision': revision,
      });
      if (result?['count'] != 1) throw const FormatException();
      final selected = await _selection!.future.timeout(
        const Duration(seconds: 5),
      );
      if (_disposed) throw StateError('Place details closed');
      if (selected['placeId'] != id ||
          selected['revision'] != revision ||
          selected['resolved'] != true ||
          selected['latitude'] is! num ||
          selected['longitude'] is! num ||
          selected['retrievedAtMillis'] is! int) {
        throw const FormatException();
      }
      final coordinate = NavigationCoordinate(
        latitude: (selected['latitude'] as num).toDouble(),
        longitude: (selected['longitude'] as num).toDouble(),
      );
      if (!coordinate.valid ||
          (selected['retrievedAtMillis'] as int) <= 0 ||
          (selected['retrievedAtMillis'] as int) >
              DateTime.now().millisecondsSinceEpoch) {
        throw const FormatException();
      }
      await native.invokeMethod<void>('show', revision);
      await native.invokeMethod<void>('visibility', true);
      _loadedId = id;
      _snapshot = selected;
      await ledger.succeeded('google_ui_kit');
      return selected;
    } catch (error) {
      if (dispatched) {
        try {
          final kind = error is PlatformException && error.code == 'rate'
              ? SearchFailureKind.rate
              : error is PlatformException && error.code == 'access'
              ? SearchFailureKind.access
              : SearchFailureKind.temporary;
          await ledger.failed('google_ui_kit', SearchFailure(kind));
        } catch (_) {
          /* Keep the original explicit failure and reservation. */
        }
      }
      if (error is PlanningFailure) rethrow;
      throw const PlanningFailure(
        'Google could not load this exact destination. Your trip is kept. Retry explicitly.',
        kind: 'target_lookup',
      );
    }
  }

  Future<void> present(String? id, {bool retry = false}) async {
    if (id == null) {
      _show(false);
      return;
    }
    if (retry) _failedPresentationId = null;
    if (_failedPresentationId == id || _disposed) return;
    try {
      await load(
        id,
        ++_presentationRevision,
      ).timeout(const Duration(seconds: 45));
      if (!_disposed) onPresentationSuccess?.call(id);
    } catch (_) {
      if (_disposed) return;
      _failedPresentationId = id;
      _show(false);
      onPresentationFailure?.call();
    }
  }

  void hide() => _show(false);
  @override
  void dispose() {
    _disposed = true;
    _channel?.setMethodCallHandler(null);
    // Native PlatformView disposal removes its fragments. Late callbacks are
    // rejected by the resolver's trip/session guard and never update progress.
    super.dispose();
  }
}

class TripPlaceDetailsHost extends StatefulWidget {
  const TripPlaceDetailsHost({required this.controller, super.key});
  final TripPlaceDetailsController controller;
  @override
  State<TripPlaceDetailsHost> createState() => _TripPlaceDetailsHostState();
}

class _TripPlaceDetailsHostState extends State<TripPlaceDetailsHost> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.everVisible) return const SizedBox.shrink();
    return Offstage(
      offstage: !widget.controller.visible,
      child: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.textScalerOf(context).scale(180),
          child: PlatformViewLink(
            viewType: 'wayday/google_places',
            surfaceFactory: (context, controller) => AndroidViewSurface(
              controller: controller as AndroidViewController,
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
              gestureRecognizers: const {},
            ),
            onCreatePlatformView: (params) {
              final controller = PlatformViewsService.initExpensiveAndroidView(
                id: params.id,
                viewType: 'wayday/google_places',
                layoutDirection: TextDirection.ltr,
                onFocus: () => params.onFocusChanged(true),
              );
              controller.addOnPlatformViewCreatedListener(
                params.onPlatformViewCreated,
              );
              controller.addOnPlatformViewCreatedListener(
                (id) => widget.controller.attach(
                  MethodChannel('wayday/google_places/$id'),
                ),
              );
              controller.create();
              return controller;
            },
          ),
        ),
      ),
    );
  }
}
