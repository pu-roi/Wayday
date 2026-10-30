part of 'planning_controller.dart';

extension RecommendationPreparation on PlanningController {
  String get _roadContext => clarificationHash({
    'date': day.date,
    'departure': day.departure,
    'profile': day.profile.name,
  });
  String _coordinateIdentity(PlanCandidate p) =>
      clarificationHash({'lat': p.place.latitude, 'lon': p.place.longitude});
  String get _routeInputSignature => clarificationHash({
    'day': day.toJson(),
    'errands': activeErrands.map((e) => e.toJson()).toList(),
    'points': points.map((p) => [p.key, _coordinateIdentity(p)]).toList(),
  });
  bool _canReuseMatrix(List<PlanCandidate> selected) =>
      _matrixResponse != null &&
      _matrixTrip == _roadContext &&
      _matrixAt != null &&
      DateTime.now().difference(_matrixAt!) < const Duration(minutes: 5) &&
      selected.every(
        (p) =>
            p.place.hasCoordinates &&
            _matrixPlaces[p.key] == _coordinateIdentity(p),
      );

  Future<Map<String, dynamic>> _matrixFor(
    List<PlanCandidate> selected,
    bool Function() cancelled,
  ) async {
    if (_canReuseMatrix(selected)) {
      final indices = selected.map((p) => _matrixKeys.indexOf(p.key)).toList();
      return {
        for (final entry in _matrixResponse!.entries)
          entry.key:
              {'matrix', 'meters'}.contains(entry.key) && entry.value is List
              ? [
                  for (final a in indices)
                    [for (final b in indices) (entry.value as List)[a][b]],
                ]
              : entry.value,
      };
    }
    final response = await roads.matrix(
      day.copyWith(errands: activeErrands),
      selected,
      cancelled: cancelled,
    );
    if (!cancelled()) {
      _matrixResponse = response;
      _matrixAt = DateTime.now();
      _matrixTrip = _roadContext;
      _matrixKeys = selected.map((p) => p.key).toList();
      _matrixPlaces = {for (final p in selected) p.key: _coordinateIdentity(p)};
    }
    return response;
  }

  String get _recommendationContext => _contextWithEndpoints();
  String _contextWithEndpoints({
    PlaceIntent? from,
    PlaceIntent? to,
  }) => clarificationHash({
    'version': 2,
    // Included suggestions are retained choices, not source changes. Their
    // full model context is represented by needs below before restoring them.
    'day':
        (manualReviewDay
            .copyWith(
              fromPlace: from,
              toPlace: to,
              errands: _reviewItems.values
                  .where((e) => _originalIds.contains(e.id))
                  .toList(),
            )
            .toJson()
          ..remove('from')
          ..remove('to')),
    'needs': needs.values
        .map(
          (n) => {
            'id': n.id,
            'query': n.query,
            'category': n.category,
            'items': n.items,
            'duration': n.durationMinutes,
            'after': n.after,
            'timing': n.timing,
            'minute': n.minute,
            'optional': n.optional,
            'specific': n.requiresSpecificLocation,
            'title': n.proposedTitle,
          },
        )
        .toList(),
    'answers': clarifications.session.records.values
        .where((r) => r.applied)
        .map(
          (r) => {
            'key': r.context.key,
            'result': r.resolution!.toJson(),
            'approved': r.rulesApproved,
          },
        )
        .toList(),
    'deferrals': deferred,
  });

