import '../../today/domain/day.dart';
import '../../errands/domain/errand_order.dart';

enum PlanningInputField { date, departure, deadline, errand, input }

class PlanningInputIssue {
  const PlanningInputIssue(
    this.field,
    this.message, {
    this.errand,
    this.kind = 'invalid_input',
  });
  final PlanningInputField field;
  final String message, kind;
  final Errand? errand;
}

/// Structural errors cannot be interpreted or scheduled safely. Keep this check
/// outside prompt construction so rejecting bad input never changes cache keys.
List<PlanningInputIssue> errandFieldChecks(List<Errand> errands) {
  if (errands.isEmpty || errands.length > 12) {
    return [
      const PlanningInputIssue(
        PlanningInputField.input,
        'Plan between one and twelve errands.',
      ),
    ];
  }
  final seen = <String>{};
  final issues = <PlanningInputIssue>[];
  for (final e in errands) {
    if (e.id.trim().isEmpty || !seen.add(e.id)) {
      issues.add(
        const PlanningInputIssue(
          PlanningInputField.input,
          'Some errands have missing or duplicate identities. Review them in Today.',
        ),
      );
    } else if (e.title.trim().isEmpty) {
      issues.add(
        PlanningInputIssue(
          PlanningInputField.errand,
          'Give this errand a name.',
          errand: e,
        ),
      );
    } else if (e.durationMinutes < 1 || e.durationMinutes > 1440) {
      issues.add(
        PlanningInputIssue(
          PlanningInputField.errand,
          '“${e.title}” needs a visit time between 1 and 1,440 minutes.',
          errand: e,
        ),
      );
    } else if ((e.minute != null && (e.minute! < 0 || e.minute! > 1439)) ||
        (e.timing != TimingRule.anytime && e.minute == null)) {
      issues.add(
        PlanningInputIssue(
          PlanningInputField.errand,
          'Choose a valid time for “${e.title}”.',
          errand: e,
        ),
      );
    }
  }
  return issues;
}

/// Prove only conflicts that hold even with zero road travel. Feasibility still
/// requires real roads, waiting, shared visits and unknown-hour warnings later.
List<PlanningInputIssue> planningInputChecks(
  DayPlan day,
  List<Errand> errands,
) {
  final issues = errandFieldChecks(errands);
  final parsed = DateTime.tryParse(day.date);
  if (parsed == null || calendarDate(parsed) != day.date) {
    issues.add(
      const PlanningInputIssue(
        PlanningInputField.date,
        'Choose a valid trip date.',
      ),
    );
  }
  if (day.timeZone != 'Asia/Manila') {
    issues.add(
      const PlanningInputIssue(
        PlanningInputField.input,
        'This trip needs the Asia/Manila time zone.',
      ),
    );
  }
  if (day.departure < 0 || day.departure > 1439) {
    issues.add(
      const PlanningInputIssue(
        PlanningInputField.departure,
        'Choose a valid departure time.',
      ),
    );
  }
  if (day.deadline < 0 ||
      day.deadline > 1439 ||
      day.deadline <= day.departure) {
    issues.add(
      const PlanningInputIssue(
        PlanningInputField.deadline,
        'The final deadline must follow departure.',
      ),
    );
  }
  if (issues.isNotEmpty) return issues;
  final order = ErrandOrder.reconcile(errands);
  if (order.issue != null) {
    return issues; // The existing graph issue owns recovery.
  }
  final byId = {for (final e in errands) e.id: e};
  final needed = <String>{};
  void require(String id) {
    if (!needed.add(id)) return;
    for (final dependency in byId[id]!.afterErrandIds) {
      require(dependency);
    }
  }

  for (final e in errands.where((e) => !e.optional)) {
    require(e.id);
  }
  final earliestFinish = <String, int>{};
  for (final e in order.items) {
    var start = day.departure;
    for (final dependency in e.afterErrandIds) {
      final finish = earliestFinish[dependency]!;
      if (finish > start) {
        start = finish; // Same-stop work need not add road time.
      }
    }
    final fixed = e.minute;
    String? conflict;
    if (e.timing == TimingRule.at) {
      if (start > fixed!) {
        conflict =
            '“${e.title}” is set for ${formatMinute(fixed)}, before it can start after your ${formatMinute(day.departure)} departure and prerequisites.';
      }
      if (fixed > start) start = fixed;
    } else if (e.timing == TimingRule.arriveBy && day.departure > fixed!) {
      // Arrival can precede another task's service at a shared physical stop.
      conflict =
          '“${e.title}” is due by ${formatMinute(fixed)}, before your ${formatMinute(day.departure)} departure.';
    }
    final finish = start + e.durationMinutes;
    earliestFinish[e.id] = finish;
    if (e.timing == TimingRule.finishBefore && finish + 5 > fixed!) {
      conflict ??=
          '“${e.title}” cannot finish before ${formatMinute(fixed)} with its ${e.durationMinutes}-minute visit and 5-minute buffer.';
    }
    if (finish + 5 > day.deadline) {
      conflict ??=
          '“${e.title}” cannot fit before your ${formatMinute(day.deadline)} final deadline with its current visit time.';
    }
    if (conflict != null && needed.contains(e.id)) {
      issues.add(
        PlanningInputIssue(
          PlanningInputField.errand,
          conflict,
          errand: e,
          kind: 'time_conflict',
        ),
      );
    }
  }
  return issues;
}
