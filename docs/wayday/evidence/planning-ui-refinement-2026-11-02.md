# Planning screen hierarchy and completion — D69

## Implemented behavior

The owner approved the refinement plan with compact plan rows, inline Details, and Done beside the current errand, stacking at narrow widths or enlarged text.

- Past-departure feedback groups its exact date/time and both recovery actions in one left-aligned notice using semantic red text, a warning icon and subtle error-container fill. Validation, duplicate-error suppression and separate amber question styling remain unchanged.
- Plan rows emphasize business names and align supporting locality/timing information. Details groups Place, Visit timing and Business hours, retaining addresses, ratings, reasons, waiting/buffer, calculation age, current versus trip-date status, calculated compatibility, weekly disclosure and retrieval attribution. Selected-row tint clips to the enclosing rounded surface; route refresh hides invalid estimates.
- The navigation panel uses the existing 21-unit title role and check-icon Cornflower Done button. Done stacks when inner width is below 320 units or scaled 14-unit text exceeds 18. Content scrolls within 32% of screen height, including landscape, so the map retains space. Long enlarged titles may require scrolling to Done.
- Done calls the existing guarded completion operation; the title is not interactive. Saving… disables repeat presses. Successful persistence reveals the next independent errand, with guidance advancing only after all shared-stop tasks are complete. Errors, Back/resume and Finish confirmation/cleanup retain their behavior.

No public API, schema, provider, dependency, credential or Cloud change was introduced. Existing unrelated working-tree changes were preserved. Only the disposable `.maptest` application was installed by this task.

## Host and rendered verification

- Before implementing the warning/Done UI, focused tests failed on their missing treatment/controls as expected.
- `./tool/flutter.ps1 test --reporter expanded`: **606 passed, one existing skip**, without disabling checks.
- `./tool/flutter.ps1 analyze`: **no issues**. After the final preservation of calculation age for an unscheduled row, analysis again found no issues and all five focused plan/warning tests passed. The warning test verifies at least 4.5:1 text contrast.
- Completion coverage includes delayed/failed saves, repeated taps, noninteractive titles, independent shared-location errands, recovery, semantic labels and minimum button height. Existing session/navigation/Finish checks ran in the full suite.
- Inspected actual Flutter renders at 320/390/768 widths, up to 200% text, plus 740×390 landscape at 130%. Covered long Taglish titles/addresses, absent ratings, disclosure, pin-only unknown hours and stale-route time hiding. Existing hours tests cover current/future/weekly, unavailable, failed and stale states without provider calls.
- The Impeccable layout detector returned no findings; a separate source/render finish assessment found no actionable regressions. `git diff --check` passed.
- Before pushing D69, updated and validated the Wayday planning skill, then exported the exact staged source tree into an ignored isolated directory. That snapshot, excluding unrelated branding/research edits, passed analysis and all 606 tests with one existing skip. Local documentation links, staged additions and diff whitespace checks passed.

Ignored local captures include `.tools/ui-refinement/plan-details-{320,390,768}.png`, `.tools/ui-refinement/departure-warning-{1.0,2.0}.png`, and `.tools/navigation-screenshots/trip-{320,390,740,768}.png`. These contain synthetic fixtures, not live provider results.

## Disposable Android verification

`./tool/test-map.ps1 -DeviceId emulator-5554 -Target integration_test/trip_navigation_test.dart` built/installed `.maptest` on the `Wayday_Clarification_Test` emulator. The guard confirmed the personal package was absent and retained `--no-uninstall`. The fixture passed with `WAYDAY_COMPACT_NAVIGATION_FIXTURE_PASSED`.

It verified that title taps do not complete an errand, Done saves before the next shared-location task, first completion does not advance guidance, final shared completion advances once, Back/reopen preserves progress, and Finish cancel/confirm preserves or clears the memory repositories correctly. Current/next-errand screenshots were saved in the disposable application's temporary directory, then copied to ignored `.tools/ui-refinement/android-trip-{current,next}.png`. The native viewport, drivers and repositories are synthetic; no paid requests or persistent allowance changes were needed.

Initial native captures used the emulator's existing density override of 240 at 1080×2400. A subsequent phone-density pass at 440 was interrupted after five seconds: Android's process-exit record reports reason 3, LOW_MEMORY, with approximately 360 MB RSS for the debug fixture process. There was no Java/native crash record. That interrupted run is not a passing phone-size check. The prior density override was restored to 240. A follow-up uses a temporary 4 GB emulator RAM override, without wiping data or changing the stored AVD configuration; its result is recorded separately below.

The follow-up **passed** at density 440 (approximately 393 logical pixels wide), with the same fixture success marker and all completion/Back/Finish assertions. Inspected `.tools/ui-refinement/android-phone-trip-{current,next}.png`, including the long Taglish title beside Done. The density override was restored to 240; the AVD's stored RAM setting remains 2 GB. The temporary 4 GB process was stopped after capture. The earlier low-memory interruption remains recorded as an emulator resource limitation, not a passing run or evidence of physical-device memory behavior.

## Qualification boundary

These checks do not establish physical-phone readability, physical TalkBack, actual GPS, native maneuver/ETA/Recenter/attribution placement or live Google guidance. The native capture viewport is explicitly synthetic. No personal-phone installation, data reset, cache seeding, live provider rehearsal or publication was performed by this refinement.