  Future<void> restoreRecommendationDraft() async {
    final epoch = _epoch, context = _recommendationContext;
    try {
      final draft = await draftRepository.read(
        _draftSource,
        null,
        resolver: resolveGooglePin,
      );
      if (_closed || epoch != _epoch || context != _recommendationContext) {
        return;
      }
      _recommendationDraftRestored = true;
      recommendationStorageError = null;
      if (draft == null) return;
      if (draft.context !=
          _contextWithEndpoints(from: draft.from, to: draft.to)) {
        return;
      }
      day = day.copyWith(
        fromPlace: draft.from,
        toPlace: draft.to,
        from: draft.from?.label,
        to: draft.to?.label,
      );
      final allowed = {...needs.keys};
      if (draft.choices.keys.any((id) => !allowed.contains(id)) ||
          draft.approved.any((id) => !allowed.contains(id)) ||
          draft.additions.any((id) => !allowed.contains(id))) {
        throw const FormatException('Draft errands have changed');
      }
      approved
        ..clear()
        ..addAll(draft.approved);
      additions
        ..clear()
        ..addAll(draft.additions);
      _proposalChoices
        ..clear()
        ..addAll(draft.choices);
      overrides.clear();
      for (final entry in draft.choices.entries) {
        final p = entry.value;
        candidates[entry.key] = [
          PlanCandidate(
            key: placeKey(p),
            place: p,
            errandIds: {entry.key},
            reason: 'Your retained place choice.',
          ),
        ];
        if (draft.overrides.contains(entry.key)) {
          overrides[entry.key] = placeKey(p);
        }
      }
      selectedErrand = draft.selectedErrand;
      recommendationScrollOffset = draft.scrollOffset;
      recommendationStorageError = null;
    } catch (_) {
      recommendationStorageError =
          'Saved place choices could not be restored. Review them before continuing.';
    }
    _emit();
  }

  Future<bool> saveRecommendationDraft() async {
    if (interpretation == null) return true;
    if (!_recommendationDraftRestored &&
        !_recommendationDraftChanged &&
        result == null &&
        overrides.isEmpty) {
      return recommendationStorageError == null;
    }
    final choices = <String, PlaceIntent>{
      for (final entry in _proposalChoices.entries)
        if (activeErrands.any((e) => e.id == entry.key) &&
            candidates[entry.key]?.any((p) => p.key == placeKey(entry.value)) ==
                true)
          entry.key: entry.value,
    };
    for (final entry in overrides.entries) {
      final matches = candidates[entry.key]?.where((p) => p.key == entry.value);
      if (matches?.isNotEmpty == true) {
        choices[entry.key] = matches!.first.place;
      }
    }
    try {
      await draftRepository.save(
        _draftSource,
        RecommendationDraft(
          context: _recommendationContext,
          choices: choices,
          overrides: overrides.keys.where(choices.containsKey).toSet(),
          approved: {...approved},
          additions: {...additions},
          from: day.fromPlace,
          to: day.toPlace,
          selectedErrand: choices.containsKey(selectedErrand)
              ? selectedErrand
              : null,
          scrollOffset: recommendationScrollOffset,
        ),
      );
      if (!_closed) recommendationStorageError = null;
      return true;
    } catch (_) {
      if (!_closed) {
        recommendationStorageError =
            'Place choices could not be saved. Retry saving before closing.';
        _emit();
      }
      return false;
    }
  }

