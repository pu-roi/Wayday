import 'package:flutter/foundation.dart';
import '../data/combined_place_search.dart';
import '../domain/place_search.dart';
import '../domain/search_ranking.dart';
import '../domain/search_terms.dart';
import '../domain/place_intent.dart';
import '../data/google_search.dart';
import '../data/google_pin_cache.dart';

/// Presentation state lives only for the currently open picker session.
class _SourceSession {
  List<PlaceSearchResult> results = [];
  final Map<String, SourceState> sources = {};
  final Map<String, List<PlaceSearchResult>> batches = {};
  bool started = false, frozen = false;
  String? requestKey;
  PlaceSearchRequest? request;
  List<PlaceSearchResult>? staged;
  SearchOrigin? visibleOrigin;
}

class PlaceSearchController extends ChangeNotifier {
  PlaceSearchController(
    this.service, {
    this.google,
    this.sourceChoice,
    this.pins,
  }) {
    _previousSource = source;
    sourceChoice?.addListener(_sourceChanged);
  }
  final GoogleSearchService? google;
  final SearchSourceChoice? sourceChoice;
  final GooglePinCache? pins;
  GoogleSearchBridge? _bridge;
  GoogleNativeRequest? _googleVisible, _googleStaged;
  int? _googlePending;
  int _googleCount = 0, _googleStagedCount = 0;
  final _googleBatches = <int,List<GooglePlaceSnapshot>>{};
  List<GooglePlaceSnapshot> get googleCandidates =>
      List.unmodifiable(_googleBatches[_googleVisible?.revision] ?? const []);
  bool get googleCandidatesCurrent => _googleVisible?.search.key==_request().key && !hasUpdates;
  String get googleCandidateQuery => _googleVisible?.search.text ?? query;
  void receiveGoogleBatch(int revision, List<GooglePlaceSnapshot> values) {
    if (_disposed || _suspended || !_open) return;
    _googleBatches[revision] = values;
    // Retain only current native presentation work; never a durable catalog.
    _googleBatches.removeWhere((key, _) => key != revision && key != _googleVisible?.revision);
  }
  String? _resolvingId;
  bool _detailsStarted = false;
  bool _selecting = false;
  bool _original = false;
  String? _suggested;
  ValueChanged<PlaceIntent>? onGoogleSelection;
  String? googleMessage;
  SearchSource get source => sourceChoice?.value ?? SearchSource.others;
  bool get usesGoogle => source == SearchSource.google;
  bool get googleSupported => google?.enabled == true;
  SearchInterpretation? _interpreted;
  String? _interpretationKey;
  SearchInterpretation get interpretation {
    final text = _suggested ?? query;
    final key = '$text|$_original';
    if (_interpretationKey != key) {
      _interpretationKey = key;
      _interpreted = interpretSearch(text, useOriginal: _original);
    }
    return _interpreted!;
  }

  String get interpretedText => interpretation.providerText;
  void chooseSource(SearchSource value) => sourceChoice?.choose(value);
  SearchSource _previousSource = SearchSource.google;
  bool _open = false;
  bool _submitted = false;
  final _sessions = {
    for (final source in SearchSource.values) source: _SourceSession(),
  };
  _SourceSession get _state => _sessions[source]!;
  _SourceSession get _googleState => _sessions[SearchSource.google]!;
  void open() => _open = true;
  void _sourceChanged() {
    if (_previousSource == SearchSource.google) {
      google?.cancel(_owner);
      // A selection-resolution callback must never commit while its source is
      // hidden. Keep the original search cards available for another selection.
      if (_resolvingId != null) {
        _resolvingId = null;
        _detailsStarted = false;
        _googleState.sources['google_ui_kit'] = SourceState(
          _googleVisible == null
              ? SourcePhase.unavailable
              : SourcePhase.complete,
        );
      }
    } else {
      service.pausePending(_owner);
    }
    _previousSource = source;
    if (!_open || _disposed) return;
    // Completed and failed sessions stay intact. Only paused work resumes.
    final pending = sources.entries
        .where((entry) => entry.value.phase == SourcePhase.waiting)
        .map((entry) => entry.key)
        .toSet();
    _suspended = false;
    if (!_started &&
        (category != null ||
            query.length >= 3 ||
            (_submitted && query.length >= 2)) &&
        !needsLocalArea) {
      _launch(immediate: true);
    } else if (pending.isNotEmpty) {
      _launch(immediate: true, only: pending);
    }
    notifyListeners();
  }

