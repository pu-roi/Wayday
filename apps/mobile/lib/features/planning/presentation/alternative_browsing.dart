part of 'planning_controller.dart';

class AlternativeBrowseState {
  AlternativeBrowseState(this.context, this.values);
  final String context;
  final DateTime createdAt = DateTime.now();
  final List<PlanCandidate> values;
  bool loading = false, exhausted = false;
  String? error;
  double scrollOffset = 0;
}

extension AlternativeBrowsing on PlanningController {
  String _alternativeSearchIdentity(String id) => clarificationHash({
    'road': _roadContext,
    'need': effectiveNeed(
      activeErrands.firstWhere((e) => e.id == id),
    )!.toJson(),
    'endpoints': [
      for (final p in [day.fromPlace, day.toPlace]) [p.latitude, p.longitude],
    ],
  });

  ({String? polyline, List<PlaceIntent> anchors, String key}) _browseContext(
    String id,
  ) {
    final search = _alternativeSearches[id];
    if (search != null && search.identity == _alternativeSearchIdentity(id)) {
      return (
        polyline: search.polyline,
        anchors: search.anchors,
        key: clarificationHash({
          'identity': search.identity,
          'seed': search.polyline,
          'anchors': [
            for (final p in search.anchors) [p.latitude, p.longitude],
          ],
        }),
      );
    }
    final tasks = activeErrands;
    final order =
        result?.schedule.stops
            .expand((s) => s.tasks.map((t) => t.errandId))
            .toList() ??
        tasks.map((e) => e.id).toList();
    final index = order.indexOf(id), choices = displayChoices;
    final before = index > 0
        ? choices[order[index - 1]] ?? day.fromPlace
        : day.fromPlace;
    final after = index >= 0 && index < order.length - 1
        ? choices[order[index + 1]] ?? day.toPlace
        : day.toPlace;
    final need = effectiveNeed(tasks.firstWhere((e) => e.id == id))!;
    return (
      polyline: _discoveryPolyline,
      anchors: [before, after],
      key: clarificationHash({
        'road': _roadContext,
        'need': need.toJson(),
        'seed': _discoveryPolyline,
        'anchors': [
          for (final p in [before, after]) [p.latitude, p.longitude],
        ],
      }),
    );
  }

  AlternativeBrowseState alternativesFor(String id) {
    final context = _browseContext(id);
    final saved = _alternativeBrowses[id];
    if (saved != null &&
        saved.context == context.key &&
        DateTime.now().difference(saved.createdAt) <
            const Duration(minutes: 5)) {
      final selected = displayChoices[id];
      if (selected != null &&
          !saved.values.any((p) => p.key == placeKey(selected))) {
        if (saved.values.length == 12) saved.values.removeLast();
        saved.values.add(
          PlanCandidate(
            key: placeKey(selected),
            place: selected,
            errandIds: {id},
            reason: 'Your selected place.',
          ),
        );
      }
      return saved;
    }
    final values = <String, PlanCandidate>{
      for (final p in candidates[id] ?? <PlanCandidate>[]) p.key: p,
    };
    final selected = displayChoices[id];
    if (selected != null) {
      values.putIfAbsent(
        placeKey(selected),
        () => PlanCandidate(
          key: placeKey(selected),
          place: selected,
          errandIds: {id},
          reason: 'Your selected place.',
        ),
      );
    }
    return _alternativeBrowses[id] = AlternativeBrowseState(
      context.key,
      values.values.toList(),
    );
  }

  Future<void> showMoreAlternatives(String id) async {
    final state = alternativesFor(id), service = discovery;
    if (state.loading || state.exhausted || state.values.length >= 12) return;
    final errand = activeErrands.firstWhere((e) => e.id == id);
    if (service is! AlternativeDiscovery ||
        !needsPlaceRecommendation(errand, effectiveNeed(errand))) {
      state.exhausted = true;
      _emit();
      return;
    }
    final context = _browseContext(id);
    bool obsolete() =>
        _closed ||
        !activeErrands.any((e) => e.id == id) ||
        !identical(_alternativeBrowses[id], state) ||
        _browseContext(id).key != context.key;
    state.loading = true;
    state.error = null;
    _emit();
    try {
      final batch = await (service as AlternativeDiscovery).moreAlternatives(
        effectiveNeed(errand)!,
        polyline: context.polyline,
        anchors: context.anchors,
        excludedKeys: state.values.map((p) => p.key).toSet(),
        limit: (12 - state.values.length).clamp(1, 3),
        cancelled: obsolete,
      );
      if (obsolete()) return;
      final known = state.values.map((p) => p.key).toSet();
      state.values.addAll(
        batch.candidates
            .where((p) => known.add(p.key))
            .take(12 - state.values.length),
      );
      state.exhausted = batch.exhausted || state.values.length >= 12;
    } catch (e) {
      if (!obsolete()) {
        state.error = e is PlanningFailure
            ? e.message
            : 'More suggestions could not load. Your places are kept.';
      }
    } finally {
      state.loading = false;
      if (!_closed) _emit();
    }
  }
}
