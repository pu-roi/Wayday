import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../domain/place_search.dart';
import 'search_adapters.dart';
import 'search_quota.dart';

final combinedPlaceSearchProvider = Provider<CombinedPlaceSearch>((ref) {
  final client = http.Client();
  final service = CombinedPlaceSearch([
    HttpSearchAdapter(
      client,
      'geoapify',
      apiKey: const String.fromEnvironment('GEOAPIFY_API_KEY'),
    ),
    HttpSearchAdapter(
      client,
      'locationiq',
      apiKey: const String.fromEnvironment('LOCATIONIQ_API_KEY'),
    ),
    HttpSearchAdapter(
      client,
      'photon',
      endpoint: const String.fromEnvironment(
        'WAYDAY_PLACE_SEARCH_URL',
        defaultValue: 'https://photon.komoot.io/api/',
      ),
    ),
  ], ref.read(searchQuotaLedgerProvider));
  ref.onDispose(() {
    service.dispose();
    client.close();
  });
  return service;
});

typedef SearchUpdate =
    void Function(
      String provider,
      SourceState state,
      List<PlaceSearchResult> results,
    );

class _Cache {
  _Cache(this.results, this.expires);
  final List<PlaceSearchResult> results;
  final DateTime expires;
}

class _Job {
  _Job(this.request, this.key, this.due);
  final PlaceSearchRequest request;
  final String key;
  final DateTime due;
  final Map<Object, SearchUpdate> listeners = {};
}

class _Runner {
  _Runner(this.adapter);
  final SearchAdapter adapter;
  final cache = <String, _Cache>{};
  _Job? flight, pending;
  Timer? timer;
  bool accessBlocked = false;
}

/// One instance per application. Quotas, in-flight work and cache span pickers.
class CombinedPlaceSearch {
  CombinedPlaceSearch(
    List<SearchAdapter> adapters,
    this.ledger, {
    DateTime Function()? now,
  }) : _runners = adapters.map(_Runner.new).toList(),
       now = now ?? DateTime.now;
  final List<_Runner> _runners;
  final QuotaLedger ledger;
  final DateTime Function() now;
  bool _disposed = false;
  Iterable<String> get providers => _runners.map((r) => r.adapter.id);
  void cancel(Object owner) {
    for (final r in _runners) {
      r.flight?.listeners.remove(owner);
      r.pending?.listeners.remove(owner);
      if (r.pending?.listeners.isEmpty == true) {
        r.pending = null;
        r.timer?.cancel();
      }
    }
  }

  void search(
    Object owner,
    PlaceSearchRequest request,
    SearchUpdate update, {
    bool immediate = false,
    Set<String>? only,
  }) {
    cancel(owner);
    if (_disposed) return;
    if (request.text.length > 100 ||
        (request.category == null && request.text.length < 2) ||
        (request.category != null && request.area == null)) {
      for (final runner in _runners) {
        update(
          runner.adapter.id,
          const SourceState(SourcePhase.unavailable),
          [],
        );
      }
      return;
    }
    for (final r in _runners) {
      final id = r.adapter.id;
      if (only != null && !only.contains(id)) continue;
      if (!r.adapter.enabled ||
          (request.category != null && !r.adapter.categories)) {
        update(id, const SourceState(SourcePhase.disabled), []);
        continue;
      }
      final key = '${r.adapter.endpoint}|${request.key}';
      final cached = r.cache.remove(key);
      if (cached != null && cached.expires.isAfter(now())) {
        r.cache[key] = cached;
        update(id, const SourceState(SourcePhase.complete), cached.results);
        continue;
      }
      if (r.accessBlocked) {
        update(id, const SourceState(SourcePhase.unavailable), []);
        continue;
      }
      if (r.flight?.key == key) {
        r.flight!.listeners[owner] = update;
        update(id, const SourceState(SourcePhase.loading), []);
        continue;
      }
      if (r.pending?.key == key) {
        r.pending!.listeners[owner] = update;
        update(id, const SourceState(SourcePhase.waiting), []);
        continue;
      }
      // Only the most recent pending request is retained globally per provider.
      if (r.pending != null) {
        _notify(r, r.pending!, const SourceState(SourcePhase.unavailable), []);
      }
      r.timer?.cancel();
      final job = _Job(
        request,
        key,
        now().add(
          immediate ? Duration.zero : ProviderPolicy.forId(id).debounce,
        ),
      );
      job.listeners[owner] = update;
      r.pending = job;
      update(id, const SourceState(SourcePhase.waiting), []);
      _schedule(r);
    }
  }

  void _schedule(_Runner r, [DateTime? after]) {
    if (_disposed || r.flight != null || r.pending == null) return;
    r.timer?.cancel();
    final due = after ?? r.pending!.due;
    final wait = due.difference(now());
    r.timer = Timer(wait.isNegative ? Duration.zero : wait, () => _run(r));
  }

  void _notify(
    _Runner r,
    _Job job,
    SourceState state,
    List<PlaceSearchResult> results,
  ) {
    if (_disposed) return;
    for (final listener in job.listeners.values.toList()) {
      listener(r.adapter.id, state, results);
    }
  }

  Future<void> _run(_Runner r) async {
    final job = r.pending;
    if (_disposed || job == null || r.flight != null) return;
    // Mark work in-flight while accounting is serialized, preventing double starts.
    r.pending = null;
    r.flight = job;
    final id = r.adapter.id;
    var dispatched = false;
    try {
      if (job.listeners.isEmpty) return;
      final wait = await ledger.reserve(id, ProviderPolicy.forId(id));
      if (wait != null) {
        if (r.pending == null && job.listeners.isNotEmpty) {
          r.pending = job;
        } else {
          _notify(r, job, const SourceState(SourcePhase.unavailable), []);
        }
        r.flight = null;
        _schedule(r, wait);
        return;
      }
      if (_disposed || job.listeners.isEmpty) return;
      _notify(r, job, const SourceState(SourcePhase.loading), []);
      dispatched = true;
      final results = await r.adapter
          .search(job.request)
          .timeout(const Duration(seconds: 5));
      final expires = now().add(
        results.isEmpty
            ? const Duration(seconds: 60)
            : const Duration(minutes: 15),
      );
      r.cache.remove(job.key);
      r.cache[job.key] = _Cache(results, expires);
      while (r.cache.length > 100) {
        r.cache.remove(r.cache.keys.first);
      }
      await ledger.succeeded(id);
      _notify(r, job, const SourceState(SourcePhase.complete), results);
    } catch (error) {
      final failure = error is SearchFailure
          ? error
          : const SearchFailure(SearchFailureKind.temporary);
      DateTime? until = failure.retryAt;
      if (failure.kind == SearchFailureKind.access) r.accessBlocked = true;
      // Local accounting denials already carry their saved deadline.
      if (dispatched && failure.kind != SearchFailureKind.accounting) {
        try {
          until = await ledger.failed(id, failure);
        } catch (_) {
          /* Ledger fails closed for subsequent reservations. */
        }
      }
      _notify(r, job, SourceState(SourcePhase.unavailable, retryAt: until), []);
    } finally {
      if (identical(r.flight, job)) {
        r.flight = null;
        _schedule(r);
      }
    }
  }

  void dispose() {
    _disposed = true;
    for (final r in _runners) {
      r.timer?.cancel();
      r.pending = null;
      r.flight?.listeners.clear();
      r.cache.clear();
    }
  }
}
