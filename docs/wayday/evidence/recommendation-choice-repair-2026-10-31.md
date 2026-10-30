# Recommendation choice and cleared-answer repair

Date: 2026-10-31, Asia/Manila.

## Report and cause

The owner reported grocery-like behavior while answering a gym question and a resolved blue summary remaining after the answer field was emptied. The screenshots show a gym-specific saved summary; they do not establish that live Google results were grocery businesses.

The implementation gave the same Let Wayday recommend action two behaviors. A typed optional preference saved a local choice, with grocery-specific confirmation wording for grocery needs. Other questions received the canned sentence “Let Wayday recommend. I’ll decide when I get there.” as a draft and required Use answer/Gemini processing. The arrival wording did not clearly describe choosing a gym branch before routing. Separately, saveDraft retained the previously applied result when the answer was emptied, so the review reflected the old result instead of the user's intended withdrawal. Both interactions reproduced in widget tests before the fixes.

## Implemented behavior

Supported location and optional-preference questions now save the explicit recommendation choice directly. The action leaves the interpreted query, category, supplied items and explicit brand intact and uses neutral confirmation copy. No free-form sentence is inserted, and this choice does not call Gemini. Initial interpretation and genuinely free-form clarification remain separate. Timing/dependency questions, fixed destinations, stale interpretation and answers proposing rules cannot be bypassed with this shortcut. Real places still come from provider discovery and the route-aware planning flow.

Emptying an existing answer creates a newer cleared record in the existing clarification JSON. It removes the applied resolution, restores the appropriate unanswered state and invalidates affected automatic candidates/calculation through the shared coordinator. Required questions regain the question bubble, dark amber #7A4500 and Needs your answer; optional questions retain normal optional styling. Nonempty unsent changes remain drafts. Revision-based selection/merge and stale-response identity guards prevent older answers from returning after clock edits, restart or late completion. Storage errors remain visible and allow free local save retry; persistence is not claimed before that retry succeeds.

No new table, dependency, provider, billing setting or credential change was introduced for these bug fixes. Existing review labels, Edit errand, Choose actual location and trip details remain intact. The broader intelligent-location/manual-map repair remains a separate integrated qualification concern under D59.

## Verification

- Red reproduction: both new gym widget tests failed on the reported interactions before the changes (`.tools/recommend-choice-red-second.log`).
- Focused regression checks cover a gym choice reaching mocked place discovery with query gym/category other, brand/items preservation, a grocery-to-gym change with the same task ID, protected timing/fixed/stale cases, cleared answers across clock changes and restart, late completion, SQLite reopen/merge, and storage failure with free retry. No live generation or provider request was used.
- The updated answer sheet and review state were rendered at 390 pixels; the cleared state was inspected visually. The review layout also passed at 320 pixels with 2× text, 390 pixels and 768 pixels. Existing narrow-screen keyboard and accessible-control checks passed. Captures are local ignored artifacts under `.impeccable/clarification/`.
- Final Flutter analysis: no issues (`.tools/recommend-choice-analyze-final.log`).
- Final full suite: 427 passed, eight failed and one intentionally skipped (`.tools/recommend-choice-full-final.log`). All tests for the repaired behavior pass. The eight failures match the longstanding baseline groups below; no failures were suppressed or skipped for this repair.

The fresh pre-repair baseline was 342 passed, nine failed and one skipped. In addition to the historical eight failures, it exposed a recommendation large-text test that expected exactly two lazily built reason rows. That viewport-dependent assertion now checks available reasons without requiring offscreen rows to be built. A new review test similarly scrolls to the relevant control before checking its accessibility. These changes preserve the intended behavior checks.

The eight remaining failures are:

1. `online_pin_picker_test`: map pin confirmation returns chosen coordinates.
2. `regional_map_test`: unavailable map preserves label saving and Back cancellation at large text.
3. `regional_map_test`: settings credits work without a map and report missing notices.
4. `regional_map_test`: blank native renderer expires without preventing manual label entry.
5. `saved_places_profile_test`: place picker offers the updated saved place.
6. `saved_places_profile_test`: profile edits, cancels and deletes without changing another place.
7. `today_test`: unset endpoints cancel unchanged and save actual manual labels.
8. `today_test`: manual map labels edit endpoints and errand locations without geocoding.

An ARM64 Android debug build passed (`.tools/recommend-choice-android-build.log`); the final-source refresh is recorded in `.tools/recommend-choice-android-final.log`. This is a build check, not a personal-phone installation or runtime qualification. An earlier disposable `.maptest` attempt for the broader location-understanding integration did not complete; it is not reported as a native pass. Real native map gestures, physical-phone restart/permissions, TalkBack and live Gemini/provider suitability remain separately unqualified. The personal phone was not installed, reset, cleared, seeded or provisioned, and no live paid requests were made.
