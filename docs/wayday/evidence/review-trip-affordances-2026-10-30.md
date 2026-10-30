# Review trip editing affordances

Date: 2026-10-30. D56 records the owner's request to make departure and From/To editing discoverable while preserving Wayday's design system.

## Implementation

The new review-only presentation component uses the shared outlined white surface. Its collapsed header includes Edit and a disclosure chevron. Expanded date, departure, finish-time and endpoint controls use the existing pale field fill, persistent labels, wrapping values and trailing pencil icons. Each entire field activates the existing editor. Date includes the year; confirmed endpoints no longer repeat Location ready. Missing coordinates retain the existing map-location cue.

Departure and finish time use two columns only when the inner width and text scale allow them; otherwise they stack. Enlarged header text retains the chevron while omitting the redundant Edit/Hide word. Field targets have a minimum 64-unit height, Material ink/focus states and labeled button semantics. Expansion uses the existing Remove animations preference. Listening to the expansion controller keeps restored state and visible header text consistent without setting ancestor state during child initialization.

The existing date picker, numeric time sheet, location picker, conditional expansion, light-pickup confirmation and save callbacks remain connected. Interpretation, road estimates, storage schema and native bridges were not changed by this task. Pre-existing uncommitted work was preserved.

## Verification

- `flutter analyze`: no issues.
- `flutter test`: 290 passed, one deliberately skipped live-road probe, eight previously documented failures. Every planning/review check passes.
- New component checks cover full-field activation of all five controls, named button semantics, keyboard disclosure/date activation, restored expansion, long Taglish endpoint labels, missing coordinates, large-text scrolling and reduced-motion disclosure.
- Existing review date/time persistence and source-separation checks pass in the full suite. Existing suggestion approval/reversal remains tested; its test now waits for the requested scroll to settle before tapping.
- The preview harness now captures expanded trip fields as well as the prior review/suggestion states. It scrolls lazy content into view before trying to tap it in constrained layouts. No assertion was removed or weakened.
- Synthetic Figtree/Material-icon renders were inspected at 390 × 844, 320 × 740 with 2× text and 768 × 1024. Normal and past-departure/appointment-conflict variants were rendered. Local images are under the ignored `.impeccable/review/` directory: `review-trip-fields-390.png`, `review-trip-fields-320.png`, `review-trip-fields-768.png`, and matching review/suggestion captures.

The eight existing failures are map pin confirmation; regional unavailable-map label/Back behavior; missing map notices; native-renderer timeout/manual labeling; saved-place picker update; profile place editing; unset Today endpoint manual labeling; and Today endpoint/errand manual map labeling. They remain outside this review-section change.

These are synthetic Flutter rendering and interaction checks, not Android device screenshots or TalkBack evidence. No app was installed, no integration harness was run on the personal phone, and no paid/model/provider request, provisioning, cache seeding or personal data change was performed.

## Typography correction following owner review

The owner identified inconsistent sizing in the first D56 render. The trip heading now matches the compact errand heading's 14-unit semibold body style. All five field labels and their values use the existing 14-unit body style; the summary and supporting hints use the existing 12-unit detail style. Edit/Hide keeps the shared 14-unit action style. The pencil sits beside the value, leaving the full field width available to the label so Finish the day by does not make its control taller than Departure at the normal phone size.

Twenty focused review/component/render checks pass after the final layout correction, and analysis is clean. The broader typography run reports 290 passes, one intentional live-road skip and the same eight documented failures. Updated normal-phone, narrow 2x-text and tablet renders were inspected. No Android installation or paid request was made.
