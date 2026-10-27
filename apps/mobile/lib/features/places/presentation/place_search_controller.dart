import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/philippine_place_search.dart';

/// Debounces queries and runs at most one request, retaining only the latest query.
class PlaceSearchController extends ChangeNotifier {
  PlaceSearchController(this.search);
  final Future<List<PlaceSearchResult>> Function(String) search;
  String query = '';
  List<PlaceSearchResult> results = const [];
  bool loading = false, failed = false, searched = false;
  Timer? _debounce;
  bool _running = false, _queued = false, _disposed = false;
  int _revision = 0;
  final _cache = <String, List<PlaceSearchResult>>{};

  void change(String value) {
    final next = value.trim();
    if (next == query) return;
    _reset(next);
    if (query.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 600), _request);
    }
  }

  void _reset(String value) {
    _debounce?.cancel();
    _revision++;
    query = value;
    _queued = false;
    loading = false;
    failed = false;
    searched = false;
    results = const [];
    notifyListeners();
  }

  void dismiss() => _reset('');

  void submit() {
    _debounce?.cancel();
    if (!searched && !loading) _request();
  }

  void retry() {
    failed = false;
    _request();
  }

  Future<void> _request() async {
    if (_disposed || query.length < 2) return;
    if (_running) {
      _queued = true;
      return;
    }
    final value = query;
    final revision = _revision;
    if (_cache.containsKey(value)) {
      results = _cache[value]!;
      searched = true;
      failed = false;
      notifyListeners();
      return;
    }
    _running = true;
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final found = await search(value);
      if (_disposed) return;
      if (_cache.length >= 20) _cache.remove(_cache.keys.first);
      _cache[value] = found;
      if (revision == _revision) {
        results = found;
        searched = true;
      }
    } catch (_) {
      if (!_disposed && revision == _revision) failed = true;
    } finally {
      _running = false;
      if (!_disposed) {
        if (revision == _revision) loading = false;
        notifyListeners();
        if (_queued) {
          _queued = false;
          _request();
        }
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
