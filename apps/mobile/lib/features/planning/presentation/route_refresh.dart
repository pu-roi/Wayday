part of 'planning_controller.dart';

enum RouteRefreshState { idle, queued, refreshing, failed }

extension AutomaticRouteRefresh on PlanningController {
  void _stopRouteRefresh() {
    _routeRefreshTimer?.cancel();
    _refreshNotBefore = null;
    _refreshRequested = false;
    _selectionRevision++;
    routeRefreshState = RouteRefreshState.idle;
    keepPlanVisible = false;
  }

  Future<void> replaceAndRefresh(String id, PlaceIntent place) async {
    final current = displayChoices[id];
    if (current != null &&
        placeKey(current) == placeKey(place) &&
        current.latitude == place.latitude &&
        current.longitude == place.longitude) {
      return;
    }
    final revision = ++_selectionRevision;
    _epoch++; // An older route may finish, but cannot apply to these choices.
    _routeRefreshTimer?.cancel();
    _refreshRequested = true;
    replacePlannedPlace(id, place);
    keepPlanVisible = true;
    routeRefreshState = RouteRefreshState.queued;
    _emit();
    if (!await saveRecommendationDraft()) {
      if (!_closed && revision == _selectionRevision) {
        _refreshRequested = false;
        routeRefreshState = RouteRefreshState.failed;
        _emit();
      }
      return;
    }
    if (_closed || revision != _selectionRevision) return;
    _savedSelectionRevision = revision;
    _refreshNotBefore = DateTime.now().add(routeDebounce);
    _routeRefreshTimer = Timer(routeDebounce, _drainRouteRefresh);
  }

  Future<void> retryRouteRefresh() async {
    if (_closed ||
        _routeRefreshFlight != null ||
        routeRefreshState == RouteRefreshState.queued) {
      return;
    }
    keepPlanVisible = true;
    if (unresolved.isNotEmpty) {
      await buildRecommendations();
      return;
    }
    if (!await saveRecommendationDraft()) return;
    _savedSelectionRevision = _selectionRevision;
    _refreshNotBefore = null;
    _refreshRequested = true;
    await _drainRouteRefresh();
  }

  Future<void> _drainRouteRefresh() async {
    if (_closed ||
        _routeRefreshFlight != null ||
        !_refreshRequested ||
        _savedSelectionRevision != _selectionRevision) {
      return;
    }
    final wait = _refreshNotBefore?.difference(DateTime.now());
    if (wait != null && wait > Duration.zero) {
      _routeRefreshTimer = Timer(wait, _drainRouteRefresh);
      return;
    }
    _refreshRequested = false;
    final revision = _selectionRevision;
    routeRefreshState = RouteRefreshState.refreshing;
    _emit();
    final flight = () async {
      final previous = _previousStopOrder;
      await calculate();
      if (_closed || revision != _selectionRevision) return;
      final order = result?.schedule.stops
          .expand((s) => s.tasks.map((t) => t.errandId))
          .toList();
      orderChanged =
          order != null &&
          previous != null &&
          order.join('|') != previous.join('|');
      if (order != null) _previousStopOrder = null;
      routeRefreshState = result == null || recommendationStorageError != null
          ? RouteRefreshState.failed
          : RouteRefreshState.idle;
      _emit();
    }();
    _routeRefreshFlight = flight;
    try {
      await flight;
    } finally {
      if (identical(_routeRefreshFlight, flight)) _routeRefreshFlight = null;
      if (!_closed &&
          _refreshRequested &&
          _savedSelectionRevision == _selectionRevision) {
        _routeRefreshTimer = Timer(Duration.zero, _drainRouteRefresh);
      }
    }
  }
}
