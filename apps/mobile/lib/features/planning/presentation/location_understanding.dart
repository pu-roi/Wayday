part of 'planning_controller.dart';

extension LocationUnderstanding on PlanningController {
  bool canRecommendPlaces(Errand e) {
    final n = effectiveNeed(e);
    if (n == null ||
        interpretationStale ||
        e.placeIntent.hasCoordinates ||
        hasSpecificSource(e) ||
        needsActualLocation(e, n) ||
        answerFor(e)?.proposesRules == true ||
        n.query.trim().isEmpty) {
      return false;
    }
    final questionNeed = _questionNeed(e);
    return questionContext(e).facts['kind'] == 'location' ||
        (!{'timing', 'dependency'}.contains(questionNeed.questionKind) &&
            questionNeed.questionRequired == false &&
            n.locationIntent == LocationIntent.flexible);
  }

  /// This is an explicit user decision, not language for Gemini to interpret.
  /// Leave discovery metadata intact so a gym stays a gym and brands survive.
  Future<void> recommendPlaces(Errand e) async {
    final context = questionContext(e);
    if (!canRecommendPlaces(e) || clarifications.isRunning(context)) {
      throw StateError(
        'Resolve the current question before recommending places.',
      );
    }
    await clarifications.applyStructured(
      context,
      ClarificationResolution(
        outcome: 'flexible',
        kind: context.facts['kind'] == 'location' ? 'location' : 'preference',
        summary: 'Wayday will recommend suitable places',
        locationIntent: LocationIntent.flexible,
      ),
      'Let Wayday recommend',
    );
  }

  LocationAssessmentContext locationContext(Errand errand) {
    final e = reviewInput(errand), n = needs[e.id];
    final preference = e.placeIntent;
    return LocationAssessmentContext({
      'version': 1,
      'id': e.id,
      'title': e.title,
      'notes': e.notes,
      'hasConfirmedLocation': e.placeIntent.hasCoordinates,
      'hasSpecificSource': hasSpecificSource(e),
      'placePreference': preference.kind == PlaceKind.search
          ? {
              'label': preference.label,
              'category': preference.category,
              'brand': preference.brand,
            }
          : null,
      'query': n?.query,
      'category': n?.category,
      'items': n?.items ?? <String>[],
      'answers': [
        for (final r in clarifications.session.records.values)
          if (r.applied &&
              r.context.id == e.id &&
              r.context.facts['title'] == e.title &&
              r.context.facts['notes'] == e.notes)
            {
              'question': r.context.question,
              'answer': r.answer,
              'result': r.resolution!.toJson(),
            },
      ],
    });
  }

  Future<void> recheckLocation(
    Errand e, {
    bool retry = false,
    bool savedOnly = false,
  }) async {
    if (needs[e.id] == null || e.placeIntent.hasCoordinates) return;
    await clarifications.assessLocation(
      locationContext(e),
      retry: retry,
      savedOnly: savedOnly,
    );
  }
}
