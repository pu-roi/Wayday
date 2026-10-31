import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../places/data/google_pin_cache.dart';
import '../../places/data/search_quota.dart';
import '../../places/domain/place_intent.dart';
import '../../places/domain/place_search.dart';
import '../../places/domain/search_terms.dart';
import '../domain/planning_models.dart';
import '../domain/recommendation.dart';

final recommendationDiscoveryProvider = Provider<RecommendationDiscovery>(
  (ref) => GoogleRecommendationDiscovery(
    ref.read(searchQuotaLedgerProvider),
    ref.read(googlePinCacheProvider),
  ),
);

typedef PlacesInvoker =
    Future<List<Object?>> Function(
      String method,
      Map<String, Object?> arguments,
    );

class GoogleRecommendationDiscovery
    implements
        RecommendationDiscovery,
        AlternativeDiscovery,
        HoursRefreshDiscovery {
  GoogleRecommendationDiscovery(
    this.ledger,
    this.pins, {
    PlacesInvoker? invoke,
    this.requestTimeout = const Duration(seconds: 15),
    this.coordinateSaveTimeout = const Duration(seconds: 10),
  }) : invoke = invoke ?? _native;
  final QuotaLedger ledger;
  final GooglePinCache pins;
  final PlacesInvoker invoke;
  final Duration requestTimeout;
  final Duration coordinateSaveTimeout;
  final _coordinateSaves = <String, Future<void>>{};

  Future<void> _persistCoordinates(RecommendationPlace place) async {
    final key = jsonEncode([
      place.id,
      place.latitude,
      place.longitude,
      place.acquiredAt.toIso8601String(),
    ]);
    final flight = _coordinateSaves.putIfAbsent(
      key,
      () =>
          pins.put(place.id, place.latitude, place.longitude, place.acquiredAt),
    );
    void done() {
      if (identical(_coordinateSaves[key], flight)) {
        _coordinateSaves.remove(key);
      }
    }

    unawaited(
      flight.then<void>(
        (_) => done(),
        onError: (Object _, StackTrace _) => done(),
      ),
    );
    try {
      await flight.timeout(coordinateSaveTimeout);
    } on TimeoutException {
      throw const PlanningFailure(
        'The selected place location could not finish saving. Your choices are kept.',
        kind: 'accounting',
      );
    }
  }

  static const channel = MethodChannel('wayday/recommendations');
  static Future<List<Object?>> _native(
    String method,
    Map<String, Object?> args,
  ) async {
    final raw = await channel.invokeMethod<Object?>(method, args);
    if (raw is! List) throw const FormatException('Invalid place response');
    return raw.cast<Object?>();
  }

  final _waiters = <String, List<bool Function()>>{};
  final _pending = <String, Future<_PlaceBatch>>{};
  final _cache = <String, ({DateTime at, _PlaceBatch values})>{};
  final _places = <String, RecommendationPlace>{};
  final _failedHours = <String>{};

  @override
  BusinessHours hoursStatus(PlaceIntent place) =>
      _failedHours.contains(place.providerPlaceId)
      ? const BusinessHours(failed: true)
      : metadata(place)?.hours ?? const BusinessHours();

  @override
  RecommendationPlace? metadata(PlaceIntent place) =>
      _places[place.providerPlaceId];

  @override
  Future<void> preflight(int maximumRequests) async {
    try {
      await ledger.checkCapacity(
        'google_ui_kit',
        maximumRequests,
        ProviderPolicy.forId('google_ui_kit'),
      );
      if (maximumRequests > 0) {
        await ledger.googleBudget?.google(
          'places_35000',
          maximumRequests,
          35000,
          checkOnly: true,
        );
      }
    } on SearchFailure catch (e) {
      throw RecommendationFailure(
        e.kind == SearchFailureKind.accounting
            ? RecommendationFailureKind.accounting
            : RecommendationFailureKind.quota,
        RecommendationOperation.configuration,
      );
    }
  }

  Future<_PlaceBatch> _request(
    String method,
    Map<String, Object?> args, {
    bool Function()? cancelled,
  }) async {
    final key = jsonEncode([1, method, args]); // Requested hours field profile.
    final saved = _cache[key];
    if (saved != null &&
        DateTime.now().difference(saved.at) < const Duration(minutes: 5)) {
      return saved.values;
    }
    final watcher = cancelled ?? () => false;
    final waiters = _waiters.putIfAbsent(key, () => []);
    waiters.add(watcher);
    void check() {
      if (!waiters.any((cancelled) => !cancelled())) {
        throw const PlanningFailure(
          'Recommendation search cancelled.',
          kind: 'cancelled',
        );
      }
    }

    final future =
        _pending[key] ??
        () async {
          var reserved = false, dispatched = false;
          try {
            while (true) {
              check();
              // Shared with the existing picker: SDK discovery cannot bypass its limits.
              final wait = await ledger.reserve(
                'google_ui_kit',
                ProviderPolicy.forId('google_ui_kit'),
                googleUnitMicros: method == 'details' ? 20000 : 35000,
              );
              if (wait == null) {
                reserved = true;
                break;
              }
              await Future<void>.delayed(
                wait.difference(DateTime.now()).isNegative
                    ? Duration.zero
                    : wait.difference(DateTime.now()),
              );
            }
            check();
            dispatched = true;
            final raw = await invoke(method, args);
            if (raw.length > 10) {
              throw const FormatException('Unbounded place response');
            }
            final values = <RecommendationPlace>[];
            final exclusions = <PlaceExclusion, int>{};
            void exclude(PlaceExclusion reason) =>
                exclusions.update(reason, (n) => n + 1, ifAbsent: () => 1);
            for (final record in raw) {
              try {
                final place = RecommendationPlace.fromJson(
                  Map<Object?, Object?>.from(record as Map),
                );
                final reason = !place.countryEligible
                    ? PlaceExclusion.country
                    : method == 'details'
                    ? null
                    : place.name.isEmpty
                    ? PlaceExclusion.missingName
                    : {
                        'CLOSED_PERMANENTLY',
                        'CLOSED_TEMPORARILY',
                      }.contains(place.status)
                    ? PlaceExclusion.closed
                    : !place.eligible
                    ? PlaceExclusion.addressOnly
                    : null;
                if (reason == null) {
                  values.add(place);
                } else {
                  exclude(reason);
                }
              } catch (_) {
                exclude(PlaceExclusion.malformed);
              }
            }
            final batch = _PlaceBatch(values, raw.length, exclusions);
            for (final p in values) {
              _places[p.id] = p;
              _failedHours.remove(p.id);
            }
            while (_places.length > 240) {
              _places.remove(_places.keys.first);
            }
            while (_cache.length >= 32) {
              _cache.remove(_cache.keys.first);
            }
            await ledger.succeeded('google_ui_kit');
            _cache[key] = (at: DateTime.now(), values: batch);
            return batch;
          } on PlanningFailure {
            if (reserved && !dispatched) {
              final rate = method == 'details' ? 20000 : 35000;
              await ledger.googleBudget?.google(
                'places_$rate',
                1,
                rate,
                release: true,
              );
            }
            rethrow;
          } on SearchFailure catch (e) {
            throw RecommendationFailure(
              e.kind == SearchFailureKind.accounting
                  ? RecommendationFailureKind.accounting
                  : RecommendationFailureKind.quota,
              _operation(method, args),
            );
          } on PlatformException catch (e) {
            if (e.code == 'not_found') {
              return _PlaceBatch([], 0, {});
            }
            final status = e.details is Map
                ? (e.details as Map)['status']
                : null;
            final cause = switch (e.code) {
              'configuration' => RecommendationFailureKind.configuration,
              'access' => RecommendationFailureKind.access,
              'quota' => RecommendationFailureKind.quota,
              'invalid_request' => RecommendationFailureKind.invalidRequest,
              'network' => RecommendationFailureKind.network,
              'timeout' => RecommendationFailureKind.timeout,
              'cancelled' => RecommendationFailureKind.cancelled,
              _ => RecommendationFailureKind.unavailable,
            };
            throw RecommendationFailure(
              cause,
              _operation(method, args),
              providerStatus: status is int ? status : null,
            );
          } on MissingPluginException {
            throw RecommendationFailure(
              RecommendationFailureKind.configuration,
              _operation(method, args),
            );
          } on FormatException {
            throw RecommendationFailure(
              RecommendationFailureKind.unexpectedResponse,
              _operation(method, args),
            );
          } catch (_) {
            throw RecommendationFailure(
              RecommendationFailureKind.unexpectedResponse,
              _operation(method, args),
            );
          }
        }();
    _pending[key] = future;
    void completed() {
      if (identical(_pending[key], future)) _pending.remove(key);
      if (waiters.isEmpty) _waiters.remove(key);
    }

    // A caller timeout must not detach the still-running provider request.
    // A subsequent explicit retry attaches until native completion/cancellation.
    unawaited(
      future.then<void>((_) => completed(), onError: (Object _) => completed()),
    );
    try {
      return await future.timeout(requestTimeout);
    } on TimeoutException {
      throw RecommendationFailure(
        RecommendationFailureKind.timeout,
        _operation(method, args),
      );
    } on RecommendationFailure catch (failure) {
      if (kDebugMode) {
        debugPrint(
          'WaydayRecommendations operation=${failure.operation.name} kind=${failure.kind} status=${failure.providerStatus}',
        );
      }
      rethrow;
    } finally {
      waiters.remove(watcher);
      if (waiters.isEmpty && !_pending.containsKey(key)) _waiters.remove(key);
    }
  }

  RecommendationOperation _operation(
    String method,
    Map<String, Object?> args,
  ) => method == 'details'
      ? RecommendationOperation.refresh
      : args.containsKey('polyline')
      ? RecommendationOperation.corridor
      : RecommendationOperation.anchor;

  @override
  Future<RecommendationPlace?> retryHours(PlaceIntent place) async {
    final id = place.providerPlaceId;
    _cache.remove(
      jsonEncode([
        1,
        'details',
        {'id': id},
      ]),
    );
    final previous = metadata(place);
    if (previous != null) {
      _places[previous.id] = previous.withHours(previous.hours.failure());
    }
    return hydrate(place);
  }

  @override
  Future<RecommendationPlace?> hydrate(
    PlaceIntent place, {
    bool Function()? cancelled,
  }) async {
    if (!place.isGoogle) return null;
    final current = metadata(place);
    if (current != null &&
        current.hours.checked &&
        place.hasCoordinates &&
        DateTime.now().difference(current.acquiredAt) <
            const Duration(minutes: 5)) {
      return current;
    }
    try {
      final batch = await _request('details', {
        'id': place.providerPlaceId,
      }, cancelled: cancelled);
      final values = batch.places;
      if (values.isEmpty || values.single.id != place.providerPlaceId) {
        throw const PlanningFailure(
          'This selected Google place could not be refreshed. Choose its actual location.',
          kind: 'missing_location',
        );
      }
      final value = values.single;
      await _persistCoordinates(value);
      _failedHours.remove(value.id);
      return value;
    } catch (_) {
      _failedHours.add(place.providerPlaceId!);
      if (current != null) {
        _places[current.id] = current.withHours(current.hours.failure());
      }
      rethrow;
    }
  }

  @override
  Future<DiscoveryResult> discover(
    ErrandNeed need, {
    required String? polyline,
    required List<PlaceIntent> anchors,
    required int limit,
    required bool Function() cancelled,
    HoursQuery? hours,
  }) async => (await _collect(
    need,
    polyline: polyline,
    anchors: anchors,
    limit: limit,
    cancelled: cancelled,
    hours: hours,
  )).result;

  @override
  Future<AlternativeBatch> moreAlternatives(
    ErrandNeed need, {
    required String? polyline,
    required List<PlaceIntent> anchors,
    required Set<String> excludedKeys,
    required int limit,
    required bool Function() cancelled,
    HoursQuery? hours,
  }) async {
    final batch = await _collect(
      need,
      polyline: polyline,
      anchors: anchors,
      limit: limit,
      excludedKeys: excludedKeys,
      browsing: true,
      cancelled: cancelled,
      hours: hours,
    );
    return AlternativeBatch(
      batch.result.candidates,
      exhausted: batch.exhausted,
    );
  }

  Future<({DiscoveryResult result, bool exhausted})> _collect(
    ErrandNeed need, {
    required String? polyline,
    required List<PlaceIntent> anchors,
    required int limit,
    required bool Function() cancelled,
    Set<String> excludedKeys = const {},
    bool browsing = false,
    HoursQuery? hours,
  }) async {
    void check() {
      if (cancelled()) {
        throw const PlanningFailure(
          'Recommendation search cancelled.',
          kind: 'cancelled',
        );
      }
    }

    check();
    final pool = <String, RecommendationPlace>{};
    final exclusions = <PlaceExclusion, int>{};
    var returnedCount = 0, contextsEvaluated = 0;
    void exclude(PlaceExclusion reason, [int count = 1]) =>
        exclusions.update(reason, (n) => n + count, ifAbsent: () => count);
    final contexts = <Map<String, Object?>>[
      if (polyline != null) {'query': need.query, 'polyline': polyline},
      for (final p in anchors.where((p) => p.hasCoordinates).take(2))
        {'query': need.query, 'latitude': p.latitude, 'longitude': p.longitude},
    ];
    bool cached(Map<String, Object?> context) {
      final saved = _cache[jsonEncode([1, 'search', context])];
      return saved != null &&
          DateTime.now().difference(saved.at) < const Duration(minutes: 5);
    }

    final searches = browsing
        ? [...contexts.where(cached), ...contexts.where((c) => !cached(c))]
        : contexts;
    final seen = <String>{};
    for (final context in searches) {
      check();
      if (!seen.add(jsonEncode(context))) continue;
      final brand = brandSearchTerm(need.query)?.brand;
      final batch = await _request('search', context, cancelled: cancelled);
      contextsEvaluated++;
      returnedCount += batch.returnedCount;
      batch.exclusions.forEach(exclude);
      for (final p in batch.places) {
        if (hours != null && !hours.permits(p.hours)) {
          exclude(PlaceExclusion.hours);
          continue;
        }
        if (brand != null &&
            !brand.landmark &&
            brandSearchTerm(p.name)?.brand.name != brand.name) {
          exclude(PlaceExclusion.brand);
          continue;
        }
        final types = switch (need.category) {
          'grocery' => {
            'supermarket',
            'grocery_store',
            'market',
            'convenience_store',
            'discount_store',
            'food_store',
          },
          'pharmacy' => {'pharmacy', 'drugstore'},
          'marketplace' => {
            'market',
            'farmers_market',
            'supermarket',
            'grocery_store',
          },
          _ => <String>{},
        };
        if (types.isNotEmpty && !p.types.any(types.contains)) {
          exclude(PlaceExclusion.category);
          continue;
        }
        if (pool.containsKey(p.id)) exclude(PlaceExclusion.duplicate);
        if (excludedKeys.contains('google:${p.id}')) continue;
        pool[p.id] = p;
      }
      check();
      if (pool.length >= limit && (browsing || polyline != null)) {
        break;
      }
    }
    // Retain candidates from different route anchors, rather than only the start.
    final ranked = pool.values.toList();
    double cost(RecommendationPlace p) {
      if (anchors.isEmpty) return 0;
      final a = anchors.first, b = anchors.last;
      return distanceMeters(
            a.latitude!,
            a.longitude!,
            p.latitude,
            p.longitude,
          ) +
          distanceMeters(p.latitude, p.longitude, b.latitude!, b.longitude!);
    }

    ranked.sort((a, b) => cost(a).compareTo(cost(b)));
    final chosen = <RecommendationPlace>[];
    if (ranked.isNotEmpty) chosen.add(ranked.first);
    for (final anchor in anchors.reversed) {
      if (chosen.length >= limit) break;
      final remaining = ranked.where((p) => !chosen.contains(p)).toList()
        ..sort(
          (a, b) =>
              distanceMeters(
                anchor.latitude!,
                anchor.longitude!,
                a.latitude,
                a.longitude,
              ).compareTo(
                distanceMeters(
                  anchor.latitude!,
                  anchor.longitude!,
                  b.latitude,
                  b.longitude,
                ),
              ),
        );
      if (remaining.isNotEmpty) chosen.add(remaining.first);
    }
    for (final p in ranked) {
      if (chosen.length < limit && !chosen.contains(p)) chosen.add(p);
    }
    final result = <PlanCandidate>[];
    for (final p in chosen) {
      check();
      await _persistCoordinates(p);
      final place = p.reference(pins.lease(p.id));
      result.add(
        PlanCandidate(
          key: placeKey(place),
          place: place,
          errandIds: {need.id},
          reason: 'Matches your request; compared within this trip.',
        ),
      );
    }
    final report = DiscoveryResult(
      result,
      returnedCount: returnedCount,
      contextsEvaluated: contextsEvaluated,
      exclusions: exclusions,
    );
    if (kDebugMode) {
      debugPrint(
        'WaydayRecommendations outcome=${report.outcome.name} returned=${report.returnedCount} candidates=${report.candidates.length} exclusions=${report.exclusions.map((key, value) => MapEntry(key.name, value))}',
      );
    }
    return (
      result: report,
      exhausted:
          pool.length <= limit &&
          seen.length == contexts.map(jsonEncode).toSet().length,
    );
  }
}

class _PlaceBatch {
  _PlaceBatch(this.places, this.returnedCount, this.exclusions);
  final List<RecommendationPlace> places;
  final int returnedCount;
  final Map<PlaceExclusion, int> exclusions;
}
