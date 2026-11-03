import '../../errands/domain/errand.dart';

/// Google display/assessment data is transient and is never template content.
enum HoursState { notRequested, available, notProvided, failed, stale }

class HoursDay {
  const HoursDay(
    this.state, {
    this.windows,
    this.usual = false,
    this.weekdays = const [],
    this.checkedAt,
    this.outsideCoverage = false,
  });
  final HoursState state;
  final List<List<int>>? windows;
  final bool usual;
  final bool outsideCoverage;
  final List<String> weekdays;
  final DateTime? checkedAt;
  bool? openAt(int seconds) => state != HoursState.available || windows == null
      ? null
      : windows!.any((w) => seconds >= w[0] && seconds < w[1]);
  bool fits(int start, int finish) =>
      windows == null || windows!.any((w) => start >= w[0] && finish <= w[1]);
  bool possible(int start, int end, int duration, {int? latestStart}) =>
      windows == null ||
      windows!.any(
        (w) =>
            (latestStart == null ||
                (w[0] > start ? w[0] : start) <= latestStart) &&
            (w[0] > start ? w[0] : start) + duration <=
                (w[1] < end ? w[1] : end),
      );
}

class BusinessHours {
  const BusinessHours({
    this.version = 0,
    this.offset,
    this.coverageStart,
    this.current,
    this.regular,
    this.checkedAt,
    this.failed = false,
  });
  final int version;
  final int? offset;
  final String? coverageStart;
  final Map<String, dynamic>? current, regular;
  final DateTime? checkedAt;
  final bool failed;
  bool get checked => version == 1 && !failed;
  BusinessHours failure() => BusinessHours(
    version: version,
    offset: offset,
    coverageStart: coverageStart,
    current: current,
    regular: regular,
    checkedAt: checkedAt,
    failed: true,
  );

  factory BusinessHours.fromJson(Map<Object?, Object?> value, DateTime at) {
    try {
      Map<String, dynamic>? block(String key) {
        final raw = value[key];
        if (raw == null) return null;
        if (raw is! Map) throw const FormatException('Invalid hours');
        return Map<String, dynamic>.from(raw);
      }

      return BusinessHours(
        version: value['hoursVersion'] as int? ?? 0,
        offset: value['utcOffset'] as int?,
        coverageStart: value['hoursDate'] as String?,
        current: block('currentHours'),
        regular: block('regularHours'),
        checkedAt: at,
      );
    } catch (_) {
      return BusinessHours(version: 1, checkedAt: at, failed: true);
    }
  }

