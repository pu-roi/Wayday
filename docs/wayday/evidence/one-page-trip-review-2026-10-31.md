# D61 one-page trip review and sustainable requests

Date: 2026-10-31, Asia/Manila.

## Implementation

The owner authorized the combined Your plan page, visible replacement controls during failure, multi-edit/one-update behavior, separate navigation start and explicit reusable-trip saving. Directional matrix acquisition excludes incoming-start/outgoing-destination work and reuses valid pairs. HTTP requests and selected-leg responses coalesce/reuse within the foreground freshness window. Accounting reserves dispatched operations rather than all planned legs/blocks.

The private Google testing allocation is US$10 total split US$8 personal / US$2 disposable, estimated conservatively per service without assumed free usage. It does not refill on updates or erase historical counters. It is not a provider/account-wide spending cap. Drift v7 adds validated user-owned reusable-trip payloads, preserving old accepted payloads and separate progress.

## Verification

New focused regressions reproduced the old 81-element matrix/repeated-dispatch behavior before the repair. The optimized nine-point fixture requests 64 elements, identical repetition adds zero and one changed point adds at most 17; these use mocked road responses, not live savings measurements. Budget restart/failed-save checks and reusable-ID/Gemini-free reuse checks pass. The deterministic asymmetric-road equivalence fixture also produces the same feasibility, branches and stop order as the previous complete-matrix input. This establishes fixture equivalence, not global optimality or measured live savings.

No Cloud settings, billing activation, personal app reset/install or Gemini generation has occurred during this implementation. Live Routes qualification still requires the owner's disposable signing identity to be authorized. Native map gestures, TalkBack and physical-phone behavior are distinct from synthetic widget renders.

### Completed checks

- `flutter analyze`: no issues. The project wrapper uses the pinned local Flutter SDK and ignored private configuration.
- Focused road/budget/reuse/one-page checks: 16 passed. These include timed-out in-flight request attachment without another reservation, cancellation before dispatch, background/mode invalidation, restart accounting, v6-to-v7 upgrade and reopen, independent run identities, preserved vehicle qualification gates, multiple replacements followed by one update, unchanged complete-proposal reuse and zero new interpretation calls.
- The full suite completed with 459 passes, the existing eight baseline failures and one intentional skip. A subsequent concurrent run stalled during host test loading and was interrupted; the final serial rerun completed in 2 minutes 21 seconds with the same 459 passes, eight baseline failures and one intentional skip. No test was skipped or deleted to obtain this comparison.
- Responsive widget checks: six passed at 390 logical pixels, 320 pixels with 2x text and 768 pixels, including paused recovery and accessible replacement actions. Synthetic renders were inspected; they do not qualify native map gestures or TalkBack.
- The guarded disposable Android fixture passed (`WAYDAY_RECOMMENDATION_FLOW_PASSED`), including the combined page, Back/retained selections and naming/saving a reusable trip through SQLite. The final repeat took 242.2 seconds to build and nine seconds for the fixture. Interpretation, places and roads in this fixture are mocked.
- The ordinary debug APK built successfully in 169.4 seconds. Package: `dev.wayday.wayday`. Signing SHA-1: `DB:F4:CB:E2:C5:F4:D0:39:27:E8:3D:C0:87:0C:57:5C:5B:43:8A:1B`. APK SHA-256: `D481501FEB091E9CA9C44624F91C36B70EF8BC3BB5B25E84A33905A4D7F14CB4`. This APK was not installed on the personal phone.

The eight baseline failures remain: online pin confirmation; three regional-map cases (unavailable map at large text, missing credits and blank renderer); two saved-place/Profile cases; and two Today endpoint/manual-label cases. They are outside D61 and remain failures, rather than evidence of an entirely green suite.

### Controlled live qualification

One explicit disposable rehearsal stopped at `operation=seed`, `kind=access`, HTTP status `403`. No automatic retry, Places discovery or route-matrix qualification followed that failure. It does not establish a lack of suitable businesses or identify the personal phone's provider behavior. The last owner-reported Routes key settings list only the personal package; the isolated package is `dev.wayday.wayday.maptest`. Verify that exact package and the same SHA-1 on the existing restricted Routes key before another separately approved rehearsal. Do not weaken restrictions or change billing to bypass the rejection.

The isolated accounting file retained its US$2 allocation and US$0.01 conservative Routes reservation across the later fixture update. That reservation is an application estimate for a dispatched failure, not a confirmed Google charge. Remaining free usage and account-wide spend have not been verified. The owned disposable emulator was shut down without wiping its data. No personal phone harness, personal installation/reset, Gemini generation, Cloud modification or allocation refill was used.

### Cost estimation

Current first paid-tier global rates were rechecked on Google's [pricing list](https://developers.google.com/maps/billing-and-pricing/pricing) and [Routes billing guidance](https://developers.google.com/maps/documentation/routes/usage-and-billing). Matrix elements are charged individually; HTTP batching alone is not an element saving. Conservative local estimates, without presumed free usage, are:

| Operation | Estimate per unit |
| --- | --- |
| Basic road matrix element / route query | US$0.005 |
| Traffic-aware driving element / route query | US$0.010 |
| Two-wheel enterprise element / route query | US$0.015 |
| SDK Text Search Pro request | US$0.032 |
| SDK Place Details Pro refresh | US$0.017 |
| UI Kit search reservation | US$0.005 conservative bound |
| Navigation request | US$0.025 |

Services are recorded separately. Reservations occur before dispatch; known unsent work is released, dispatched failures remain conservatively counted. Historical counters stay readable. The Google search admission guard is now 1,000 starts per rolling day, retaining the existing 20-per-minute guard and spacing; the durable monetary allocation remains the additional testing bound. Other-provider limits remain unchanged. Estimates do not enforce an account-wide Cloud budget; reconcile actual SKU usage before any future allocation increase.

### Remaining qualification

Live whole-trip branch/road quality remains blocked by Routes access. Physical-phone behavior, TalkBack, native map gestures, approximate/denied location behavior and real navigation remain separate qualification work. Saved templates deliberately retain no road geometry, live ETAs, matrices or copied Google business text. A saved template refreshes the selected IDs and roads before starting; it does not promise offline or request-free navigation. Future shared errands/live-location sharing remain documentation only.
