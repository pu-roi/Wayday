import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/place_search.dart';
import '../domain/search_terms.dart';
import '../domain/philippine_eligibility.dart';
import 'search_quota.dart';

enum SearchSource { google, others }

class SearchSourceChoice extends ChangeNotifier {
  SearchSource value = SearchSource.google;
  void choose(SearchSource source) {
    if (value != source) {
      value = source;
      notifyListeners();
    }
  }
}

final searchSourceChoiceProvider = Provider((ref) {
  final choice = SearchSourceChoice();
  ref.onDispose(choice.dispose);
  return choice;
});
final googleSearchProvider = Provider((ref) {
  final service = GoogleSearchService(
    ref.read(searchQuotaLedgerProvider),
    enabled:
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        const String.fromEnvironment('GOOGLE_MAPS_ANDROID_API_KEY').isNotEmpty,
  );
  ref.onDispose(service.dispose);
  return service;
});

abstract interface class GoogleSearchBridge {
  Future<Map<Object?, Object?>> load(GoogleNativeRequest request);
  Future<void> show(int revision);
  Future<void> cancel();
}

class GoogleNativeRequest {
  GoogleNativeRequest(this.revision, this.search, {this.placeId});
  final int revision;
  final PlaceSearchRequest search;
  final String? placeId;
  Map<String, Object?> toJson() => {
    'revision': revision,
    'query': search.providerText,
    'placeId': placeId,
    'latitude': search.origin?.latitude,
    'longitude': search.origin?.longitude,
    'brandOnly': brandOnlyQuery(search.providerText),
    'types': switch (search.category) {
      SearchCategory.marketplace => ['market'],
      SearchCategory.food => ['restaurant', 'fast_food_restaurant'],
      SearchCategory.grocery => ['supermarket', 'grocery_store'],
      SearchCategory.shop => ['store'],
      SearchCategory.convenience => ['convenience_store'],
      SearchCategory.pharmacy => ['pharmacy'],
      null => <String>[],
    },
  };
}

class GooglePlaceSnapshot {
  GooglePlaceSnapshot({
    required this.revision,
    required this.placeId,
    required this.latitude,
    required this.longitude,
    required this.countryVerified,
    required this.resolved,
    required this.retrievedAt,
  });
  factory GooglePlaceSnapshot.fromJson(
    Map<Object?, Object?> json,
    DateTime now,
  ) {
    final id = json['placeId'];
    if (id is! String || id.isEmpty || json['revision'] is! int) {
      throw const FormatException('Invalid Google selection');
    }
    final timestamp = json['retrievedAtMillis'];
    if (timestamp is! int ||
        timestamp <= 0 ||
        timestamp > now.millisecondsSinceEpoch ||
        (json['latitude'] != null && json['latitude'] is! num) ||
        (json['longitude'] != null && json['longitude'] is! num)) {
      throw const FormatException('Invalid Google selection metadata');
    }
    final lat = (json['latitude'] as num?)?.toDouble();
    final lon = (json['longitude'] as num?)?.toDouble();
    return GooglePlaceSnapshot(
      revision: json['revision'] as int,
      placeId: id,
      latitude: lat,
      longitude: lon,
      countryVerified:
          json['countryStatus'] == true ||
          (json['countryStatus'] != false && json['countryVerified'] == true) ||
          (json['countryStatus'] != false &&
              lat != null &&
              lon != null &&
              PhilippineEligibility.confirmed(lat, lon)),
      resolved: json['resolved'] == true,
      retrievedAt: DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true),
    );
  }
  final int revision;
  final String placeId;
  final double? latitude, longitude;
  final bool countryVerified, resolved;
  final DateTime retrievedAt;
  bool get valid =>
      countryVerified &&
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;
}

class _GoogleJob {
  _GoogleJob(
    this.owner,
    this.bridge,
    this.request,
    this.update,
    this.ready,
    this.due,
  );
  final DateTime due;
  final Object owner;
  final GoogleSearchBridge bridge;
  final GoogleNativeRequest request;
  final void Function(SourceState) update;
  final void Function(GoogleNativeRequest, int) ready;
}

/// Application-scoped, no Google response cache and no implicit provider fallback.
class GoogleSearchService {
  GoogleSearchService(
    this.ledger, {
    this.enabled = true,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final QuotaLedger ledger;
  final bool enabled;
  final DateTime Function() now;
  _GoogleJob? _pending, _flight;
  Timer? _timer;
  int _revision = 0;
  bool _disposed = false, _blocked = false, _checking = false;
  void cancel(Object owner) {
    if (_pending?.owner == owner) {
      _pending = null;
      _timer?.cancel();
    }
  }

  int search(
    Object owner,
    GoogleSearchBridge bridge,
    PlaceSearchRequest request,
    void Function(SourceState) update,
    void Function(GoogleNativeRequest, int) ready, {
    bool immediate = false,
    String? placeId,
  }) {
    cancel(owner);
    final native = GoogleNativeRequest(++_revision, request, placeId: placeId);
    if (!enabled || _blocked) {
      update(const SourceState(SourcePhase.disabled));
      return native.revision;
    }
    _pending = _GoogleJob(
      owner,
      bridge,
      native,
      update,
      ready,
      now().add(immediate ? Duration.zero : const Duration(seconds: 1)),
    );
    update(const SourceState(SourcePhase.waiting));
    _timer?.cancel();
    _timer = Timer(
      immediate ? Duration.zero : const Duration(seconds: 1),
      _dispatch,
    );
    return native.revision;
  }

  Future<void> _dispatch() async {
    if (_disposed || _checking || _flight != null || _pending == null) return;
    final job = _pending!;
    if (job.due.isAfter(now())) {
      _timer = Timer(job.due.difference(now()), _dispatch);
      return;
    }
    _checking = true;
    var waiting = false;
    try {
      final allowed = await ledger.reserve(
        'google_ui_kit',
        ProviderPolicy.forId('google_ui_kit'),
      );
      if (_disposed || _pending != job) return;
      if (allowed != null) {
        waiting = true;
        _timer = Timer(
          allowed.difference(now()).isNegative
              ? Duration.zero
              : allowed.difference(now()),
          _dispatch,
        );
        return;
      }
      _pending = null;
      _flight = job;
      job.update(const SourceState(SourcePhase.loading));
      final result = await job.bridge
          .load(job.request)
          .timeout(const Duration(seconds: 5));
      if (result['error'] == 'cancelled') return;
      if (result['error'] != null) {
        throw SearchFailure(switch (result['error']) {
          'access' => SearchFailureKind.access,
          'rate' => SearchFailureKind.rate,
          _ => SearchFailureKind.temporary,
        });
      }
      await ledger.succeeded('google_ui_kit');
      if (!_disposed) {
        job.ready(job.request, (result['count'] as int?) ?? 0);
        job.update(const SourceState(SourcePhase.complete));
      }
    } catch (error) {
      final failure = error is SearchFailure
          ? error
          : const SearchFailure(SearchFailureKind.temporary);
      if (failure.kind == SearchFailureKind.access) _blocked = true;
      DateTime? retry;
      try {
        retry = await ledger.failed('google_ui_kit', failure);
      } catch (_) {}
      if (_pending == job) _pending = null;
      if (!_disposed) {
        job.update(SourceState(SourcePhase.unavailable, retryAt: retry));
      }
    } finally {
      _checking = false;
      if (_flight == job) _flight = null;
      if (!_disposed && !waiting && _pending != null) {
        _timer?.cancel();
        _timer = Timer(Duration.zero, _dispatch);
      }
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _pending = null;
  }
}
