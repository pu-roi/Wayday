# Planning review investigation — 2026-10-30

The owner requested deeper investigation of review ordering and the recurring past-departure message after D51.

## Observed evidence

Read-only Samsung inspection at approximately 11:51 AM on October 30 found a stored October 29 departure at 8:30 AM and a 6:00 PM final deadline. The database contained four errands in pickup, grocery, pares, ice-cream order. Pares explicitly depended on pickup and grocery. The source data and the order in the supplied screenshot were already consistent. Seven native Gemini attempts remained. No credential value or personal coordinates were copied into this evidence.

## Root causes and scope

| Finding | Root cause | Correction |
| --- | --- | --- |
| New selected ordering rules were not immediately visible | The review iterated controller.day while approvals only changed a selection set. Effective rules and topological reconciliation ran later inside applyReview, after the user tapped Next. | Share one pure effective projection between visible review order and forward validation. Keep the original baseline for reversal. |
| Corrected date/time reverted after Close or process exit | Date/time edits only changed the screen-owned controller. Reopening reconstructed it from unchanged Today. D51 only cleared the earlier error label. | Save explicit review date/departure/deadline in a separate source-bound singleton Drift row and restore before interpretation. |
| The latest screenshot still showed a departure error | October 29 at 8:30 AM was genuinely past at October 30 11:49 AM. Even October 30 8:30 AM would be past at that time. | Preserve real validation, show the exact selected departure and direct recovery actions, and gate Next until corrected. Do not move appointments automatically. |

Preparation settings remain separate from source Today and accepted itinerary progress. A changed source invalidates the saved snapshot; replanning/history bypasses it. The snapshot stores only date and two minute values, with a source hash. It does not store interpretation responses, route geometry or coordinates. Reads and writes are serialized, failures are visible, and an explicit retry can save the current edit.

## Regression evidence

Two new widget cases failed before implementation: immediate ordering after approval and corrected date after Close/reopen. They pass after the correction. Additional cases cover reversal before Next with an invalid departure, explicit existing constraints, failed-save retry, replanning isolation, v3-to-v4 upgrade and SQLite reopening, source invalidation, latest-write ordering, bounded snapshot content, unchanged interpretation request identity, and Philippine/UTC midnight/minute boundaries.

The two reported clock scenarios are tested independently: October 30 3:27 AM precedes October 30 8:30 AM; October 30 11:49 AM follows both that departure and the October 29 departure. The current minute remains selectable under the existing minute-precision input contract.

Static analysis passes. The full Flutter suite reports 260 passes, one deliberately skipped live-road probe and the same eight baseline failures. Thirty-two focused checks pass. Synthetic rendered review states were checked at normal phone size and narrow 2× text, including expired-departure recovery. The isolated physical Samsung recovery fixture passed after a local generated Gradle-cache repair: UI edits survived view/database recreation with zero generation requests. Its saved SQLite row also survived an explicit force-stop of the disposable .maptest package. Normal-package installation results are recorded in Progress.

## Limits

This is not a complete live itinerary rehearsal or native TalkBack qualification. Interpretation context was not changed, and no paid Gemini generation is needed to validate these regressions. A future departure still requires the user's explicit choice; genuinely missed errand appointments remain scheduling constraints to correct or explain.

## Normal installation verification

The normal private ARM64 package was installed with install -r and launched. Schema 3-to-4 migration completed on the Samsung. All rows in the six pre-existing personal tables compare unchanged against the before-update snapshot, four Today errands remain, SQLite integrity is ok, and the Gemini allowance remains seven. No source date, appointment or private cache was reset or changed. A future departure still needs one explicit user correction; the new review row will retain that correction for unchanged source input.