  void attachGoogle(GoogleSearchBridge bridge) {
    _bridge = bridge;
    if (usesGoogle && _started && !_suspended && _googlePending == null) {
      _launch();
    }
  }

  void detachGoogle(GoogleSearchBridge bridge) {
    if (_bridge == bridge) {
      google?.cancel(_owner);
      _bridge = null;
      _googlePending = null;
      _googleVisible = null;
    }
  }

  void _clearGoogle() {
    _googleBatches.clear();
    google?.cancel(_owner);
    _bridge?.cancel();
    _googlePending = null;
    _googleVisible = null;
    _googleStaged = null;
    _resolvingId = null;
    _detailsStarted = false;
    _googleCount = 0;
    googleMessage = null;
  }

  void searchOriginal() {
    _original = true;
    _suggested = null;
    _clearGoogle();
    _newOriginSearch();
  }

  void chooseSuggestion(String text) {
    _suggested = text;
    _original = false;
    _clearGoogle();
    _newOriginSearch();
  }

  Future<void> googleSelected(GooglePlaceSnapshot snapshot) async {
    if (_disposed || !usesGoogle || _suspended || _selecting) return;
    final visible = _googleVisible;
    final resolving =
        snapshot.resolved &&
        snapshot.revision == _googlePending &&
        snapshot.placeId == _resolvingId;
    if (snapshot.resolved && !resolving) return;
    if (!resolving && snapshot.revision != visible?.revision) return;
    if (!snapshot.valid) {
      if (!snapshot.resolved && _resolvingId == null) {
        _resolvingId = snapshot.placeId;
        _loadGoogleDetails(snapshot.placeId);
      } else {
        googleMessage =
            'This place’s Philippine location could not be verified. Choose another result or use Other sources.';
        notifyListeners();
      }
      return;
    }
    final revision = _revision;
    final label = query;
    _selecting = true;
    try {
      await pins!.put(
        snapshot.placeId,
        snapshot.latitude!,
        snapshot.longitude!,
        snapshot.retrievedAt,
      );
      if (_disposed || revision != _revision || !usesGoogle || _suspended) {
        return;
      }
      onGoogleSelection?.call(
        PlaceIntent(
          kind: PlaceKind.providerReference,
          label: label.isEmpty ? 'My place' : label,
          provider: 'google_ui_kit',
          providerPlaceId: snapshot.placeId,
          source: 'google_ui_kit',
          googlePin: pins!.lease(snapshot.placeId),
          attributions: const ['Google Maps'],
        ),
      );
    } catch (_) {
      if (!_disposed) {
        googleMessage = 'The temporary pin could not be stored. Try again.';
        notifyListeners();
      }
    } finally {
      _selecting = false;
    }
  }

  void refreshGoogleReference(PlaceIntent place) {
    if (!place.isGoogle || place.providerPlaceId == null) return;
    _open = true;
    service.cancel(_owner);
    _clearGoogle();
    _revision++;
    _invalidateSessions();
    // Source activation must not first schedule an unrelated named search.
    query = '';
    chooseSource(SearchSource.google);
    query = place.label;
    _resolvingId = place.providerPlaceId;
    _activeRequest = PlaceSearchRequest(query, origin: origin);
    _started = true;
    if (_bridge != null) _loadGoogleDetails(place.providerPlaceId!);
  }

  void _loadGoogleDetails(String id) {
    if (_detailsStarted) return;
    if (_bridge == null) return;
    _detailsStarted = true;
    _launchGoogle(
      _activeRequest ?? PlaceSearchRequest(query, origin: origin),
      immediate: true,
      placeId: id,
    );
  }