  HoursDay day(String date, {DateTime? now}) {
    HoursDay unknown(HoursState state) => HoursDay(state, checkedAt: checkedAt);
    if (failed) return unknown(HoursState.failed);
    if (version != 1) return unknown(HoursState.notRequested);
    if (checkedAt == null ||
        (now ?? DateTime.now()).difference(checkedAt!) >=
            const Duration(minutes: 5)) {
      return unknown(HoursState.stale);
    }
    if (current == null && regular == null) {
      return unknown(HoursState.notProvided);
    }
    try {
      // Wayday's eligible places and planning clock are Philippine/Asia-Manila.
      if (offset != 480) {
        throw const FormatException('Unexpected place timezone');
      }
      DateTime dateOnly(String value) {
        final parsed = DateTime.parse('${value}T00:00:00Z');
        if (value.length != 10 ||
            parsed.toIso8601String().split('T').first != value) {
          throw const FormatException('Invalid hours date');
        }
        return parsed;
      }

      final target = dateOnly(date);
      final base = coverageStart == null ? null : dateOnly(coverageStart!);
      final covered =
          base != null &&
          !target.isBefore(base) &&
          target.isBefore(base.add(const Duration(days: 7)));
      final block = covered && current != null ? current : regular;
      if (block == null) {
        return HoursDay(
          HoursState.notProvided,
          checkedAt: checkedAt,
          outsideCoverage: !covered && current != null,
        );
      }
      final dated = covered && current != null;
      final raw = block['periods'];
      if (raw is! List || raw.length > 100) {
        throw const FormatException('Invalid periods');
      }
      final windows = <List<int>>[];
      for (final value in raw) {
        final period = Map<String, dynamic>.from(value as Map);
        final open = Map<String, dynamic>.from(period['open'] as Map);
        final close = period['close'] == null
            ? null
            : Map<String, dynamic>.from(period['close'] as Map);
        int clock(Map<String, dynamic> p) {
          final hour = p['hour'] as int, minute = p['minute'] as int;
          if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
            throw const FormatException('Invalid clock');
          }
          return hour * 3600 + minute * 60;
        }

        int weekday(Map<String, dynamic> p) {
          final day = p['day'] as int;
          if (day < 0 || day > 6) {
            throw const FormatException('Invalid weekday');
          }
          return day;
        }

        final startClock = clock(open), startDay = weekday(open);
        if (close == null &&
            startDay == 0 &&
            startClock == 0 &&
            (!dated || open['date'] == null)) {
          windows.add([0, 86400]);
          continue;
        }
        if (dated) {
          DateTime point(Map<String, dynamic> p) {
            final rawDate = p['date'] as String?;
            final day = rawDate == null
                ? base.add(
                    Duration(days: (weekday(p) - base.weekday % 7 + 7) % 7),
                  )
                : dateOnly(rawDate);
            if (day.weekday % 7 != weekday(p)) {
              throw const FormatException('Inconsistent hours date');
            }
            return day.add(Duration(seconds: clock(p)));
          }

          final start = point(open);
          var end = close == null
              ? base.add(const Duration(days: 7))
              : point(close);
          if (close != null && close['date'] == null && end.isBefore(start)) {
            end = end.add(const Duration(days: 7));
          }
          final a = start.difference(target).inSeconds;
          final b = end.difference(target).inSeconds;
          if (b <= a) throw const FormatException('Invalid interval');
          if (b > 0 && a < 86400) {
            windows.add([a.clamp(0, 86400), b.clamp(0, 86400)]);
          }
        } else {
          if (close == null) {
            throw const FormatException('Missing closing time');
          }
          final start = startDay * 86400 + startClock;
          var end = weekday(close) * 86400 + clock(close);
          if (end <= start) end += 7 * 86400;
          final midnight = target.weekday % 7 * 86400;
          for (final shift in [-7 * 86400, 0, 7 * 86400]) {
            final a = start + shift - midnight, b = end + shift - midnight;
            if (b > 0 && a < 86400) {
              windows.add([a.clamp(0, 86400), b.clamp(0, 86400)]);
            }
          }
        }
      }
      windows.sort((a, b) => a[0].compareTo(b[0]));
      final merged = <List<int>>[];
      for (final w in windows) {
        if (merged.isNotEmpty && w[0] <= merged.last[1]) {
          if (w[1] > merged.last[1]) merged.last[1] = w[1];
        } else {
          merged.add([...w]);
        }
      }
      final text = (block['weekdays'] as List? ?? const []).cast<String>();
      if (text.length > 7 || text.any((s) => s.length > 500)) {
        throw const FormatException('Invalid weekday text');
      }
      return HoursDay(
        HoursState.available,
        windows: merged,
        usual: !dated,
        weekdays: text,
        checkedAt: checkedAt,
      );
    } catch (_) {
      return unknown(HoursState.failed);
    }
  }
}

/// Trip context is local filtering input, not another provider request.
class HoursQuery {
  const HoursQuery(
    this.date,
    this.departure,
    this.deadline,
    this.visitMinutes, {
    this.timing = TimingRule.anytime,
    this.minute,
    this.mayShareStop = true,
  });
  final String date;
  final int departure, deadline, visitMinutes;
  final TimingRule timing;
  final int? minute;
  final bool mayShareStop;

  Object get context =>
      (date, departure, deadline, visitMinutes, timing, minute, mayShareStop);

  bool permits(BusinessHours hours) => permitsDay(hours.day(date));

  bool permitsDay(HoursDay hours) {
    final start = departure * 60;
    final end = deadline * 60;
    final duration = visitMinutes * 60 + 300;
    final boundary = minute == null ? null : minute! * 60;
    if (boundary != null && timing == TimingRule.at) {
      return boundary >= start &&
          boundary + duration <= end &&
          hours.fits(boundary, boundary + duration);
    }
    // Arrive by constrains the stop arrival. A shared stop can start this
    // particular task later, so its service window needs the joint solver.
    return hours.possible(
      start,
      boundary != null && timing == TimingRule.finishBefore && boundary < end
          ? boundary
          : end,
      duration,
      latestStart: timing == TimingRule.arriveBy && !mayShareStop
          ? boundary
          : null,
    );
  }
}
