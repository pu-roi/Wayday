part of 'clarification_coordinator.dart';

extension LocationAssessmentCoordinator on ClarificationCoordinator {
  LocationAssessment? locationAssessment(LocationAssessmentContext context) =>
      session.locationAssessments[context.key];
  bool locationAssessmentRunning(LocationAssessmentContext context) =>
      _locationFlights.containsKey('$sourceKey:${context.key}');

  Future<void> assessLocation(
    LocationAssessmentContext context, {
    bool retry = false,
    bool savedOnly = false,
  }) {
    final key = '$sourceKey:${context.key}';
    if (_locationFlights[key] != null) return _locationFlights[key]!;
    final existing = locationAssessment(context);
    if (existing?.applied == true) return Future.value();
    // Reopening or tapping again after failure cannot implicitly regenerate.
    if (existing != null && !retry && !savedOnly) {
      errors[context.key] =
          'Check the saved location answer or explicitly retry Gemini. Your choices are kept.';
      _emit();
      return Future.value();
    }
    final future = _assessLocation(context, retry: retry, savedOnly: savedOnly);
    _locationFlights[key] = future;
    return future.whenComplete(() {
      if (identical(_locationFlights[key], future)) {
        _locationFlights.remove(key);
      }
      _emit();
    });
  }

  Future<void> _assessLocation(
    LocationAssessmentContext context, {
    required bool retry,
    required bool savedOnly,
  }) async {
    final source = sourceKey, previous = locationAssessment(context);
    if (source == null) return;
    final record = previous != null && (savedOnly || retry)
        ? previous
        : LocationAssessment(
            context: context,
            revision: _stamp(previous?.revision ?? 0),
            updatedAt: _stamp(0),
          );
    session.locationAssessments[context.key] = record;
    while (session.locationAssessments.length > 96) {
      session.locationAssessments.remove(
        session.locationAssessments.keys.first,
      );
    }
    bool current() =>
        !_closed &&
        sourceKey == source &&
        identical(session.locationAssessments[context.key], record);
    record.status = 'processing';
    record.persisted = false;
    record.updatedAt = _stamp(record.updatedAt);
    errors.remove(context.key);
    _emit();
    try {
      await _save();
      if (!current()) return;
      final proposed = await locationResolver.assess(
        context,
        retry: retry,
        savedOnly: savedOnly,
      );
      if (!current()) return;
      final validated = LocationAssessmentResult.fromJson({
        'id': context.id,
        ...proposed.toJson(),
      }, context.id);
      record.result = validated;
      record.status = 'completed';
      record.persisted = false;
      record.updatedAt = _stamp(record.updatedAt);
      await _save();
    } catch (error) {
      if (!current()) return;
      if (record.result == null) record.status = 'failed';
      errors[context.key] = error.toString();
      // A result that only failed local storage remains available for free save retry.
    }
    _emit();
  }

  Future<void> resumeLocationAssessments(
    Iterable<LocationAssessmentContext> contexts,
  ) async {
    for (final context in contexts) {
      if (locationAssessment(context)?.status == 'processing') {
        await assessLocation(context, savedOnly: true);
      }
    }
  }
}
