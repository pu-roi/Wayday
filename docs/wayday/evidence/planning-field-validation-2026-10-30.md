# Planning field validation and recovery audit

Date: 2026-10-30. Scope: the reported morning pickup deadline with an afternoon departure, plus the owner's request to inspect other fields. D53 records the field behavior; D54 records the verification incident and safe recovery policy.

## Root finding

Review previously checked whether departure had passed, but a corrected departure could still contradict an errand's arrival/start/finish rule. Some failures were checked only in later solver/road validation. Shared deterministic checks now reject structural errors and provably impossible mandatory schedules before discovery or route work. They never move appointments automatically.

## Field coverage

| Field or boundary | Behavior and verification |
| --- | --- |
| Errand count, identity and name | Require 1–12 errands, nonblank unique identities and nonblank titles. Malformed source input is rejected before interpretation. |
| Date and time zone | Require an actual calendar date and Asia/Manila. The calendar editor safely clamps its initial display to its supported range. |
| Departure | Validate minute range and Philippine date/time expiry. Recheck immediately before route calculation if candidate selection took time. |
| Final deadline | Require a later time than departure on the same trip date. Flag a mandatory visit that cannot finish with its buffer, even with zero travel. Overnight plans are not inferred. |
| Arrive by | Flag a mandatory deadline before departure. Equality is not rejected without road evidence. Arrival can precede prerequisite service at a shared stop. |
| At | Validate fixed service start against departure and prerequisite service lower bounds. Waiting remains possible. |
| Finish before | Include configured visit duration and the existing five-minute buffer. |
| Visit duration | Require 1–1,440 minutes. Unconfirmed defaults remain visibly estimated; bounds do not prove duration accuracy. |
| After rules | Reject missing/self/cyclic references; preserve stable ordering. Include transitive prerequisites of required errands in blocking timing checks, even when a prerequisite is labelled optional. |
| Required versus optional | Independent optional errands may be omitted. Their missed timing does not block the entire day. The solver still explains actual omissions. |
| Endpoints and private meetings | Existing checks require usable coordinates and confirmation of expired explicit references. Coordinate validity and provider/picker admission rules remain in their existing boundaries. |
| Flexible errands without a place | Proceed to recommendations. An empty business location is not itself an error. |
| Places, stock and hours | Real provider records, coordinate leases, road reachability and later schedule validation remain necessary. Unknown hours or stock are not invented or guaranteed by preflight. |
| Travel mode | Existing bicycle qualification and compatible light-pickup guards remain. This change does not qualify all five profiles or clearance-aware routing. |
| Titles/notes and interpretation | Changed text remains stale until explicitly reinterpreted. Corrected review clocks restore after unchanged-source understanding, retaining the original cache identity. |
| Other questions | Restoring a clock cannot clear an unrelated timing/order/unknown clarification. Existing cached-question handling remains conservative. |
| Persistence and source revision | Store only manual clock differences alongside trip settings. Legacy rows remain valid; malformed clocks surface errors, changed source invalidates the row, and Today/accepted progress remain separate. |
| Review actions | Edit actions open the affected errand. Next stays visible and disabled for blocking field conflicts. The review editor no longer offers its unhandled Remove action; source removal remains in Today. |

These are structural checks and zero-road lower bounds, not a promise that a route is feasible. The actual road matrix, branch choice, waiting, shared visits and final validation remain essential.

## Verification

The original appointment-conflict widget test failed before the fix. New domain cases cover arrival/start/completion distinctions, mandatory prerequisite closure, optional omission, shared-stop arrival, invalid date/time/duration/identity data and trip windows. Controller tests prove malformed source input does not reach the interpreter and invalid calculation input does not reach roads. SQLite and widget tests prove manual clocks survive reopening while unchanged original interpretation inputs and Today remain intact. A canonical-set cache test now uses valid dependency targets while retaining its original ordering-invariance assertion.

Final analysis is clean. Fifty-five focused tests pass. The final full suite reports 277 passes, one intentionally skipped live-road check and the same eight existing map/picker/profile/Today failures recorded in D52. Normal and narrow 2×-text conflict renders were inspected. The synthetic Samsung fixture exercised editing a conflicting appointment and view/database recreation with zero native generation requests. The normal ARM64 debug APK builds and installs.

## Verification incident and limits

During the Android test/install sequence, verification detected a fresh personal app installation with empty local state. The precise uninstall trigger was not established; Flutter's launcher contains an install-failure uninstall fallback independent of the test cleanup flag. Do not treat the prior package-suffix/cleanup protection as sufficient. The wrapper now refuses to run when the personal package is installed; this guard was exercised successfully before any build/install. Future harness runs require a disposable emulator without the personal package.

A consistent private SQLite snapshot restored the four original errands and saved review settings, including the manually selected 9:30 AM clock. The private credential was imported once with exactly the previously verified seven remaining attempts; two consumed attempts were conservatively retained in native and Dart rolling-day accounting. This was restoration of the existing allocation, not an additional allowance. No live generation was sent.

The original Gemini response journal could not be recovered. It was not seeded with fixture or invented responses. A separate native recovery marker makes a missing interpretation require explicit paid retry, both through status lookup and direct dispatch. Only a successful explicit generation clears that marker. A real normal-app opening on Samsung showed the recovery message and Retry Gemini action, with seven attempts unchanged. A mocked regression also proves recovery performs no dispatch or budget write until explicit retry. The owner subsequently said further data recovery was unnecessary; no further recovery work is planned.

A complete live itinerary/navigation rehearsal and native TalkBack qualification remain outside this field fix. No all-mode readiness claim follows from these checks.
