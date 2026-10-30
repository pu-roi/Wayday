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
              if (past) ...[
                _notice(
                  'Departure has passed: ${day.date}, ${formatMinute(day.departure)}.',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: onDate,
                      child: const Text('Change date'),
                    ),
                    TextButton(
                      onPressed: onDeparture,
                      child: const Text('Change departure'),
                    ),
                  ],
                ),
              ],
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
