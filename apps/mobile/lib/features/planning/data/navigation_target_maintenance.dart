import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navigation_target_resolver.dart';

final navigationTargetMaintenanceProvider = Provider((ref) {
  final maintenance = NavigationTargetMaintenance()..start();
  ref.onDispose(maintenance.dispose);
  return maintenance;
});

class NavigationTargetMaintenance with WidgetsBindingObserver {
  Timer? _timer;
  bool _disposed = false, _refreshing = false, _foreground = true;
  late final void Function() _storedChanged = _changed;
  void _changed() {
    unawaited(_refresh());
  }

  void start() {
    WidgetsBinding.instance.addObserver(this);
    NavigationTargetResolver.onStoredChange = _storedChanged;
    scheduleMicrotask(_changed);
  }

  Future<void> _refresh() async {
    if (_disposed || _refreshing || !_foreground) return;
    _refreshing = true;
    _timer?.cancel();
    var delay = const Duration(hours: 1);
    try {
      final next = await NavigationTargetResolver.purgeStored();
      if (next != null) delay = next.difference(DateTime.now());
    } catch (_) {
      // Cache I/O failure cannot trigger a provider call or wipe personal data.
      delay = const Duration(minutes: 1);
    } finally {
      _refreshing = false;
      if (!_disposed && _foreground) {
        _timer = Timer(delay.isNegative ? Duration.zero : delay, _changed);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _changed();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _timer?.cancel();
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (identical(NavigationTargetResolver.onStoredChange, _storedChanged)) {
      NavigationTargetResolver.onStoredChange = null;
    }
  }
}
