part of 'planning_controller.dart';

extension PlanningHours on PlanningController {
  bool hoursAreAdvisory(String errandId) =>
      _manualPlaces.contains(errandId) ||
      reviewInput(
        activeErrands.firstWhere((e) => e.id == errandId),
      ).placeIntent.hasCoordinates;

  Set<String> get hoursAdvisoryErrands => {
    for (final e in activeErrands)
      if (hoursAreAdvisory(e.id)) e.id,
  };
  HoursQuery hoursQuery(Errand e) => HoursQuery(
    day.date,
    day.departure,
    day.deadline,
    e.durationMinutes,
    timing: e.timing,
    minute: e.minute,
    mayShareStop: activeErrands.length > 1,
  );

  void discardShortlistsForChangedHours() {
    for (final e in activeErrands) {
      final old = _shortlistHours[e.id];
      if (old == null || old == hoursQuery(e).context) continue;
      _shortlistHours.remove(e.id);
      if (overrides.containsKey(e.id) || e.placeIntent.hasCoordinates) continue;
      candidates.remove(e.id);
      discoveryResults.remove(e.id);
      _proposalChoices.remove(e.id);
      _recommendationDraftChanged = true;
    }
  }

  HoursDay hoursFor(PlaceIntent place) => hoursForDate(place, day.date);
  HoursDay hoursForDate(PlaceIntent place, String date, {DateTime? now}) {
    final service = discovery;
    return (service is HoursRefreshDiscovery
            ? (service as HoursRefreshDiscovery).hoursStatus(place)
            : service?.metadata(place)?.hours ?? const BusinessHours())
        .day(date, now: now);
  }

  Map<String, Object?> get hoursIdentity => {
    for (final p in points.where(
      (p) => p.place.isGoogle && p.errandIds.isNotEmpty,
    ))
      p.key: {
        'state': hoursFor(p.place).state.name,
        'windows': hoursFor(p.place).windows,
        'usual': hoursFor(p.place).usual,
        'at': hoursFor(p.place).checkedAt?.toIso8601String(),
      },
  };
  Map<String, List<List<int>>> businessWindows(List<PlanCandidate> selected) =>
      {
        for (final p in selected)
          if (p.place.isGoogle &&
              p.errandIds.isNotEmpty &&
              hoursFor(p.place).windows != null)
            p.key: hoursFor(p.place).windows!,
      };
  Future<void> prepareHours(
    List<PlanCandidate> selected,
    bool Function() cancelled,
  ) async {
    for (final p in selected.where(
      (p) => p.place.isGoogle && p.errandIds.isNotEmpty,
    )) {
      if (cancelled()) return;
      final record = discovery?.metadata(p.place);
      if (record == null ||
          !record.hours.checked ||
          {
            HoursState.failed,
            HoursState.stale,
          }.contains(hoursFor(p.place).state)) {
        await discovery?.hydrate(p.place, cancelled: cancelled);
      }
      if (cancelled()) return;
      if (p.errandIds.any((id) => !hoursAreAdvisory(id)) &&
          (hoursFor(p.place).state == HoursState.failed ||
              discovery is HoursRefreshDiscovery &&
                  hoursFor(p.place).state == HoursState.notRequested)) {
        throw const PlanningFailure(
          'Business hours could not be checked. Retry the hours check before starting.',
          kind: 'business_hours',
        );
      }
    }
  }

  void checkHoursOptions(List<PlanCandidate> selected) {
    for (final e in activeErrands.where(
      (e) => !e.optional && !hoursAreAdvisory(e.id),
    )) {
      final options = selected
          .where((p) => p.errandIds.contains(e.id))
          .toList();
      if (options.isNotEmpty &&
          options.every(
            (p) =>
                p.place.isGoogle &&
                hoursFor(p.place).windows != null &&
                !hoursQuery(e).permitsDay(hoursFor(p.place)),
          )) {
        throw PlanningFailure(
          'No selected place can fit “${e.title}” within its scheduled time and reported hours. Change its place or timing.',
          kind: 'business_hours',
        );
      }
    }
  }

  bool alternativeHasWindow(String id, PlanCandidate candidate) {
    if (!candidate.place.isGoogle ||
        displayChoices[id] != null &&
            placeKey(displayChoices[id]!) == candidate.key) {
      return true;
    }
    final business = discovery?.metadata(candidate.place);
    if ({
      'CLOSED_PERMANENTLY',
      'CLOSED_TEMPORARILY',
    }.contains(business?.status)) {
      return false;
    }
    return hoursQuery(
      activeErrands.firstWhere((e) => e.id == id),
    ).permits(business?.hours ?? const BusinessHours());
  }

  Future<void> retryBusinessHours(PlaceIntent place) async {
    final service = discovery;
    final epoch = _epoch;
    try {
      if (service is HoursRefreshDiscovery) {
        await (service as HoursRefreshDiscovery).retryHours(place);
      } else {
        await service?.hydrate(place);
      }
    } catch (_) {
      if (!_closed && epoch == _epoch) _emit();
      rethrow;
    }
    if (_closed || epoch != _epoch) return;
    _emit();
    if (hoursFor(place).state == HoursState.failed) {
      throw const PlanningFailure(
        'Business hours could not be read. Your place is kept.',
      );
    }
    if (unresolved.isEmpty &&
        !busy &&
        displayChoices.values.any((p) => placeKey(p) == placeKey(place))) {
      await retryRouteRefresh();
    }
  }

  String? hoursConflict(
    DaySchedule schedule,
    Map<String, List<List<int>>> windows,
  ) {
    for (final stop in schedule.stops) {
      final hours = windows[stop.placeKey];
      if (hours != null &&
          !reportedHoursFit(stop, hours, hoursAdvisoryErrands)) {
        final id = stop.tasks
            .firstWhere((t) => !hoursAreAdvisory(t.errandId))
            .errandId;
        final title = activeErrands.firstWhere((e) => e.id == id).title;
        return '“$title” no longer fits the reported opening hours. Change the place or trip time and recalculate.';
      }
    }
    return null;
  }
}
