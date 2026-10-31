import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../today/data/day_repository.dart';
import '../../today/domain/day.dart';
import '../../today/presentation/today_controller.dart';
import '../data/itinerary_repository.dart';
import '../domain/planning_models.dart';
import 'planning_controller.dart';
import 'saved_plan_view.dart' show savedItineraryProvider;

class TripExit {
  const TripExit.paused(this.plan) : finished = false;
  const TripExit.finished() : plan = null, finished = true;
  final AcceptedItinerary? plan;
  final bool finished;
}

final tripFinishProvider = NotifierProvider<TripFinishController, bool>(
  TripFinishController.new,
);

class TripFinishController extends Notifier<bool> {
  Future<DayPlan>? _flight;
  String? _run;
  @override
  bool build() => false;
  Future<DayPlan> finish(String runId, int revision) {
    if (_flight != null) {
      if (_run != runId) {
        throw const PlanningFailure('Another trip is finishing. Please wait.');
      }
      return _flight!;
    }
    final today = ref.read(dayRepositoryProvider);
    final trips = ref.read(itineraryRepositoryProvider);
    state = true;
    _run = runId;
    final work = () async {
      final reset = await trips.finish(
        runId,
        today: today,
        expectedRevision: revision,
        stillCurrent: () => ref.read(todayProvider).revision == revision,
        now: DateTime.now(),
      );
      ref.read(todayProvider.notifier).applyFinishedReset(reset);
      ref.invalidate(savedItineraryProvider);
      return reset;
    }();
    _flight = work;
    work.then(
      (_) {
        _flight = null;
        state = false;
      },
      onError: (Object _, StackTrace _) {
        _flight = null;
        state = false;
      },
    );
    return work;
  }
}

/// Confirmation is shared by the navigation and existing-trip summary entry paths.
class FinishTripAction extends ConsumerStatefulWidget {
  const FinishTripAction({
    required this.plan,
    required this.onFinished,
    this.enabled = true,
    super.key,
  });
  final AcceptedItinerary plan;
  final VoidCallback onFinished;
  final bool enabled;
  @override
  ConsumerState<FinishTripAction> createState() => _FinishTripActionState();
}

class _FinishTripActionState extends ConsumerState<FinishTripAction> {
  bool working = false;
  bool confirming = false;
  String? error;
  int? confirmedRevision;
  @override
  void didUpdateWidget(covariant FinishTripAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.runId != widget.plan.runId) {
      confirmedRevision = null;
      error = null;
    }
  }

  Future<void> finish() async {
    if (working || confirming || ref.read(tripFinishProvider)) return;
    final revision = ref.read(todayProvider).revision;
    final runId = widget.plan.runId;
    if (confirmedRevision != revision) {
      confirming = true;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Finish trip and clear Today?'),
          scrollable: true,
          content: const Text(
            'All Today errands, locations and trip settings will reset, including errands added or left out of this trip. Trips you saved for reuse, recurring lists and saved places will stay.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Finish and clear Today'),
            ),
          ],
        ),
      );
      confirming = false;
      if (!mounted || confirmed != true) return;
      if (ref.read(todayProvider).revision != revision ||
          widget.plan.runId != runId) {
        setState(
          () => error =
              'Today changed. Review the confirmation again before finishing.',
        );
        return;
      }
      confirmedRevision = revision;
    }
    setState(() {
      working = true;
      error = null;
    });
    try {
      await ref.read(tripFinishProvider.notifier).finish(runId, revision);
      if (mounted) widget.onFinished();
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        if (failure is TodayChangedDuringFinish) {
          confirmedRevision = null;
          error =
              'Today changed. Review the confirmation again before finishing.';
        } else {
          error = failure is PlanningFailure
              ? failure.message
              : 'The trip could not be finished. Today and your trip progress are kept.';
        }
      });
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (error != null) Semantics(liveRegion: true, child: Text(error!)),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed:
              widget.enabled && !working && !ref.watch(tripFinishProvider)
              ? finish
              : null,
          icon: const Icon(Icons.flag_outlined),
          label: Text(
            working
                ? 'Finishing trip…'
                : error == null
                ? 'Finish trip'
                : 'Retry finishing trip',
          ),
        ),
      ),
    ],
  );
}
