import 'dart:async';

/// A confirmation belongs to one movement revision and waits for its final idle.
class MapSelectionController {
  MapSelectionController({this.timeout = const Duration(seconds: 3)});
  final Duration timeout;
  int _revision = 0;
  bool _moving = false;
  (double, double)? _point;
  Completer<(double, double)>? _pending;
  int get revision => _revision;

  void begin() {
    cancel();
    _moving = true;
  }

  void settle(double latitude, double longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      cancel();
      return;
    }
    _moving = false;
    _point = (latitude, longitude);
    _pending?.complete(_point!);
    _pending = null;
  }

  void cancel() {
    _revision++;
    _moving = false;
    _point = null;
    _pending?.completeError(
      StateError('The pin changed. Confirm its new position.'),
    );
    _pending = null;
  }

  Future<(double, double)?> capture() async {
    final revision = _revision;
    if (!_moving) return _point;
    final pending = _pending ??= Completer<(double, double)>();
    try {
      final point = await pending.future.timeout(timeout);
      if (revision != _revision) {
        throw StateError('The pin changed. Confirm its new position.');
      }
      return point;
    } finally {
      if (identical(_pending, pending)) _pending = null;
    }
  }
}