  void _launchGoogle(
    PlaceSearchRequest request, {
    bool immediate = false,
    String? placeId,
  }) {
    final session = _googleState;
    final bridge = _bridge;
    if (bridge == null) {
      sources['google_ui_kit'] = SourceState(
        googleSupported ? SourcePhase.waiting : SourcePhase.disabled,
      );
      notifyListeners();
      return;
    }
    final revision = _revision;
    _googlePending = google!.search(
      _owner,
      bridge,
      request,
      (state) {
        if (_disposed ||
            revision != _revision ||
            !_open ||
            _suspended ||
            (placeId != null && _resolvingId != placeId)) {
          return;
        }
        session.sources['google_ui_kit'] = state;
        notifyListeners();
      },
      (native, count) {
        if (_disposed ||
            revision != _revision ||
            !_open ||
            _suspended ||
            (placeId != null && _resolvingId != placeId)) {
          return;
        }
        if (session.frozen && _googleVisible != null && placeId == null) {
          _googleStaged = native;
          _googleStagedCount = count;
        } else {
          _googleCount = count;
          _googleVisible = native;
          bridge.show(native.revision);
        }
        notifyListeners();
      },
      immediate: immediate,
      placeId: placeId,
    );
  }

  final CombinedPlaceSearch service;
  final Object _owner = Object();
  String query = '';
  List<PlaceSearchResult> get results => _state.results;
  set results(List<PlaceSearchResult> value) => _state.results = value;
  Map<String, SourceState> get sources => _state.sources;
  SearchArea? _area;
  SearchCategory? category;
  bool _disposed = false, _suspended = false;
  bool get _started => _state.started;
  set _started(bool value) => _state.started = value;
  int _revision = 0;
  int _contextRevision = 0;
  int get contextRevision => _contextRevision;
  String? get _requestKey => _state.requestKey;
  set _requestKey(String? value) => _state.requestKey = value;
  PlaceSearchRequest? get _activeRequest => _state.request;
  set _activeRequest(PlaceSearchRequest? value) => _state.request = value;
  Map<String, List<PlaceSearchResult>> get _batches => _state.batches;
  SearchOrigin? _device;
  SearchOrigin? _selectedArea;
  bool _areaSelected = false, _replacementUsed = false;
  set _frozen(bool value) => _state.frozen = value;
  List<PlaceSearchResult>? get _staged => _state.staged;
  set _staged(List<PlaceSearchResult>? value) => _state.staged = value;
  SearchOrigin? get _visibleOrigin => _state.visibleOrigin;
  SearchOrigin? get origin => _areaSelected ? _selectedArea : _device;
  SearchOrigin? get visibleOrigin => _visibleOrigin;
  String get originLabel => origin?.label ?? 'Philippines';
  bool get hasUpdates => usesGoogle ? _googleStaged != null : _staged != null;
  bool get nearMe => !_areaSelected && _device != null;
  void freezeResults() {
    _frozen = true;
  }

  void applyUpdates() {
    _frozen = false;
    final native = usesGoogle ? _googleStaged : null;
    if (native != null) {
      _googleVisible = native;
      _googleCount = _googleStagedCount;
      _googleStaged = null;
      _bridge?.show(native.revision);
    }
    _publish();
    notifyListeners();
  }

  void _resetRanking() {
    _frozen = false;
    _staged = null;
    _replacementUsed = false;
    _batches.clear();
  }

  void useNearMe() {
    if (!_areaSelected) return;
    _areaSelected = false;
    _selectedArea = null;
    _newOriginSearch();
  }

  void _newOriginSearch() {
    service.cancel(_owner);
    _clearGoogle();
    _revision++;
    _invalidateSessions();
    _resetRanking();
    results = [];
    sources.clear();
    _started = false;
    if ((category != null || query.length >= 2) && !needsLocalArea) {
      _launch(immediate: true);
    } else {
      notifyListeners();
    }
  }

