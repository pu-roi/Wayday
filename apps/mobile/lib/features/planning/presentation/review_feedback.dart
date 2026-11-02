import 'package:flutter/material.dart';
import '../../today/domain/day.dart';
import '../domain/trip_departure.dart';
import '../domain/planning_input_checks.dart';

class ReviewFeedback extends StatelessWidget {
  const ReviewFeedback({
    required this.day,
    required this.onDate,
    required this.onDeparture,
    required this.onRetrySave,
    required this.onIssue,
    this.issues = const [],
    this.error,
    this.orderIssue,
    this.storageError,
    super.key,
  });
  final DayPlan day;
  final String? error, orderIssue, storageError;
  final VoidCallback onDate, onDeparture, onRetrySave;
  final List<PlanningInputIssue> issues;
  final ValueChanged<PlanningInputIssue> onIssue;

  @override
  Widget build(BuildContext context) {
    final past = tripDepartureHasPassed(day);
    final duplicatePastError =
        past &&
        error ==
            'The departure is in the past. Choose a new date and departure time.';
    if (!past &&
        error == null &&
        orderIssue == null &&
        storageError == null &&
        issues.isEmpty) {
      return const SizedBox.shrink();
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .4,
      ),
      child: SingleChildScrollView(
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (storageError != null) ...[
                _notice(storageError!),
                TextButton(
                  onPressed: onRetrySave,
                  child: const Text('Retry saving trip settings'),
                ),
              ],
              if (past)
                _DepartureWarning(
                  message:
                      'Departure has passed: ${day.date}, ${formatMinute(day.departure)}.',
                  onDate: onDate,
                  onDeparture: onDeparture,
                ),
              if (orderIssue != null) _notice(orderIssue!),
              for (final issue in issues) ...[
                _notice(issue.message),
                TextButton(
                  onPressed: () => onIssue(issue),
                  child: Text(switch (issue.field) {
                    PlanningInputField.date => 'Change date',
                    PlanningInputField.departure => 'Change departure',
                    PlanningInputField.deadline => 'Change finish time',
                    PlanningInputField.errand =>
                      issue.errand!.title.trim().isEmpty
                          ? 'Edit errand'
                          : 'Edit ${issue.errand!.title}',
                    PlanningInputField.input => 'Back to Today',
                  }),
                ),
              ],
              if (error != null &&
                  !duplicatePastError &&
                  error != orderIssue &&
                  !issues.any((i) => i.message == error))
                _notice(error!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notice(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Text(text),
  );
}

class _DepartureWarning extends StatelessWidget {
  const _DepartureWarning({
    required this.message,
    required this.onDate,
    required this.onDeparture,
  });
  final String message;
  final VoidCallback onDate, onDeparture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: colors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(onPressed: onDate, child: const Text('Change date')),
              TextButton(
                onPressed: onDeparture,
                child: const Text('Change departure'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
