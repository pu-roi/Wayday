import '../../today/domain/day.dart';
import '../../places/domain/place_intent.dart';
import 'planning_models.dart';

/// Location selection belongs to deterministic place handling, not a generic
/// model question. Keep the original answer/cache intact and reconcile on read.
bool needsActualLocation(Errand errand, ErrandNeed? need) {
  final place = errand.placeIntent;
  if (place.hasCoordinates) return false;
  if (need?.meeting == true ||
      need?.requiresSpecificLocation == true ||
      place.isGoogle) {
    return true;
  }
  if ({
    PlaceKind.specific,
    PlaceKind.saved,
    PlaceKind.providerReference,
  }.contains(place.kind)) {
    return true;
  }
  return place.label.trim().isNotEmpty &&
      place.kind != PlaceKind.search &&
      errand.confirmedFields.contains('place');
}

bool needsPlaceRecommendation(Errand errand, ErrandNeed? need) =>
    !errand.placeIntent.hasCoordinates && !needsActualLocation(errand, need);

String? outstandingQuestion(ErrandNeed? need, {required bool clarified}) {
  final question = need?.question?.trim();
  if (clarified || question == null || question.isEmpty) return null;
  return _locationOnly(question) ? null : question;
}

// The existing cached schema has an untyped question string. Conservatively
// recognize location-only wording; preserve mixed/unknown questions for review.
// A missing private point still requires the picker, and a missing shop goes to
// discovery. Neither path needs a duplicate free-text "where" question.
bool _locationOnly(String question) {
  final text = question.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (RegExp(
    r'\b(when|time|long|duration|before|after|first|last|order|schedule|sequence|who|whose|budget|allergies|oras|kailan|gaano|bago|pagkatapos|una|sino|alin)\b',
  ).hasMatch(text)) {
    return false;
  }
  return RegExp(r'^(where|saan|saang|nasaan|nasaang|asan)\b').hasMatch(text) ||
      RegExp(
        r'^(what|which|anong|aling) (is the |ang )?(address|location|meeting point|pickup point|place|branch|store|shop|restaurant|lugar|lokasyon|tindahan)\b',
      ).hasMatch(text) ||
      RegExp(
        r'^(please )?(can|could|would) you (provide|confirm|specify|choose) (the |a |your )?(address|location|meeting point|pickup point)\b',
      ).hasMatch(text);
}

/// A visit estimate is already present in every valid errand, including 15 min.
bool durationOnlyQuestion(String question) => RegExp(
  r'^(how long|how much time|gaano katagal|ilang minuto|what (is the |visit )?duration)\b',
  caseSensitive: false,
).hasMatch(question.trim());
