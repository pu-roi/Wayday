import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/local_repositories.dart';
import '../domain/place_intent.dart';
import 'google_pin_storage_stub.dart'
    if (dart.library.io) 'google_pin_storage_native.dart'
    as storage;

final googlePinCacheProvider = Provider<GooglePinCache>((ref) {
  final existing = ref.watch(localRepositoriesProvider)?.googlePins;
  if (existing != null) {
    existing.observeLifecycle();
    return existing;
  }
  final cache = GooglePinCache()..observeLifecycle();
  ref.onDispose(cache.dispose);
  return cache;
});

/// Android cacheDir is private and excluded from both backup and device transfer.
/// Only this file contains temporary Google coordinates; application records keep IDs.
class GooglePinCache extends ChangeNotifier with WidgetsBindingObserver {
  GooglePinCache({
    DateTime Function()? now,
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
  }) : now = now ?? DateTime.now,
       read = read ?? storage.readPins,
       write = write ?? storage.writePins;
  bool _observing = false, _disposed = false;
  void observeLifecycle() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  final DateTime Function() now;
  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  final Map<String, GooglePinLease> _pins = {};
  Timer? _expiry;
  Future<void> _tail = Future.value();
  GooglePinLease lease(String id) {
    final pin = _pins.putIfAbsent(id, () => GooglePinLease(now: now));
    if (pin.acquiredAt != null && !pin.valid) {
      pin.clear();
      unawaited(_save().catchError((Object _) {}));
    }
    return pin;
  }

  Future<void> load() async {
    try {
      final raw = await read();
      if (_disposed) return;
      if (raw != null) {
        for (final entry in (jsonDecode(raw) as Map).entries) {
          final data = entry.value as Map;
          final pin = lease(entry.key as String);
          pin.acquiredAt = DateTime.parse(data['at'] as String).toUtc();
          pin.latitude = (data['lat'] as num).toDouble();
          pin.longitude = (data['lon'] as num).toDouble();
          if (!pin.latitude!.isFinite ||
              pin.latitude!.abs() > 90 ||
              !pin.longitude!.isFinite ||
              pin.longitude!.abs() > 180) {
            pin.clear();
          }
        }
      }
    } catch (_) {
      for (final pin in _pins.values) {
        pin.clear();
      }
    }
    await purge();
  }

  Future<void> put(String id, double lat, double lon, DateTime acquired) async {
    if (_disposed) throw StateError('Google pin cache is closed');
    if (id.isEmpty ||
        !lat.isFinite ||
        lat.abs() > 90 ||
        !lon.isFinite ||
        lon.abs() > 180 ||
        acquired.isAfter(now()) ||
        !now().isBefore(acquired.add(const Duration(days: 30)))) {
      throw const FormatException('Invalid Google coordinate lease');
    }
    final pin = lease(id);
    pin.latitude = lat;
    pin.longitude = lon;
    pin.acquiredAt = acquired.toUtc();
    try {
      await _save();
    } catch (_) {
      pin.clear();
      rethrow;
    }
    if (!_disposed) {
      _schedule();
      notifyListeners();
    }
  }

  Future<void> purge() async {
    if (_disposed) return;
    for (final pin in _pins.values) {
      if (!pin.valid) pin.clear();
    }
    try {
      await _save();
    } catch (_) {
      /* Expired memory leases remain revoked. */
    }
    if (!_disposed) {
      _schedule();
      notifyListeners();
    }
  }

  Future<void> _save() {
    final result = _tail.then(
      (_) => write(
        jsonEncode({
          for (final entry in _pins.entries)
            if (entry.value.valid)
              entry.key: {
                'at': entry.value.acquiredAt!.toIso8601String(),
                'lat': entry.value.latitude,
                'lon': entry.value.longitude,
              },
        }),
      ),
    );
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _schedule() {
    _expiry?.cancel();
    final dates =
        _pins.values
            .where((p) => p.valid)
            .map((p) => p.acquiredAt!.add(const Duration(days: 30)))
            .toList()
          ..sort();
    if (dates.isNotEmpty) _expiry = Timer(dates.first.difference(now()), purge);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) purge();
  }

  @override
  void dispose() {
    _disposed = true;
    _expiry?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
