import 'package:flutter/foundation.dart';
import '../../today/domain/day.dart';
import '../domain/clarification.dart';
import '../data/clarification_repository.dart';
import '../data/clarification_resolver.dart';

class ClarificationCoordinator extends ChangeNotifier {
  ClarificationCoordinator(this.repository, this.resolver);
  final ClarificationRepository repository;
  final ClarificationResolver resolver;
  ClarificationSession session = ClarificationSession();
  String? sourceKey, storageError;
  final errors = <String, String>{};
  final _flights = <String, Future<void>>{};
  bool _closed = false;
  int _stamp(int previous) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return now > previous ? now : previous + 1;
  }

  void _emit() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }

  Future<void> bind(String key) async {
    if (sourceKey == key) return;
    sourceKey = key;
    session = ClarificationSession();
    errors.clear();
    storageError = null;
    try {
      final saved = await repository.read(key);
      if (sourceKey == key) session = saved;
    } catch (_) {
      storageError =
          'Saved answers could not be restored. Your errands are kept.';
    }
  }

  String? draftFor(ClarificationContext c) =>
      session.records[c.key]?.draft ?? record(c)?.draft;
  bool _sameResolvedScope(ClarificationRecord r, ClarificationContext c) {
    if (!r.applied ||
        r.proposesRules ||
        r.context.preferenceKey != c.preferenceKey) {
      return false;
    }
    return switch (r.resolution!.kind) {
      'preference' => true,
      'timing' =>
        r.context.facts['timing'] == c.facts['timing'] &&
            r.context.facts['minute'] == c.facts['minute'],
      'dependency' =>
        clarificationHash(r.context.facts['dependencies'] as Object) ==
            clarificationHash(c.facts['dependencies'] as Object),
      _ => false,
    };
  }

  ClarificationRecord? record(ClarificationContext c) {
    final direct = session.records[c.key];
    if (direct != null &&
        direct.status != 'draft' &&
        !_sameResolvedScope(direct, c)) {
      return direct;
    }
    ClarificationRecord? latest;
    for (final r in session.records.values) {
      if (_sameResolvedScope(r, c) &&
          (latest == null || r.revision > latest.revision)) {
        latest = r;
      }
    }
    return latest ?? direct;
  }

  Future<void> _save() async {
    final key = sourceKey!, current = session;
    bool isCurrent() => sourceKey == key && identical(session, current);
    try {
      await repository.save(key, current);
      if (isCurrent()) storageError = null;
    } catch (_) {
      if (isCurrent()) {
        storageError =
            'Your answer could not be saved. Retry saving before closing.';
      }
      rethrow;
    } finally {
      if (isCurrent()) _emit();
    }
  }

  Future<void> saveDraft(ClarificationContext c, String text) async {
    final r = session.records.putIfAbsent(
      c.key,
      () => ClarificationRecord(context: c),
    );
    r.draft = text;
    r.draftRevision = _stamp(r.draftRevision);
    try {
      await _save();
    } catch (_) {}
  }

  bool isRunning(ClarificationContext context) =>
      _flights.containsKey('$sourceKey:${context.key}');
  Future<void> submit(
    ClarificationContext c,
    String answer, {
    bool retry = false,
    bool savedOnly = false,
  }) {
    final key = '$sourceKey:${c.key}';
    if (_flights[key] != null) return _flights[key]!;
    final future = _submit(c, answer, retry, savedOnly);
    _flights[key] = future;
    return future.whenComplete(() {
      if (identical(_flights[key], future)) _flights.remove(key);
      _emit();
    });
  }

  Future<void> _submit(
    ClarificationContext c,
    String answer,
    bool retry,
    bool savedOnly,
  ) async {
    final previous = record(c);
    if (!retry &&
        !savedOnly &&
        previous?.answer.trim() == answer.trim() &&
        previous?.resolution != null) {
      return;
    }
    final isResume =
        (retry || savedOnly) && previous?.answer.trim() == answer.trim();
    final r = isResume && previous != null
        ? previous
        : ClarificationRecord(
            context: c,
            answer: answer,
            history: previous?.status == 'unresolved'
                ? [...previous!.history, previous.answer].reversed.fold(
                    <String>[],
                    (values, text) => values.join().length + text.length <= 8000
                        ? [text, ...values]
                        : values,
                  )
                : [...?previous?.history],
            revision: _stamp(previous?.revision ?? 0),
          );
    final key = sourceKey;
    session.records[c.key] = r;
    r.status = 'processing';
    r.updatedAt = _stamp(r.updatedAt);
    errors.remove(c.key);
    _emit();
    try {
      await _save(); // Durable answer before a request, without touching Today.
      if (sourceKey != key || !identical(session.records[c.key], r)) return;
      final proposed = await resolver.resolve(
        c,
        r.answer,
        history: r.history,
        retry: retry,
        savedOnly: savedOnly,
      );
      if (sourceKey != key || !identical(session.records[c.key], r)) return;
      final result = ClarificationResolution.fromJson({
        'id': c.id,
        ...proposed.toJson(),
      }, c);
      r.resolution = result;
      r.status = result.outcome;
      r.draft = null;
      r.draftRevision = _stamp(r.draftRevision);
      r.updatedAt = _stamp(r.updatedAt);
      await _save();
    } catch (e) {
      if (sourceKey != key || !identical(session.records[c.key], r)) return;
      // Keep a completed resolution if only saving failed: Retry save is free.
      if (r.resolution == null || !r.resolution!.resolved) r.status = 'failed';
      r.updatedAt = _stamp(r.updatedAt);
      errors[c.key] = e.toString();
      try {
        await _save();
      } catch (_) {}
    }
    _emit();
  }

  Future<void> resumeSaved(Iterable<ClarificationContext> contexts) async {
    for (final c in contexts) {
      final r = record(c);
      if (r?.status == 'processing') {
        await submit(c, r!.answer, savedOnly: true);
      }
    }
  }

  Future<void> applyStructured(
    ClarificationContext c,
    ClarificationResolution result,
    String answer,
  ) async {
    final previous = record(c);
    session.records[c.key] = ClarificationRecord(
      context: c,
      answer: answer,
      status: result.outcome,
      resolution: result,
      revision: _stamp(previous?.revision ?? 0),
      updatedAt: _stamp(previous?.updatedAt ?? 0),
    );
    await _save();
  }

  Future<void> retrySave() => _save();
  Future<void> approveRules(ClarificationContext c, bool approved) async {
    final r = record(c);
    if (r == null) return;
    r.rulesApproved = approved;
    r.updatedAt = _stamp(r.updatedAt);
    await _save();
  }

  Map<String, String> deferred(String date) => session.deferrals[date] ?? {};
  List<Errand> affectedByDeferral(String id, List<Errand> errands) {
    final ids = {id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final e in errands) {
        if (!ids.contains(e.id) && e.afterErrandIds.any(ids.contains)) {
          ids.add(e.id);
          changed = true;
        }
      }
    }
    return errands.where((e) => ids.contains(e.id)).toList();
  }

  Future<void> defer(String date, List<Errand> affected, String reason) async {
    final values = session.deferrals.putIfAbsent(date, () => {});
    for (final e in affected) {
      values.putIfAbsent(
        e.id,
        () => e.id == affected.first.id
            ? reason
            : 'Depends on an errand you left out of this plan.',
      );
    }
    session.deferralRevisions[date] = _stamp(
      session.deferralRevisions[date] ?? 0,
    );
    await _save();
  }

  Future<void> include(String date, Errand e) async {
    final values = session.deferrals.putIfAbsent(date, () => {});
    if (e.afterErrandIds.any(values.containsKey)) {
      throw StateError('Include this errand’s prerequisites first.');
    }
    values.remove(e.id);
    session.deferralRevisions[date] = _stamp(
      session.deferralRevisions[date] ?? 0,
    );
    await _save();
  }
}
