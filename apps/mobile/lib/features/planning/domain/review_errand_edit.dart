import 'package:flutter/foundation.dart';

import '../../today/domain/day.dart';
import 'review_timing_edit.dart';

/// Manual fields only. Place data and model suggestions belong to other drafts.
class ReviewErrandEdit {
  ReviewErrandEdit._(this.values);

  final Map<String, dynamic> values;
  static const fields = {
    'timing',
    'optional',
    'notes',
    'duration',
    'dependencies',
  };

  factory ReviewErrandEdit.between(
    Errand before,
    Errand after, {
    Set<String> touched = const {},
  }) {
    bool confirmed(String field) =>
        touched.contains(field) ||
        (after.confirmedFields.contains(field) &&
            !before.confirmedFields.contains(field));
    return ReviewErrandEdit.fromJson({
      if (after.timing != before.timing ||
          after.minute != before.minute ||
          confirmed('timing'))
        'timing': ReviewTimingEdit(after.timing, after.minute).toJson(),
      if (after.optional != before.optional || confirmed('optional'))
        'optional': after.optional,
      if (after.notes != before.notes || confirmed('notes'))
        'notes': after.notes,
      if (after.durationMinutes != before.durationMinutes ||
          after.durationConfirmed != before.durationConfirmed ||
          confirmed('duration'))
        'duration': [after.durationMinutes, after.durationConfirmed],
      if (!listEquals(after.afterErrandIds, before.afterErrandIds) ||
          confirmed('dependencies'))
        'dependencies': after.afterErrandIds,
    });
  }

  /// An older analysis snapshot cannot override an authoritative source value
  /// when a manual edit has since returned to that value.
  static Errand protectSource(Errand snapshot, Errand source) {
    final protected = {
      ...source.confirmedFields,
      'notes',
      if (source.timing != TimingRule.anytime) 'timing',
      if (source.optional) 'optional',
      if (source.durationConfirmed) 'duration',
      if (source.afterErrandIds.isNotEmpty) 'dependencies',
    };
    final differences = ReviewErrandEdit.between(snapshot, source).values;
    return ReviewErrandEdit._({
      for (final entry in differences.entries)
        if (protected.contains(entry.key)) entry.key: entry.value,
    }).apply(snapshot);
  }

  factory ReviewErrandEdit.fromJson(Map<String, dynamic> json) {
    final duration = json['duration'];
    final after = json['dependencies'];
    if (json.keys.any((key) => !fields.contains(key)) ||
        (json.containsKey('optional') && json['optional'] is! bool) ||
        (json.containsKey('notes') && json['notes'] is! String) ||
        (json.containsKey('timing') && json['timing'] is! Map) ||
        (json.containsKey('duration') &&
            (duration is! List ||
                duration.length != 2 ||
                duration[0] is! int ||
                (duration[0] as int) < 1 ||
                (duration[0] as int) > 1440 ||
                duration[1] is! bool)) ||
        (json.containsKey('dependencies') &&
            (after is! List ||
                after.any((id) => id is! String || id.isEmpty)))) {
      throw const FormatException('Invalid saved errand edits');
    }
    if (json.containsKey('timing')) {
      ReviewTimingEdit.fromJson(
        Map<String, dynamic>.from(json['timing'] as Map),
      );
    }
    return ReviewErrandEdit._(Map.unmodifiable(json));
  }

  Errand apply(Errand errand) {
    final time = values['timing'];
    final duration = values['duration'] as List?;
    final result = time == null
        ? errand
        : ReviewTimingEdit.fromJson(
            Map<String, dynamic>.from(time as Map),
          ).apply(errand);
    if (values.isEmpty) return result;
    return result.copyWith(
      notes: values['notes'] as String?,
      optional: values['optional'] as bool?,
      durationMinutes: duration?[0] as int?,
      durationConfirmed: duration?[1] as bool?,
      afterErrandIds: (values['dependencies'] as List?)?.cast<String>(),
      confirmedFields: {...result.confirmedFields, ...values.keys},
    );
  }
}
