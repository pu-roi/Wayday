import 'dart:convert';
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

class GoogleRecommendationDiscovery implements RecommendationDiscovery {
  GoogleRecommendationDiscovery(this.ledger, this.pins, {PlacesInvoker? invoke})
    : invoke = invoke ?? _native;
  final QuotaLedger ledger;
  final GooglePinCache pins;
  final PlacesInvoker invoke;
  static const channel = MethodChannel('wayday/recommendations');
  static Future<List<Object?>> _native(
    String method,
    Map<String, Object?> args,
  ) async =>
      await channel
          .invokeListMethod<Object?>(method, args)
          .timeout(const Duration(seconds: 15)) ??
      [];
  final _waiters = <String, List<bool Function()>>{};
  final _pending = <String, Future<List<RecommendationPlace>>>{};
  final _cache = <String, ({DateTime at, List<RecommendationPlace> values})>{};
  final _places = <String, RecommendationPlace>{};

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
    } on SearchFailure {
      throw const PlanningFailure(
        'There is not enough Google search capacity for this recommendation batch. Your choices are kept.',
        kind: 'quota',
      );
    }
  }

  Future<List<RecommendationPlace>> _request(
    String method,
    Map<String, Object?> args, {
    bool Function()? cancelled,
  }) async {
    final key = jsonEncode([method, args]);
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
          try {
            while (true) {
              check();
              // Shared with the existing picker: SDK discovery cannot bypass its limits.
              final wait = await ledger.reserve(
                'google_ui_kit',
                ProviderPolicy.forId('google_ui_kit'),
              );
              if (wait == null) break;
              await Future<void>.delayed(
                wait.difference(DateTime.now()).isNegative
                    ? Duration.zero
                    : wait.difference(DateTime.now()),
              );
            }
            check();
            final raw = await invoke(method, args);
            if (raw.length > 10) {
              throw const FormatException('Unbounded place response');
            }
            final values = <RecommendationPlace>[];
            for (final record in raw) {
              try {
                final place = RecommendationPlace.fromJson(
                  Map<Object?, Object?>.from(record as Map),
                );
                if (method == 'details'
                    ? place.countryEligible
                    : place.eligible) {
                  values.add(place);
                }
              } on FormatException {
                /* A malformed record is not a candidate. */
              }
            }
            for (final p in values) {
              _places[p.id] = p;
            }
            while (_places.length > 240) {
              _places.remove(_places.keys.first);
            }
            while (_cache.length >= 32) {
              _cache.remove(_cache.keys.first);
            }
            _cache[key] = (at: DateTime.now(), values: values);
            await ledger.succeeded('google_ui_kit');
            return values;
          } on PlanningFailure {
            rethrow;
          } on SearchFailure catch (e) {
            throw PlanningFailure(
              e.kind == SearchFailureKind.accounting
                  ? 'Place search accounting could not be saved.'
                  : 'Google place search capacity is unavailable. Your choices are kept.',
              kind: e.kind == SearchFailureKind.accounting
                  ? 'accounting'
                  : 'quota',
            );
          } catch (_) {
            throw const PlanningFailure(
              'Place recommendations are unavailable. Your choices are kept; retry or search for a place.',
              kind: 'places_unavailable',
            );
          }
        }();
    _pending[key] = future;
    try {
      return await future;
    } finally {
      waiters.remove(watcher);
      if (waiters.isEmpty) {
        _waiters.remove(key);
        _pending.remove(key);
      }
    }
  }

  @override
  Future<RecommendationPlace?> hydrate(
    PlaceIntent place, {
    bool Function()? cancelled,
  }) async {
    if (!place.isGoogle) return null;
    final current = metadata(place);
    if (current != null &&
        place.hasCoordinates &&
        DateTime.now().difference(current.acquiredAt) <
            const Duration(minutes: 5)) {
      return current;
    }
    final values = await _request('details', {
      'id': place.providerPlaceId,
    }, cancelled: cancelled);
    if (values.isEmpty || values.single.id != place.providerPlaceId) {
      throw const PlanningFailure(
        'This selected Google place could not be refreshed. Choose its actual location.',
        kind: 'missing_location',
      );
    }
    final value = values.single;
    await pins.put(value.id, value.latitude, value.longitude, value.acquiredAt);
    return value;
  }

  @override
  Future<List<PlanCandidate>> discover(
    ErrandNeed need, {
    required String? polyline,
    required List<PlaceIntent> anchors,
    required int limit,
    required bool Function() cancelled,
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
    final contexts = <Map<String, Object?>>[
      if (polyline != null) {'query': need.query, 'polyline': polyline},
      for (final p in anchors.where((p) => p.hasCoordinates).take(2))
        {'query': need.query, 'latitude': p.latitude, 'longitude': p.longitude},
    ];
    final seen = <String>{};
    for (final context in contexts) {
      check();
      if (!seen.add(jsonEncode(context))) continue;
      final brand = brandSearchTerm(need.query)?.brand;
      for (final p in await _request('search', context, cancelled: cancelled)) {
        if (brand != null &&
            !brand.landmark &&
            brandSearchTerm(p.name)?.brand.name != brand.name) {
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
        if (types.isNotEmpty && !p.types.any(types.contains)) continue;
        pool[p.id] = p;
      }
      check();
      if (pool.length >= limit && polyline != null) break;
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
      await pins.put(p.id, p.latitude, p.longitude, p.acquiredAt);
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
    return result;
  }
}
