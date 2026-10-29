import 'dart:async';
import 'dart:convert';
import '../domain/place_search.dart';
import 'quota_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final searchQuotaLedgerProvider = Provider<QuotaLedger>((ref) => QuotaLedger());

class ProviderPolicy {
  const ProviderPolicy(this.spacing, this.minute, this.daily, this.debounce);
  final Duration spacing, debounce;
  final int minute, daily;
  static ProviderPolicy forId(String id) => id == 'google_ui_kit'
      ? const ProviderPolicy(
          Duration(milliseconds: 1100),
          20,
          100,
          Duration(seconds: 1),
        )
      : id == 'photon'
      ? const ProviderPolicy(
          Duration(seconds: 2),
          10,
          100,
          Duration(milliseconds: 1500),
        )
      : ProviderPolicy(
          const Duration(milliseconds: 1100),
          id == 'locationiq' ? 50 : 60,
          500,
          const Duration(milliseconds: 800),
        );
}

class QuotaLedger {
  QuotaLedger({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
    DateTime Function()? now,
  }) : read = read ?? readQuotaFile,
       write = write ?? writeQuotaFile,
       now = now ?? DateTime.now;
  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  final DateTime Function() now;
  final Map<String, List<DateTime>> _starts = {};
  final Map<String, DateTime> _cooldowns = {};
  final Map<String, int> _streaks = {};
  bool _loaded = false, _broken = false;
  Future<void> _tail = Future.value();
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _load() async {
    if (_broken) throw const SearchFailure(SearchFailureKind.accounting);
    if (_loaded) return;
    try {
      final raw = await read();
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map;
        if (decoded['version'] != 1) throw const FormatException();
        for (final entry in (decoded['starts'] as Map).entries) {
          _starts[entry.key as String] =
              (entry.value as List)
                  .map((v) => DateTime.parse(v as String).toUtc())
                  .toList()
                ..sort();
        }
        for (final entry in (decoded['cooldowns'] as Map).entries) {
          _cooldowns[entry.key as String] = DateTime.parse(
            entry.value as String,
          ).toUtc();
        }
        for (final entry in (decoded['streaks'] as Map).entries) {
          _streaks[entry.key as String] = entry.value as int;
        }
      }
      _loaded = true;
    } catch (_) {
      _broken = true;
      throw const SearchFailure(SearchFailureKind.accounting);
    }
  }

  Future<void> _save() async {
    try {
      await write(
        jsonEncode({
          'version': 1,
          'starts': _starts.map(
            (k, v) =>
                MapEntry(k, v.map((d) => d.toUtc().toIso8601String()).toList()),
          ),
          'cooldowns': _cooldowns.map(
            (k, v) => MapEntry(k, v.toUtc().toIso8601String()),
          ),
          'streaks': _streaks,
        }),
      );
    } catch (_) {
      _broken = true;
      throw const SearchFailure(SearchFailureKind.accounting);
    }
  }

  /// Null reserves a call. A future time means wait without consuming a call.
  Future<DateTime?> reserve(String id, ProviderPolicy policy) =>
      _serial(() async {
        await _load();
        final time = now().toUtc();
        final pause = _cooldowns[id];
        if (pause != null && pause.isAfter(time)) {
          throw SearchFailure(SearchFailureKind.rate, retryAt: pause);
        }
        final starts = _starts.putIfAbsent(id, () => []);
        starts.removeWhere(
          (d) => !d.isAfter(time.subtract(const Duration(hours: 24))),
        );
        if (starts.length >= policy.daily) {
          throw SearchFailure(
            SearchFailureKind.daily,
            retryAt: starts.first.add(const Duration(hours: 24)),
          );
        }
        DateTime allowed = time;
        if (starts.isNotEmpty) {
          final spaced = starts.last.add(policy.spacing);
          if (spaced.isAfter(allowed)) allowed = spaced;
        }
        final recent = starts
            .where((d) => d.isAfter(time.subtract(const Duration(minutes: 1))))
            .toList();
        if (recent.length >= policy.minute) {
          final minute = recent[recent.length - policy.minute].add(
            const Duration(minutes: 1),
          );
          if (minute.isAfter(allowed)) allowed = minute;
        }
        if (allowed.isAfter(time)) return allowed;
        starts.add(time);
        await _save();
        return null;
      });
  Future<DateTime?> failed(String id, SearchFailure error) => _serial(() async {
    await _load();
    final time = now().toUtc();
    DateTime? until;
    if (error.kind == SearchFailureKind.rate) {
      final streak = (_streaks[id] ?? 0) + 1;
      _streaks[id] = streak;
      final seconds = (60 * (1 << (streak - 1).clamp(0, 4))).clamp(60, 900);
      until = error.retryAt ?? time.add(Duration(seconds: seconds));
    } else if (error.kind == SearchFailureKind.daily) {
      until =
          error.retryAt ?? DateTime.utc(time.year, time.month, time.day + 1);
    } else if (error.kind != SearchFailureKind.access) {
      until = time.add(const Duration(seconds: 15));
    }
    if (until != null) _cooldowns[id] = until;
    await _save();
    return until;
  });
  Future<void> succeeded(String id) => _serial(() async {
    await _load();
    _streaks.remove(id);
    _cooldowns.remove(id);
    await _save();
  });
}