  Future<void> buildRecommendations() async {
    try {
      applyReview();
    } catch (e) {
      error = e.toString();
      _emit();
      return;
    }
    final service = discovery;
    final epoch = ++_epoch;
    bool cancelled() => _closed || epoch != _epoch;
    stage = PreparationStage.calculating;
    progress = 'Finding suitable places along your trip…';
    error = null;
    _emit();
    try {
      // Estimate the complete bounded calculation before spending on discovery.
      final count = activeErrands.fold<int>(
        2,
        (sum, e) =>
            sum +
            (candidates.containsKey(e.id)
                ? candidates[e.id]!.length
                : candidateLimit),
      );
      await roads.preflight(
        unresolved.isEmpty && _canReuseMatrix(points) ? 0 : count,
        activeErrands.length + 1,
        seed: unresolved.isNotEmpty,
      );
      final requests =
          unresolved.length * 3 +
          candidates.values
              .expand((v) => v)
              .where((p) => p.place.isGoogle)
              .length;
      if (requests > 0) await service?.preflight(requests);
      if (cancelled()) return;
      for (final group in candidates.values) {
        for (final candidate in group) {
          if (candidate.place.isGoogle) {
            if (service == null) {
              throw const PlanningFailure(
                'Google place refresh is unavailable.',
              );
            }
            final metadata = await service.hydrate(
              candidate.place,
              cancelled: cancelled,
            );
            if (cancelled()) return;
            if (metadata?.status == 'CLOSED_PERMANENTLY' ||
                metadata?.status == 'CLOSED_TEMPORARILY') {
              throw const PlanningFailure(
                'A selected business is reported closed. Review its actual location or defer that errand.',
                kind: 'needs_clarification',
              );
            }
          }
        }
      }
      if (unresolved.isNotEmpty) {
        if (service == null) {
          throw const PlanningFailure(
            'Place recommendations are unavailable in this build.',
          );
        }
        final fixed = <PlanCandidate>[
          PlanCandidate(key: '@start', place: day.fromPlace, errandIds: {}),
          for (final e in activeErrands)
            if (e.placeIntent.hasCoordinates)
              PlanCandidate(
                key: placeKey(e.placeIntent),
                place: e.placeIntent,
                errandIds: {e.id},
              ),
          PlanCandidate(key: '@end', place: day.toPlace, errandIds: {}),
        ];
        final route = await roads.discoveryRoute(
          day,
          fixed,
          cancelled: cancelled,
        );
        if (cancelled()) return;
        for (final e in [...unresolved]) {
          progress = 'Finding places for “${e.title}”…';
          _emit();
          final tasks = activeErrands,
              position = activeErrands.indexWhere((task) => task.id == e.id);
          final previous = tasks
              .take(position)
              .where((task) => task.placeIntent.hasCoordinates)
              .toList();
          final following = tasks
              .skip(position + 1)
              .where((task) => task.placeIntent.hasCoordinates)
              .toList();
          final prerequisites = e.afterErrandIds
              .where((id) => candidates[id]?.isNotEmpty == true)
              .toList();
          final anchorBefore = prerequisites.isNotEmpty
              ? candidates[prerequisites.last]!.first.place
              : previous.isNotEmpty
              ? previous.last.placeIntent
              : day.fromPlace;
          final anchorAfter = following.isNotEmpty
              ? following.first.placeIntent
              : day.toPlace;
          final values = await service.discover(
            effectiveNeed(e)!,
            polyline: route,
            anchors: [anchorBefore, anchorAfter],
            limit: candidateLimit,
            cancelled: cancelled,
          );
          if (cancelled()) return;
          if (values.isEmpty && !e.optional) {
            throw PlanningFailure(
              'No suitable place was found for “${e.title}”. Search for a place or review this errand.',
              kind: 'no_candidates',
            );
          }
          candidates[e.id] = values
              .map(
                (p) => PlanCandidate(
                  key: p.key,
                  place: p.place.isGoogle
                      ? p.place.withLabel(e.title, labelSource: 'user')
                      : p.place,
                  errandIds: p.errandIds,
                  reason: p.reason,
                ),
              )
              .toList();
        }
      }
      if (!cancelled()) await calculate();
    } catch (e) {
      if (cancelled()) return;
      error = e is PlanningFailure
          ? e.message
          : 'Recommendations are unavailable. Your choices are kept.';
      stage = PreparationStage.discovery;
      _emit();
    }
  }

  String displayPlace(PlaceIntent place) {
    final name = discovery?.metadata(place)?.name;
    return name?.isNotEmpty == true
        ? name!
        : place.label.isNotEmpty
        ? place.label
        : 'Selected place · refresh details';
  }

  int? detourFor(String key, String before, String after) {
    final matrix = recommendationMatrix, keys = recommendationKeys;
    if (matrix == null || ![key, before, after].every(keys.contains)) {
      return null;
    }
    final a = keys.indexOf(before),
        b = keys.indexOf(key),
        c = keys.indexOf(after);
    return addedTravelSeconds(matrix, a, b, c);
  }
}
