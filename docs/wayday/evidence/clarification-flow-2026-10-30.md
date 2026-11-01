# D57 clarification answers and flexible recommendations

Date: 2026-10-30, Asia/Manila.

## Implemented behavior

Question taps open a focused answer sheet, separate from the errand editor. Draft text is stored without applying it. Free-form English, Filipino and Taglish is sent to the contextual clarification resolver; the sheet shows processing and prevents duplicate submission. Known typed optional flexibility, location selection, time selection and explicit deferral use local controls. Successful storage produces a compact editable summary. Uncertain grocery items mean suitable shopping places and choosing items on arrival, never invented shopping lists or inventory claims.

Question identity and scope replace the errand-wide clarified flag. Relevant facts bind a result to its source; scope-compatible preferences survive unrelated clock/duration changes, and unrelated edits never resolve unanswered questions. Original notes, explicit locations/preferences and the current duration remain intact. The 15-minute unconfirmed estimate is explicitly covered. Timing/dependency proposals require approval and preserve existing dependencies; proposed cycles fail validation. Relevant answer changes invalidate affected automatic candidates and the schedule.

Plan the other errands previews the dependent closure before confirmation. Deferred errands remain in Today with their required status and their reasons visible in review/results. Re-inclusion is explicit, prerequisites must be included first, and an all-deferred plan cannot continue. Selected extra errands use the same review and clarification controls.

## Persistence and request safety

Drift v5 adds clarification_sessions through an additive migration. Source keys exclude routing-only settings; deferrals also bind to the chosen plan date. Independent question submission/draft revisions and dated deferral revisions prevent stale writes from replacing newer work. User-confirmed review locations serialize through existing PlaceIntent rules; source-point/text checks prevent overwriting newer Today choices, and Google coordinates continue to expire through the existing reference resolver. The separate v4 review trip/clock row is preserved.

A shared GeminiRequestClient handles initial interpretation and clarification with coalescing, persistent saved lookup and explicit retries. The legacy interpretation body remains frozen and completed compatible answers are checked before generation. Pending/failed/corrupt legacy states cannot become automatic retries through a schema upgrade. Native clarification snapshots use a separate 32-entry no-backup journal and cannot evict the original eight interpretation snapshots. D55's removal of app-imposed usage caps remains intact. Closing/disposal does not cancel persistence of submitted work. A reopened processing sheet closes when its stored result arrives; reopening an already applied answer remains editable. Retrying a completed answer’s local save closes only the sheet and never regenerates it. Pending restart recovery uses saved-only lookup. Storage failure retains text/results and exposes a free local save retry. A source switch before dispatch prevents stale generation.

Accepted itinerary JSON v2 retains clarification records/summaries and explicit deferral reasons; v1 remains readable. Both save and read validate assignment, optional omission and explicit deferral as separate disjoint groups. Existing progress survives migration/restart. Provider results, native Google cards/attribution and Google coordinate retention are unchanged. Calculation validates both current source input and the effective active projection before road requests.

## Verification

- Flutter analysis: clean.
- Focused suite: 68 passing checks across clarification domain/state/storage/transport/sheets, interpretation cache compatibility, review, field guards and itinerary migration.
- Full Flutter suite: 321 passed, eight existing failures, one deliberately skipped live-road check. The additional field-guard regression found during implementation was fixed and passes; the remaining failures are the documented map/picker/Profile/Today cases listed below.
- Native Android: the isolated clarification_cache_test passes on the newly created Wayday_Clarification_Test API 37 x86_64 emulator, with only the .maptest package, no credential provisioned and saved-only client calls. It validates journal integrity, namespace isolation after 34 answer snapshots, completed lookup and retained pending state. Initial launch failed because the fresh emulator's Activity Manager stalled; a restart with software graphics succeeded. This was an emulator startup failure, not a successful first test run.
- Synthetic renders: inspected answer-sheet.png, answered-review.png and large-text-keyboard.png under the ignored .impeccable/clarification directory. The 390-unit normal sheet and 320-unit 2x text/keyboard state keep controls reachable. Widget checks cover labelled semantic targets, keyboard insets, draft close/reopen, loading, explicit flexibility, dependent preview, re-inclusion and empty active plans. Theme tokens and reduced-motion modal behavior are reused.
- No live Gemini request, credential operation, allowance refill, personal-phone installation, database recovery or personal-app harness was used.

The eight baseline failures are: online_pin_picker_test's chosen-coordinate confirmation; regional_map_test's blank renderer/manual label, settings credits and unavailable-map large-text cases; two saved_places_profile_test cases; and two Today manual-location cases. They remain outside this clarification change and were not skipped or weakened.

## Remaining qualification

Real Gemini answer quality in English/Filipino/Taglish, real provider recommendation suitability and physical-phone/TalkBack/restart behavior still need a separately authorized live rehearsal. Mocked semantic fixtures prove application behavior and validation, not the live model's accuracy. Existing bicycle routing/guidance and all-mode limitations remain. The personal-phone harness remains blocked. The normal Android debug APK was built successfully with the ARM64 target after the final source edits and was not installed on the personal phone.

## Final build artifact

The normal dev.wayday.wayday debug APK was built from the final source with the Android ARM64 target. SHA-256: DB09BC9A4D679CEB3DB4CD56CA5C03237DADEEF449745DFB76A3E48A7BE259C5. The build succeeded with the existing Gradle native-access warnings. This artifact is generated/ignored and was not pushed or installed. The disposable emulator was stopped after verification.
