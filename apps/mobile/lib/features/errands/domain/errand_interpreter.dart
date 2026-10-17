import '../../places/domain/place_intent.dart';
import 'errand.dart';

/// Suggestions are derived only from the title, never private free-form notes.
class ErrandSuggestions {
  const ErrandSuggestions({
    this.place,
    this.timing,
    this.minute,
    this.durationMinutes,
    this.optional,
    this.questions = const [],
  });
  final PlaceIntent? place;
  final TimingRule? timing;
  final int? minute;
  final int? durationMinutes;
  final bool? optional;
  final List<String> questions;
  bool get hasDetails =>
      place != null ||
      timing != null ||
      durationMinutes != null ||
      optional != null;
}

ErrandSuggestions interpretErrand(
  String text, {
  List<SavedPlace> savedPlaces = const [],
}) {
  final input = text.toLowerCase();
  String? category;
  for (final entry in {
    'groceries': r'\b(grocer(?:y|ies)|palengke|gulay|mamili)\b',
    'pharmacy': r'\b(pharmacy|gamot|botika)\b',
    'haircut': r'\b(haircut|barber|pagupit|gupit)\b',
    'coffee': r'\b(coffee|kape)\b',
    'bank': r'\b(bank|bangko)\b',
  }.entries) {
    if (RegExp(entry.value).hasMatch(input)) {
      category = entry.key;
      break;
    }
  }
  final brandMatch = RegExp(
    r'\b(puregold|mercury drug|watsons|starbucks)\b',
  ).firstMatch(input);
  final brand = brandMatch == null
      ? null
      : {
          'puregold': 'Puregold',
          'mercury drug': 'Mercury Drug',
          'watsons': 'Watsons',
          'starbucks': 'Starbucks',
        }[brandMatch.group(0)];
  final questions = <String>[];
  PlaceIntent? place;
  final savedMatches = savedPlaces
      .where(
        (saved) => RegExp(
          '\\b(?:at|sa|from|to)\\s+${RegExp.escape(saved.place.label.toLowerCase())}(?=\\s*[,;.]|\\s*\$)',
        ).hasMatch(input),
      )
      .toList();
  final explicitSavedOrSpecific =
      RegExp(r'\b(at|sa)\s+(?!\d)[a-z]').hasMatch(input) && brand == null;
  if (savedMatches.length == 1) {
    place = savedMatches.single.intent;
  } else if (savedMatches.length > 1) {
    questions.add('Choose which saved place you mean.');
  } else if (explicitSavedOrSpecific) {
    questions.add('Choose the specific place you mean.');
  } else if (brand != null || category != null) {
    place = PlaceIntent(
      kind: PlaceKind.search,
      label: brand ?? category!,
      category: category,
      brand: brand,
      source: 'rule',
    );
    if (brand != null && !RegExp(r'\b(any|kahit|alinmang)\b').hasMatch(input)) {
      questions.add('Choose a branch, or confirm that any branch is suitable.');
    }
  }

  TimingRule? timing;
  int? minute;
  final times = RegExp(
    r'\b(finish before|tapos bago|arrive by|dating bago|before|bago|by|at)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
  ).allMatches(input).toList();
  final time = times.length == 1 ? times.single : null;
  if (times.length > 1) {
    questions.add(
      'More than one time was mentioned. Choose the timing rule for this visit.',
    );
  }
  if (time != null) {
    final hour = int.parse(time.group(2)!);
    final minutes = int.tryParse(time.group(3) ?? '0')!;
    final period = time.group(4);
    if (minutes > 59 ||
        hour > 23 ||
        (period != null && (hour < 1 || hour > 12))) {
      questions.add('Choose a valid time.');
    } else if (period == null && hour >= 1 && hour <= 12) {
      questions.add(
        'Does ${time.group(2)}${time.group(3) == null ? '' : ':${time.group(3)}'} mean AM or PM?',
      );
    } else {
      final phrase = time.group(1)!;
      if (['before', 'bago', 'by'].contains(phrase)) {
        questions.add(
          'Should you arrive by that time, or finish the visit before it?',
        );
      } else {
        minute =
            (period == null ? hour : hour % 12 + (period == 'pm' ? 12 : 0)) *
                60 +
            minutes;
        timing = switch (phrase) {
          'finish before' || 'tapos bago' => TimingRule.finishBefore,
          'arrive by' || 'dating bago' => TimingRule.arriveBy,
          _ => TimingRule.at,
        };
      }
    }
  }
  final duration = RegExp(
    r'\b(?:allow|spend|for|laan(?:an)?|maglaan)\s+(\d{1,3})\s*(minutes?|mins?|minuto|hours?|oras)\b',
  ).firstMatch(input);
  int? durationMinutes;
  if (duration != null) {
    final amount = int.parse(duration.group(1)!);
    final value =
        amount *
        (['hour', 'hours', 'oras'].contains(duration.group(2)) ? 60 : 1);
    if (value >= 1 && value <= 1440) {
      durationMinutes = value;
    } else {
      questions.add('Choose a visit duration between 1 and 1,440 minutes.');
    }
  }
  return ErrandSuggestions(
    place: place,
    timing: timing,
    minute: minute,
    durationMinutes: durationMinutes,
    optional:
        RegExp(
          r'\b(if (?:there is |there.s )?time|kung may (?:time|oras))\b',
        ).hasMatch(input)
        ? true
        : null,
    questions: List.unmodifiable(questions),
  );
}