  void updateDeviceLocation(SearchOrigin? value) {
    final previous = _device;
    _device = value;
    if (_resolvingId != null || _selecting) {
      notifyListeners();
      return;
    }
    if (_areaSelected) {
      notifyListeners();
      return;
    }
    final active = _activeRequest;
    final moved =
        value != null &&
        (active?.origin == null ||
            distanceMeters(
                  active!.origin!.latitude,
                  active.origin!.longitude,
                  value.latitude,
                  value.longitude,
                ) >=
                250);
    if (_started &&
        !_suspended &&
        value != null &&
        moved &&
        !_replacementUsed) {
      final dispatched = sources.values.any(
        (s) =>
            s.phase == SourcePhase.loading || s.phase == SourcePhase.complete,
      );
      if (dispatched) _replacementUsed = true;
      // Preserve visible records until replacement candidates are ready.
      _revision++;
      service.cancel(_owner);
      google?.cancel(_owner);
      _sessions[usesGoogle ? SearchSource.others : SearchSource.google] =
          _SourceSession();
      if (!usesGoogle) _clearGoogle();
      _launch(immediate: dispatched, preserveResults: true);
    } else if (previous?.rankingKey != value?.rankingKey) {
      _publish();
      notifyListeners();
    }
  }

  SearchArea? get area => _area;
  SearchCategory? get suggestion => SearchCategory.match(query);
  bool get needsLocalArea =>
      category != null && (_area?.local != true || origin?.area.local != true);
  bool get loading => sources.values.any(
    (s) => s.phase == SourcePhase.waiting || s.phase == SourcePhase.loading,
  );
  bool get failed =>
      sources.values.any((s) => s.phase == SourcePhase.unavailable) ||
      (_started &&
          sources.values.every((s) => s.phase == SourcePhase.disabled));
  bool get searched => _started && !loading;
  bool get hasSearch => _started;
  bool get emptySuccess =>
      searched && !failed && (usesGoogle ? _googleCount == 0 : results.isEmpty);
  void updateArea(SearchArea area) {
    final wasLocal = _area?.local == true;
    _area = area;
    if (wasLocal != area.local) notifyListeners();
  }

  void change(String value) {
    _open = true;
    final next = normalizeSearch(value);
    if (next == query && category == null) return;
    _submitted = false;
    service.cancel(_owner);
    _clearGoogle();
    _original = false;
    _suggested = null;
    _revision++;
    _invalidateSessions();
    _resetRanking();
    query = next;
    category = null;
    results = [];
    sources.clear();
    _started = false;
    notifyListeners();
    if (query.length >= 3 && query.length <= 100) _launch();
  }

  void chooseCategory(SearchCategory value) {
    _open = true;
    service.cancel(_owner);
    _clearGoogle();
    _revision++;
    _invalidateSessions();
    _resetRanking();
    category = value;
    if (_device == null && _area?.local == true) {
      _areaSelected = true;
      _selectedArea = SearchOrigin.map(_area!);
    }
    results = [];
    sources.clear();
    _started = false;
    if (needsLocalArea) {
      notifyListeners();
      return;
    }
    _launch(immediate: true);
  }

  void searchThisArea() {
    if (_area?.local != true) return;
    if (_areaSelected && _selectedArea?.key == SearchOrigin.map(_area!).key) {
      return;
    }
    _areaSelected = true;
    _selectedArea = SearchOrigin.map(_area!);
    _newOriginSearch();
  }

  void submit() {
    _open = true;
    _submitted = true;
    if (query.length < 2 || query.length > 100 || needsLocalArea) return;
    if (usesGoogle && sources['google_ui_kit']?.phase == SourcePhase.loading) {
      return;
    }
    if (_requestKey == _request().key &&
        _started &&
        !loading &&
        sources.values.every(
          (s) =>
              s.phase == SourcePhase.complete ||
              s.phase == SourcePhase.disabled,
        )) {
      return;
    }
    _launch(immediate: true);
  }

  PlaceSearchRequest _request() => PlaceSearchRequest(
    _suggested ?? query,
    category: category,
    origin: origin,
    useOriginal: _original,
  );

  void retry() {
    if (loading) return;
    _suspended = false;
    if (usesGoogle && _resolvingId != null && _detailsStarted) {
      googleMessage =
          'This selection could not be resolved. Choose another result or use Other sources.';
      notifyListeners();
      return;
    }
    final ids = sources.entries
        .where((e) => e.value.phase == SourcePhase.unavailable)
        .map((e) => e.key)
        .toSet();
    if (ids.isNotEmpty) _launch(immediate: true, only: ids);
  }

