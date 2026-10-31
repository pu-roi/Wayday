import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../places/domain/place_intent.dart';
import '../../today/domain/day.dart' show pilotToday;
import '../domain/recommendation.dart';
import '../domain/planning_models.dart' show placeKey;
import 'planning_controller.dart';

/// Hours belong in disclosed details and alternatives, never as guessed labels.
class PlaceHours extends StatefulWidget {
  const PlaceHours({
    required this.model,
    required this.place,
    this.compact = false,
    this.now,
    super.key,
  });
  final PlanningController model;
  final PlaceIntent place;
  final bool compact;
  final DateTime Function()? now;
  @override
  State<PlaceHours> createState() => _PlaceHoursState();
}

class _PlaceHoursState extends State<PlaceHours> {
  bool weekly = false, checking = false;
  int checkRevision = 0;
  String? error;
  Timer? refresh;
  DateTime get now => widget.now?.call() ?? DateTime.now();
  @override
  void initState() {
    super.initState();
    if (widget.place.isGoogle) scheduleRefresh();
  }

  void scheduleRefresh() {
    refresh = Timer(
      Duration(milliseconds: 60000 - now.millisecondsSinceEpoch % 60000),
      () {
        if (!mounted) return;
        setState(() {});
        scheduleRefresh();
      },
    );
  }

  @override
  void dispose() {
    refresh?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlaceHours oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (placeKey(oldWidget.place) != placeKey(widget.place) ||
        oldWidget.model != widget.model) {
      checkRevision++;
      weekly = false;
      checking = false;
      error = null;
      refresh?.cancel();
      if (widget.place.isGoogle) scheduleRefresh();
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
    final instant = now;
    final hours = model.hoursForDate(place, model.day.date, now: instant);
    final current = model.hoursForDate(
      place,
      pilotToday(instant),
      now: instant,
    );
    final local = instant.toUtc().add(const Duration(hours: 8));
    final open = current.openAt(
      local.hour * 3600 + local.minute * 60 + local.second,
    );
    final metadata = model.discovery?.metadata(place);
    final freshStatus =
        metadata != null &&
        !instant.isBefore(metadata.acquiredAt) &&
        instant.difference(metadata.acquiredAt) < const Duration(minutes: 5);
    final closedStatus =
        freshStatus &&
        {'CLOSED_PERMANENTLY', 'CLOSED_TEMPORARILY'}.contains(metadata.status);
    final status = closedStatus
        ? metadata.status == 'CLOSED_PERMANENTLY'
              ? 'Reported permanently closed'
              : 'Reported temporarily closed'
        : open == null
        ? null
        : '${current.usual ? 'Usually ' : ''}${open ? 'open' : 'closed'} now';
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
        if (status != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                !closedStatus && open == true
                    ? Icons.check_circle_outline
                    : Icons.schedule,
                size: 18,
                color: !closedStatus && open == true
                    ? context.wayday.link
                    : context.wayday.attention,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${status[0].toUpperCase()}${status.substring(1)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: !closedStatus && open == true
                        ? context.wayday.link
                        : context.wayday.attention,
                  ),
                ),
              ),
            ],
          ),
        Text(summary()),
        if (hours.usual) const Text('Special-date hours are not confirmed.'),
        if (stop != null &&
            hours.state == HoursState.available &&
            !closedStatus)
          Text(
            hours.fits(stop.tasks.first.start, stop.departure)
                ? '${hours.usual ? 'Usually' : 'Expected'} open for your planned visit'
                : hours.openAt(stop.tasks.first.start) == false
                ? '${hours.usual ? 'Usually closed' : 'Closed'} at your planned visit time'
                : hours.usual
                ? 'Usual hours end before your planned visit finishes'
                : 'Closes before your planned visit finishes',
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
