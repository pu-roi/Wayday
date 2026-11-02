part of 'planning_controller.dart';

extension FreshAnalysis on PlanningController {
  bool get supportsFreshAnalysis => interpreter is FreshErrandInterpreter;
  bool get analysisRunning => _analysisFlight != null;
  bool get hasPendingAnalysis =>
      clarifications.session.analysis?.pending != null;
  List<Errand> get _analysisErrands => reviewErrands.map((errand) {
    var e = errand;
    final key = overrides[e.id];
    final place = candidates[e.id]
        ?.where((p) => p.key == key)
        .firstOrNull
        ?.place;
    if (key != null && place != null) {
      e = e.copyWith(
        placeIntent: place,
        place: place.label,
        confirmedFields: {...e.confirmedFields, 'place'},
      );
    }
    return approved.contains(e.id)
        ? e.copyWith(
            durationConfirmed: true,
            confirmedFields: {
              ...e.confirmedFields,
              'timing',
              'optional',
              'dependencies',
            },
          )
        : e;
  }).toList();
  Future<void> analyzeAgain({bool retry = false, bool savedOnly = false}) {
    if (_analysisFlight != null) return _analysisFlight!;
    final flight = _analyzeAgain(retry: retry, savedOnly: savedOnly);
    _analysisFlight = flight;
    _emit();
    return flight.whenComplete(() {
      if (identical(_analysisFlight, flight)) _analysisFlight = null;
      _emit();
    });
  }

  Future<void> _analyzeAgain({
    required bool retry,
    required bool savedOnly,
  }) async {
    if (interpreter is! FreshErrandInterpreter ||
        interpretation == null ||
        interpretationStale) {
      return;
    }
    final epoch = _epoch, source = clarifications.sourceKey;
    bool current() =>
        !_closed && epoch == _epoch && source == clarifications.sourceKey;
    error = null;
    try {
      var state = clarifications.session.analysis;
      var run = state?.pending;
      if (run != null && !run.matches(_analysisErrands)) {
        final errands = _analysisErrands;
        final ids = errands.map((e) => e.id).toSet();
        await clarifications.saveAnalysis(
          AnalysisState(
            revision: max(
              DateTime.now().microsecondsSinceEpoch,
              state!.revision + 1,
            ),
            errands: errands,
            result: Interpretation(
              [for (final e in errands) needs[e.id]!],
              additions: interpretation!.additions
                  .where((n) => !ids.contains(n.id))
                  .toList(),
            ),
            activeId: state.activeId,
            answerBases: state.answerBases,
          ),
        );
        if (current()) {
          error =
              'Your errands changed. Analyze again to use the updated review.';
        }
        return;
      }
      if (run == null) {
        if (savedOnly) return;
        final errands = _analysisErrands;
        final answers = <String, List<Map<String, dynamic>>>{};
        final answerBases = <String, ErrandNeed>{};
        for (final e in errands) {
          final applicable = clarifications.session.records.values.where(
            (r) =>
                r.applied &&
                r.context.id == e.id &&
                r.context.facts['title'] == e.title &&
                r.context.facts['notes'] == e.notes &&
                identical(clarifications.record(r.context), r),
          );
          answers[e.id] = [
            for (final r in applicable)
              {
                'question': r.context.question,
                'answer': r.answer,
                'kind': r.resolution!.kind,
                'rulesApproved': r.rulesApproved,
              },
          ];
          if (applicable.any((r) => !r.proposesRules)) {
            answerBases[e.id] = state?.answerBases[e.id] ?? needs[e.id]!;
          }
        }
        final input = day.copyWith(errands: errands);
        final id =
            '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random.secure().nextInt(1 << 32).toRadixString(36)}';
        run = AnalysisRun(
          id: id,
          body: interpretationRequest(input, savedAnswers: answers),
          errands: errands,
          answerBases: answerBases,
        );
        final ids = errands.map((e) => e.id).toSet();
        final snapshot = Interpretation(
          [for (final e in errands) needs[e.id]!],
          additions: interpretation!.additions
              .where((n) => !ids.contains(n.id))
              .toList(),
        );
        state = AnalysisState(
          revision: max(
            DateTime.now().microsecondsSinceEpoch,
            (state?.revision ?? 0) + 1,
          ),
          errands: errands,
          result: snapshot,
          activeId: state?.activeId,
          pending: run,
          answerBases: state?.answerBases ?? const {},
        );
        await clarifications.saveAnalysis(state);
        if (!current()) return;
      } else if (!retry && !savedOnly) {
        savedOnly = true;
      }
      final activeRun = run;
      final restoredRun = AnalysisRun.fromJson(
        activeRun.toJson(),
        resolveGooglePin: resolveGooglePin,
      );
      final input = day.copyWith(errands: restoredRun.errands);
      final value = await (interpreter as FreshErrandInterpreter).analyze(
        input,
        runId: activeRun.id,
        body: activeRun.body,
        retry: retry,
        savedOnly: savedOnly,
      );
      if (!current() ||
          clarifications.session.analysis?.pending?.id != activeRun.id) {
        return;
      }
      final next = AnalysisState(
        revision: max(
          DateTime.now().microsecondsSinceEpoch,
          state!.revision + 1,
        ),
        errands: restoredRun.errands,
        result: value,
        activeId: activeRun.id,
        answerBases: restoredRun.answerBases,
      );
      await clarifications.saveAnalysis(next);
      if (!current()) return;
      interpretation = value;
      _reviewItems
        ..clear()
        ..addEntries(restoredRun.errands.map((e) => MapEntry(e.id, e)));
      _originalIds
        ..clear()
        ..addAll(_reviewItems.keys);
      needs
        ..clear()
        ..addEntries(
          [...value.needs, ...value.additions].map((n) => MapEntry(n.id, n)),
        );
      approved.clear();
      additions.clear();
      candidates.removeWhere((id, _) => !overrides.containsKey(id));
      discoveryResults.clear();
      _alternativeBrowses.clear();
      _alternativeSearches.clear();
      _matrixAt = null;
      result = null;
      stage = PreparationStage.review;
      error = null;
    } catch (e) {
      if (current()) {
        error = e is PlanningFailure
            ? e.message
            : 'Fresh understanding could not be saved. Your previous review is kept. Check its saved answer or retry.';
      }
    }
    _emit();
  }
}
