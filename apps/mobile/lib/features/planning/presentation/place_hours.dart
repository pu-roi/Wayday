import 'package:flutter/material.dart';
import '../../places/domain/place_intent.dart';
import '../domain/recommendation.dart';
import '../domain/planning_models.dart' show placeKey;
import 'planning_controller.dart';

/// Hours belong in disclosed details and alternatives, never as guessed labels.
class PlaceHours extends StatefulWidget {
  const PlaceHours({
    required this.model,
    required this.place,
    this.compact = false,
    super.key,
  });
  final PlanningController model;
  final PlaceIntent place;
  final bool compact;
  @override
  State<PlaceHours> createState() => _PlaceHoursState();
}

class _PlaceHoursState extends State<PlaceHours> {
  bool weekly = false, checking = false;
  int checkRevision = 0;
  String? error;
  @override
  void didUpdateWidget(covariant PlaceHours oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (placeKey(oldWidget.place) != placeKey(widget.place) ||
        oldWidget.model != widget.model) {
      checkRevision++;
      weekly = false;
      checking = false;
      error = null;
    }
  }

  Future<void> retry() async {
    final revision = ++checkRevision;
    final model = widget.model, place = widget.place;
    setState(() {
      checking = true;
      error = null;
    });
    try {
      await model.retryBusinessHours(place);
    } catch (_) {
      if (mounted && revision == checkRevision) {
        error = 'Hours could not be checked. Your place is kept.';
      }
    } finally {
      if (mounted && revision == checkRevision) {
        setState(() => checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model, place = widget.place;
    if (!place.isGoogle) {
      return const Text('Business hours are unavailable for this pin.');
    }
    final hours = model.hoursFor(place);
    String clock(int value) => value == 86400
        ? 'midnight'
        : TimeOfDay(
            hour: value ~/ 3600,
            minute: value % 3600 ~/ 60,
          ).format(context);
    String summary() => switch (hours.state) {
      HoursState.notProvided =>
        hours.outsideCoverage
            ? 'Hours unavailable for this trip date'
            : 'Hours not provided by Google Maps',
      HoursState.notRequested => 'Business hours have not been checked',
      HoursState.failed => 'Business hours could not be checked',
      HoursState.stale => 'Business hours need refreshing',
      HoursState.available =>
        '${hours.usual ? 'Usual hours' : 'Hours'} for ${model.day.date}: ${hours.windows!.isEmpty
            ? 'Closed'
            : hours.windows!.length == 1 && hours.windows!.single[0] == 0 && hours.windows!.single[1] == 86400
            ? 'Open 24 hours'
            : hours.windows!.map((w) => '${clock(w[0])}–${clock(w[1])}').join(', ')}',
    };
    final stop = model.proposalReady
        ? model.result?.schedule.stops
              .where((s) => s.placeKey == placeKey(place))
              .firstOrNull
        : null;
    final retryable = {
      HoursState.failed,
      HoursState.stale,
      HoursState.notRequested,
    }.contains(hours.state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary()),
        if (hours.usual) const Text('Special-date hours are not confirmed.'),
        if (stop != null && hours.state == HoursState.available)
          Text(
            hours.fits(stop.tasks.first.start, stop.departure)
                ? 'Expected open for your planned visit'
                : 'The planned visit does not fit these hours',
          ),
        if (!widget.compact && hours.checkedAt != null)
          Builder(
            builder: (_) {
              final at = hours.checkedAt!.toUtc().add(const Duration(hours: 8));
              return Text(
                'Checked ${at.toIso8601String().split('T').first} ${TimeOfDay(hour: at.hour, minute: at.minute).format(context)} · Google Maps',
              );
            },
          ),
        if (!widget.compact && hours.weekdays.isNotEmpty) ...[
          TextButton(
            onPressed: () => setState(() => weekly = !weekly),
            child: Text(weekly ? 'Hide weekly hours' : 'Weekly hours'),
          ),
          if (weekly)
            for (final day in hours.weekdays) Text(day),
        ],
        if (error != null && retryable)
          Semantics(liveRegion: true, child: Text(error!)),
        if (checking)
          Semantics(liveRegion: true, child: Text('Checking business hours…')),
        if (retryable)
          TextButton(
            onPressed: checking ? null : retry,
            child: Text(
              hours.state == HoursState.notRequested
                  ? 'Check hours'
                  : 'Retry hours check',
            ),
          ),
      ],
    );
  }
}