  void _launch({
    bool immediate = false,
    Set<String>? only,
    bool preserveResults = false,
    bool refresh = false,
  }) {
    final request = only != null && _activeRequest != null
        ? _activeRequest!
        : _request();
    if (only == null && request.key != _requestKey) {
      if (!preserveResults) results = [];
      _batches.clear();
      sources.clear();
    }
    _requestKey = request.key;
    _suspended = false;
    _activeRequest = request;
    final revision = _revision;
    final session = _state;
    _started = true;
    if (usesGoogle) {
      if (_resolvingId != null) {
        _loadGoogleDetails(_resolvingId!);
      } else {
        _launchGoogle(request, immediate: immediate);
      }
      return;
    }
    service.search(
      _owner,
      request,
      (id, state, batch) {
        if (_disposed || revision != _revision || !_open || _suspended) return;
        session.sources[id] = state;
        if (state.phase == SourcePhase.complete) {
          session.batches[id] = batch;
          _publish(session);
        }
        notifyListeners();
      },
      immediate: immediate,
      only: only,
      refresh: refresh,
    );
  }

  void _publish([_SourceSession? target]) {
    final session = target ?? _state;
    final merged = <PlaceSearchResult>[];
    final sorted = rankPlaces(
      session.batches.values.expand((v) => v),
      interpretedText,
      origin,
    );
    for (final candidate in sorted) {
      final existing = merged.indexWhere(
        (value) => sameSearchPlace(value, candidate),
      );
      if (existing >= 0) {
        merged[existing] = merged[existing].withCredits(candidate.attributions);
      } else {
        merged.add(candidate);
      }
    }
    final next = merged.take(30).toList();
    final results = session.results;
    if (session.frozen) {
      // Records as well as order stay fixed while someone is choosing a row.
      if (next.length != results.length ||
          List.generate(
            next.length,
            (i) =>
                i >= results.length ||
                next[i].sourceId != results[i].sourceId ||
                next[i].provider != results[i].provider ||
                next[i].name != results[i].name ||
                next[i].address != results[i].address ||
                next[i].category != results[i].category ||
                next[i].retrievedAt != results[i].retrievedAt ||
                next[i].attributions.join('|') !=
                    results[i].attributions.join('|') ||
                next[i].latitude != results[i].latitude ||
                next[i].longitude != results[i].longitude,
          ).any((changed) => changed) ||
          session.visibleOrigin?.rankingKey != origin?.rankingKey) {
        session.staged = next;
      } else {
        session.staged = null;
      }
    } else {
      session.results = next;
      session.visibleOrigin = origin;
      session.staged = null;
    }
  }

  void dismiss() {
    _open = false;
    _submitted = false;
    service.cancel(_owner);
    _clearGoogle();
    _revision++;
    _invalidateSessions();
    _resetRanking();
    query = '';
    category = null;
    results = [];
    sources.clear();
    _started = false;
    if (!_disposed) notifyListeners();
  }

  void suspend() {
    _suspended = true;
    service.cancel(_owner);
    google?.cancel(_owner);
    _revision++;
    for (final session in _sessions.values) {
      for (final id in session.sources.keys.toList()) {
        if (session.sources[id]!.phase == SourcePhase.waiting ||
            session.sources[id]!.phase == SourcePhase.loading) {
          session.sources[id] = const SourceState(SourcePhase.unavailable);
        }
      }
    }
    notifyListeners();
  }

  void _invalidateSessions() {
    _contextRevision++;
    for (final key in SearchSource.values) {
      _sessions[key] = _SourceSession();
    }
  }

  bool get canRefresh =>
      _started &&
      !loading &&
      sources.isNotEmpty &&
      sources.values.any((value) => value.phase == SourcePhase.complete);

  void refreshResults() {
    if (!canRefresh) return;
    _suspended = false;
    _launch(immediate: true, preserveResults: true, refresh: true);
  }

  @override
  void dispose() {
    service.cancel(_owner);
    _clearGoogle();
    sourceChoice?.removeListener(_sourceChanged);
    _disposed = true;
    super.dispose();
  }
}
