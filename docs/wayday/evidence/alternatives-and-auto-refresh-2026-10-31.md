# Alternatives and automatic route refresh — D62

Date: 2026-10-31, Asia/Manila.

## Implemented behavior

- Alternatives now use a content-sized supporting sheet with fixed heading/Close and the retained errand pager. Results/actions scroll within a 90%-usable-height maximum. Current place has a checkmark/selection semantics. Show more suggestions and Choose a specific place explain distinct actions directly after the rows; provider credits follow them. Manual cancellation retains the sheet and selection.
- AlternativeBatch and a separate in-memory browsing pool append up to three unique suggestions per tap, capped at twelve. Full provider responses and the original bounded search contexts are reused; the existing solver shortlist and suitability/brand filtering remain. Exhaustion, loading and inline retry retain previously selectable rows. Per-errand loaded lists and scroll offsets survive paging. No copied provider business text is stored in a database.
- Replacement saves before a 500 ms debounce, retains other chosen branches and approved rules, and runs roads/scheduling without Gemini or business discovery. A revisioned coordinator permits one calculation flight and queues the latest saved revision. Your plan stays visible; Change remains available; Start trip is blocked while updating. Outdated geometry/timing is hidden. Explicit retry preserves choices after failure.
- Native map updates clear obsolete overlays and install changed markers/geometry on the existing map controller. Refreshed route bounds are fitted. The expanded map reads current model data rather than a captured old proposal.
- Removed the entire Trip details block from Your plan while preserving Review. Nested dismissal returns to the parent surface and unchanged valid proposals remain reusable from Review.
- Ten-second preparation, draft-save and coordinate-save caller deadlines surface failures. Matching actual writes remain coalesced until completion. Late save failures cannot override the status of a newer save. Existing provider deadlines and conservative dispatched accounting remain.

No database migration, provider replacement, dependency addition, Cloud/billing change, personal-phone installation/reset or live paid request is part of this work.

## Verification

Host verification covers bounded cached append/exhaustion, duplicate taps and twelve-entry browsing cap, independent solver shortlist, pager/list retention, inline failure/retry, narrow/enlarged-text layouts, preparation/save deadlines, automatic debounce, branch preservation, explicit recovery, late responses and single-flight updates. A fake native-map controller verifies the same view clears obsolete geometry, moves markers and draws refreshed lines. A separate case verifies all fresh cached contexts are considered before an unused anchor and no extra request is made merely to determine exhaustion.

The full suite completed with 474 passes, one skip and the same eight baseline failures. All 37 focused cases pass in that run. Separate checks passed nineteen service cases and ten controller/map-state recovery cases. After hardening actual per-errand scroll restoration with PageStorage keys, the three browsing/layout checks passed again at normal and doubled text, and final analysis reported no issues. No unrelated checks were weakened.

The guarded disposable Android fixture passed. The final run built in 196.8 seconds and passed in ten seconds, covering automatic proposal construction with mocked roads/meaning, absence of the redundant Trip details block, errand paging, actual system Back from alternatives to Your plan, Back to Review, unchanged forward navigation, local draft storage and Save for reuse. The first run passed too, but its test used an outside tap while trying to press an obscured toolbar; the final fixture explicitly sends Back and checks the sheet is gone. No warning was suppressed. The owned emulator was shut down without wiping it.

The final ordinary Android arm64 debug APK built successfully in 116.5 seconds after the cache-first and scroll-restoration fixes. Package verification reports dev.wayday.wayday, version 0.1.0 (1), signed with the existing debug SHA-1 DB:F4:CB:E2:C5:F4:D0:39:27:E8:3D:C0:87:0C:57:5C:5B:43:8A:1B. The ignored delivery copy is .tools/artifacts/wayday-d62-personal-debug.apk (191,225,538 bytes), SHA-256 D5B6713B25A078059A3D229C29972700017F3F5C82AEC3A6D5CF3EA84DD47D7C. It was not installed on the personal phone. Workspace Gradle daemons were stopped after verification.

The unchanged baseline failures are: online pin confirmation; three regional-map cases (large-text manual fallback, missing-notices credits and blank native renderer); two saved-place/profile cases (updated place in picker and edit/cancel/delete isolation); and two Today manual-map cases (unset endpoints and endpoint/errand label editing). No failure was skipped or suppressed for D62.

Synthetic sheet captures use the bundled Figtree font and Material icons at 390 units/normal text and 320 units/double text, under ignored .tools/alternatives-screenshots. They are layout checks, not real Google search results or physical-device screenshots.

## Qualification boundaries

The disposable Android fixture uses mocked interpretation/roads and no configured live map key. The native-map host mock tests overlay commands; it does not qualify actual Google map rendering, gestures or real-road quality. Physical-phone TalkBack, enlarged system fonts, manual picker permissions/keyboard and unplugged operation remain separate manual checks.

The previous disconnected-phone spinner trigger remains unconfirmed. This change repairs demonstrated unbounded preparation/save waits and delayed UI notifications; it does not establish that the historical phone symptom had the same cause.

No further live disposable calls were made. The original US$2 allocation and minimum US$0.782 reserved recovery floor remain mandatory before more paid qualification. Do not initialize/refill a replacement allocation. Existing eight baseline failures remain outside this focused repair.

## Owner phone rehearsal

Update the installed app without uninstalling or clearing data. Build a future-dated trip using the existing confirmed endpoints and errands, then check:

1. Your plan has no Trip details block. Each place still has Change. Back opens Review; rebuilding unchanged inputs returns to the valid proposal without another interpretation.
2. Change opens the shorter alternatives sheet. The current place is marked. Show more appends unique suggestions; paging away/back retains that list and position. Exhaustion differs from a failed search.
3. Choose a specific place opens manual search/saved places/map selection. Cancel returns to the sheet with the original choice. Dismiss the sheet to return to the same plan position.
4. Choose a different branch. The sheet closes, its marker moves, old route/times disappear and Updating route appears. After the update, the road line and schedule reflect the new branch. Other selected businesses remain. Selecting Current place causes no update.
5. Change again while an update is running. The final route must use the latest choice, with no older result replacing it. If saving or roads fail, Change stays available and Start trip stays blocked until saved validation succeeds.
6. Repeat with the cable disconnected after fully closing and reopening from the app icon. Record whether a bounded error appears or the route completes, the displayed stage and elapsed time. This is the outstanding standalone-phone check, not an assumed pass.

Also inspect long Taglish titles, large system text, TalkBack labels, sheet dismissal and map scrolling. Keep real provider requests within the existing personal allocation. Do not clear journals or reset allowances to repeat a test.
