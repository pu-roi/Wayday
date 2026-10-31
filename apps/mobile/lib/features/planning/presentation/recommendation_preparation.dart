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
    'hours': hoursIdentity,
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
      _matrixAt =
          DateTime.tryParse(response['acquiredAt'] as String? ?? '') ??
          DateTime.now();
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
            if (n.locationIntent != null)
              'locationIntent': n.locationIntent!.name,
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
          draft.pendingCandidates.keys.any((id) => !allowed.contains(id)) ||
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
      for (final entry in draft.pendingCandidates.entries) {
        candidates[entry.key] = [
          for (final p in entry.value)
            PlanCandidate(
              key: placeKey(p),
              place: p,
              errandIds: {entry.key},
              reason: 'Found for this trip; route comparison still needed.',
            ),
        ];
      }
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
    String? saveKey;
    try {
      final draft = RecommendationDraft(
        context: _recommendationContext,
        choices: choices,
        pendingCandidates: {
          for (final entry in candidates.entries)
            if (!choices.containsKey(entry.key) &&
                entry.value.isNotEmpty &&
                activeErrands.any((e) => e.id == entry.key))
              entry.key: entry.value.map((p) => p.place).toList(),
        },
        overrides: overrides.keys.where(choices.containsKey).toSet(),
        approved: {...approved},
        additions: {...additions},
        from: day.fromPlace,
        to: day.toPlace,
        selectedErrand: choices.containsKey(selectedErrand)
            ? selectedErrand
            : null,
        scrollOffset: recommendationScrollOffset,
      );
      final key = clarificationHash({
        'source': _draftSource,
        'draft': draft.toJson(),
      });
      _latestDraftSaveKey = key;
      saveKey = key;
      final flight = _draftSaveFlights.putIfAbsent(
        key,
        () => draftRepository.save(_draftSource, draft),
      );
      unawaited(
        flight.then<void>(
          (_) {
            if (identical(_draftSaveFlights[key], flight)) {
              _draftSaveFlights.remove(key);
            }
            if (!_closed) _emit();
          },
          onError: (Object _, StackTrace _) {
            if (identical(_draftSaveFlights[key], flight)) {
              _draftSaveFlights.remove(key);
            }
          },
        ),
      );
      await flight.timeout(draftSaveTimeout);
      if (!_closed && _latestDraftSaveKey == key) {
        recommendationStorageError = null;
        _emit();
      }
      return true;
    } catch (_) {
      if (!_closed && (saveKey == null || _latestDraftSaveKey == saveKey)) {
        recommendationStorageError =
            'Place choices could not be saved. Retry saving before closing.';
        _emit();
      }
      return false;
    }
  }

  Future<void> buildRecommendations() {
    if (_recommendationFlight != null) return _recommendationFlight!;
    final flight = _buildRecommendations();
    _recommendationFlight = flight;
    return flight.whenComplete(() {
      if (identical(_recommendationFlight, flight)) {
        _recommendationFlight = null;
      }
    });
  }

  Future<void> _buildRecommendations() async {
    if (proposalReady && _canReuseMatrix(points)) {
      stage = PreparationStage.recommendations;
      _emit();
      return;
    }
    try {
      applyReview();
    } catch (e) {
      error = e.toString();
      _emit();
      return;
    }
    recommendationFailure = null;
    failedRecommendationErrand = null;
    recommendationOperation = RecommendationOperation.configuration;
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
      progress = 'Checking planning capacity…';
      _emit();
      await roads
          .preflight(
            unresolved.isEmpty && _canReuseMatrix(points) ? 0 : count,
            activeErrands.length + 1,
            seed: unresolved.isNotEmpty,
          )
          .timeout(preparationTimeout);
      final requests =
          unresolved.length * 3 +
          candidates.values
              .expand((v) => v)
              .where((p) => p.place.isGoogle)
              .length;
      if (requests > 0) {
        await service?.preflight(requests).timeout(preparationTimeout);
      }
      if (cancelled()) return;
      recommendationOperation = RecommendationOperation.refresh;
      progress = 'Refreshing selected places…';
      _emit();
      for (final group in candidates.values) {
        for (final candidate in group) {
          if (candidate.place.isGoogle) {
            if (service == null) {
              throw const PlanningFailure(
                'Google place refresh is unavailable.',
              );
            }
            failedRecommendationErrand = candidate.errandIds.firstOrNull;
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
        failedRecommendationErrand = null;
        recommendationOperation = RecommendationOperation.seed;
        progress = 'Checking the trip route…';
        _emit();
        final route = await roads.discoveryRoute(
          day,
          fixed,
          cancelled: cancelled,
        );
        if (cancelled()) return;
        _discoveryPolyline = route;
        for (final e in [...unresolved]) {
          failedRecommendationErrand = e.id;
          recommendationOperation = route == null
              ? RecommendationOperation.anchor
              : RecommendationOperation.corridor;
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
          _alternativeSearches[e.id] = (
            identity: _alternativeSearchIdentity(e.id),
            polyline: route,
            anchors: [anchorBefore, anchorAfter],
          );
          final batch = await service.discover(
            effectiveNeed(e)!,
            polyline: route,
            anchors: [anchorBefore, anchorAfter],
            limit: candidateLimit,
            cancelled: cancelled,
            hours: hoursQuery(e),
          );
          if (cancelled()) return;
          final values = batch.candidates;
          discoveryResults[e.id] = batch;
          if (values.isEmpty && !e.optional) {
            throw PlanningFailure(
              (batch.exclusions[PlaceExclusion.hours] ?? 0) > 0
                  ? 'No returned business has a reported opening window long enough for “${e.title}” during this trip. Change the trip time or choose another place.'
                  : batch.outcome == DiscoveryOutcome.noMatches
                  ? 'The completed searches returned no matches for “${e.title}” along this trip.'
                  : 'Places were returned for “${e.title}”, but none passed the location and suitability checks.',
              kind: batch.outcome == DiscoveryOutcome.noMatches
                  ? 'no_candidates'
                  : 'candidates_rejected',
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
          _recommendationDraftChanged = true;
        }
      }
      failedRecommendationErrand = null;
      recommendationOperation = RecommendationOperation.matrix;
      if (!cancelled()) await calculate();
    } catch (e) {
      if (cancelled()) return;
      recommendationFailure = e is RecommendationFailure
          ? (failedRecommendationErrand == null
                ? e
                : e.forErrand(failedRecommendationErrand!))
          : e is PlanningFailure
          ? e
          : e is TimeoutException
          ? const PlanningFailure(
              'Planning preparation took too long. Your choices are kept; you can try again.',
              kind: 'timeout',
            )
          : const PlanningFailure(
              'Recommendations are unavailable. Your choices are kept.',
            );
      if (e is RecommendationFailure) recommendationOperation = e.operation;
      error = recommendationFailure!.message;
      stage = PreparationStage.discovery;
      _emit();
      await saveRecommendationDraft();
      if (cancelled()) return;
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
