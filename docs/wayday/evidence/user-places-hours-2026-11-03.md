# User-selected places and reported hours

## Phone reproduction

The owner authorized inspection of the connected phone and its application data, then explicitly authorized reopening the existing plan even if saved analysis was unavailable. The active application was the release-signed Wayday Test build, version 0.1.0-test.103403, package `dev.wayday.wayday.publictest`.

Android rejected `run-as` for both installed Wayday packages because they are release builds. Direct database and native-journal extraction was therefore unavailable. The investigation used the application's rendered accessibility tree and normal read-only editor/detail inspection. Raw device captures remain in ignored local tooling storage. No app was installed, uninstalled or reset. The phone was returned to Today with five errands present.

Opening Plan my day restored the existing Review for Wednesday, November 4, 2026, Motorcycle, 6 AM departure and 8 PM final deadline. Today's source date displayed November 3, demonstrating the separate saved Review date. That distinction was checked before testing the error. Build recommendations refreshed the retained places and reproduced the reported message. The university's Details showed date-specific hours of 9 AM–5 PM for November 4. The owner clarified that the school actually opens at 7 AM and that user-supplied locations should remain authoritative.

| Errand | Stored schedule shown by Review | Selected place | Reported hours for November 4 |
| --- | --- | --- | --- |
| Campus event | At 8:30 AM, 15-minute estimate | Pamantasan ng Lungsod ng Pasig | 9 AM–5 PM |
| Pickup | At 3 PM, 15-minute estimate | Sheilz Coffee | Noon–10 PM |
| Lunch | Anytime, 15-minute estimate | Zenella Restaurant, San Miguel Branch | 10 AM–10 PM |
| Bank | Anytime, 15-minute estimate | BDO Pasig, Maybunga | 8:30 AM–5:30 PM |
| Groceries | Anytime, 15-minute estimate | DALI Everyday Grocery, Luis Mercedes | 6:30 AM–10 PM |

The starting place displayed the same campus name. The first two destinations were supplied in the source errands. The remaining three were retained recommendation results. Expanded Review items showed no selected dependency rules or applied suggested changes. The lunch, bank and grocery questions were optional and unanswered. They did not prevent preparation.

## Root cause and route behavior

The reported-hours precheck required the 8:30–8:50 AM campus visit, including its buffer, to fit within 9 AM–5 PM. It used the correct future date. It rejected the campus before road-matrix dispatch, so the route engine was never given the five-errand problem. The map showed selected locations without a confirmed route.

The defect was the treatment of provider hours as a hard constraint for a destination supplied by the user. The starting point does not change the visit's service-start appointment or validate the provider's hours. A zero-travel first leg alone would not fix the 8:30 versus 9 AM comparison. The app needed to distinguish the user's chosen access from suitability constraints on automatically recommended businesses.

The other four displayed schedules have no immediate hours mismatch. Their final road feasibility depends on actual travel durations and the user's visit estimates. The default 15-minute campus duration describes the supplied data and does not establish the event's real duration.

## Owner-approved correction

Reported opening intervals are advisory for a location supplied through an errand's actual selected place or through an explicit branch override. The original place, appointment, duration and dependency rules remain the scheduling input. Details retains reported hours and displays that the user chose the place. A planned visit outside those hours carries an access warning. Automatically recommended places continue to enforce date-specific opening intervals, full visits and the existing buffer.

The controller, worker input, solver, independent schedule validation and refined-arrival check use the same task-specific policy. A manually selected event at a shared physical stop cannot exempt another recommended errand at that stop. The recommended tasks' constrained visit span must still fit reported hours. Permanent and temporary business-closure status checks remain separate from opening intervals.

The policy derives from source places and explicit choice records. The existing recommendation-draft JSON stores the explicit manual-place identities separately from automatic recommendations locked only to keep other rows stable during a place change. Those automatic locks retain strict hours checks. Legacy drafts without this optional field retain their places and default to strict hours for nonsource choices until explicitly selected. SQLite stores the additive JSON field in its existing table; no migration, model request format or provider contract changes are required. Raw provider notices and hours are retained as received.

## Verification

The five-errand reproduction uses the phone-observed schedule and hours with synthetic place identities, coordinates and road responses. It covers both a lightweight road fixture and the production matrix/refinement adapter behind a simulated HTTP transport. Both preserve the two appointments, include all five errands, enforce hours for lunch/bank/groceries, produce route geometry and save an accepted itinerary.

Disabling the user-choice hours policy caused the reproduction to fail with the same campus-hours message before matrix dispatch. Separate checks keep an automatically recommended campus blocked until explicitly selected, verify mixed shared-stop enforcement, and show advisory wording without hiding reported hours. Shared-stop details use each row's own visit and buffer. SQLite close-and-reopen retains explicit-place provenance; legacy and malformed payloads are covered. Controller reopening distinguishes manual choices from automatic locks, and a delayed older solve cannot replace a newer selection. Existing future-date and refined-closing regressions remain part of validation.

The final full Flutter suite passed 752 tests with one existing skip. Static analysis reported no issues. The focused hours, provenance, SQLite, recommendation and route-refresh checks also passed. All generation and road responses in these regressions were simulated.

The installed phone retains the earlier build. A successful fixed-build live route on that phone has not been claimed.
