# Business hours in route-aware recommendations — D63

Date: 2026-10-31, Asia/Manila.

## Owner decision and implementation

The owner approved business hours as recommendation and schedule inputs, with ordinary display limited to Details and Choose a place. Unknown-hour businesses remain eligible with a warning. Flexible visits cannot wait for opening; explicit appointment waiting and the existing five-minute buffer remain. This supersedes D58's omission of hours fields, without replacing the provider, model, solver or map stack.

The pinned Android Places SDK 6.0.2 bridge now requests OPENING_HOURS, CURRENT_OPENING_HOURS and UTC_OFFSET in existing search/details requests. Snapshot profile v1 includes structured periods, weekday text, exceptional-day metadata, place-local coverage date and acquisition time. Bridge status version is 3. Null/malformed periods do not become fabricated times. The Dart field-profile cache identity and sufficient-metadata checks distinguish older responses from completed hours checks.

Transient BusinessHours/HoursDay metadata evaluates dates in the existing Philippine planning clock. It handles current seven-day coverage, regular weekly fallback, split shifts, week-wrap/overnight periods, 24-hour sentinels and dated periods. Missing coverage for a future trip differs from Google providing no hours at all. Available, not-requested, missing, failed and stale states remain distinct. Provider content stays in the current session, with the existing five-minute foreground validity; it is not added to Today, clarification, recommendation-draft or reusable-trip JSON.

HoursQuery is an optional internal discovery/browsing input. It filters candidates with no sufficiently long interval anywhere in the selected trip before the existing three-candidate shortlist. Google search contexts remain one corridor and at most two anchors, with cached full-response reuse, provider-ID deduplication and existing suitability/brand filters. The browsing pool stays separate from the solver. Closed current selections remain visible in alternatives instead of silently disappearing. No open-now restriction or separate isOpen request is introduced.

The controller passes date-specific windows and allowOpeningWait=false to the existing solver. Complete service plus buffer must fit; branch/order selection, appointments, independent optional omissions and shared task identities remain. Selected metadata is refreshed only when insufficient/stale, without Gemini or automatic business discovery. Hours affect proposal validity. After road refinement, the controller rechecks the same hours snapshot; conflicts name the errand, retain choices and block acceptance. Explicit overrides are never silently replaced. Unrelated trip endpoints and manual pins do not trigger hours lookups.

PlaceHours provides trip-day periods, weekly disclosure, retrieval time and validated-visit compatibility inside Details. Choose a place shows periods without claiming an uncalculated branch fits. Missing, failed, stale and trip-date coverage states have distinct copy; failed/stale checks offer explicit retry while retaining the place. A dropped pin without a Google business identity gets no nearby inferred business. The unconditional page-wide hours notice is removed; the buffer explanation remains separate. These fields do not establish inventory, membership, service-specific pickup readiness or appointment capacity.

## Pricing and policy basis

Conservative request estimates are US$0.035 per enriched Text Search and US$0.020 per enriched Place Details. Admission/preflight, reservations, explicit field-aware request identity, request spacing, coalescing across caller timeouts and conservative dispatched-failure accounting remain. Existing counters and the US$8 personal/US$2 disposable allocations are not reset or replenished. No free balance is assumed.

Google's Android field table currently labels hours as Text Search Pro, while the dedicated SKU billing page lists them as Enterprise triggers. The higher published rate is used; it is an estimate, not verified charged SKU or actual Cloud spend. No Cloud settings, quotas, restrictions or billing activation were changed. No paid provider request was made for routine verification. Further disposable live work still requires restoring/reconciling the original allocation with at least US$0.782 reserved.

Primary sources reviewed:

- [Android place fields](https://developers.google.com/maps/documentation/places/android-sdk/data-fields), [OpeningHours](https://developers.google.com/maps/documentation/places/android-sdk/reference/com/google/android/libraries/places/api/model/OpeningHours) and [Place Details](https://developers.google.com/maps/documentation/places/android-sdk/details-place).
- [Period/coverage definitions](https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places#OpeningHours) and [open-now semantics](https://developers.google.com/maps/documentation/places/android-sdk/text-search).
- [SKU triggers and field-mask billing](https://developers.google.com/maps/billing-and-pricing/sku-details/places), [published global pricing](https://developers.google.com/maps/billing-and-pricing/pricing) and [Android isOpen behavior](https://developers.google.com/maps/documentation/places/android-sdk/reference/com/google/android/libraries/places/api/net/PlacesClient).
- [Android Places policy and attribution](https://developers.google.com/maps/documentation/places/android-sdk/policies). Provider IDs have a storage exception; copied hours are not durable template data.

## Verification record

The no-opening-wait regression first failed: the old scheduler delayed the visit until opening. It now rejects that flexible visit while preserving explicit appointment waiting. Domain cases cover split shifts, whole-visit/buffer fit, weekly wrap, dated overnight periods, closed special dates, usual-week fallback, 24-hour versus missing/closed data, malformed/stale states and missing future coverage.

Mocked service/controller checks cover filtering before shortlisting, retained missing hours, field-profile upgrades, reuse without hidden details calls, failure versus missing data, explicit retry, conservative per-service accounting, joint branch selection and traffic refinement invalidating a confirmed branch. UI checks cover state wording, weekly disclosure, absent compatibility claims for uncalculated places, dropped pins, narrow widths and doubled text. Synthetic captures were rendered and inspected under ignored .tools/hours-screenshots, using bundled Figtree and fixture data.

The final full suite completed with 496 passes, one skip and the same eight baseline failures. Final focused checks passed forty cases; the full run also includes the final dated-Sunday boundary regression and late-response UI guard. The eight failures concern the existing online/manual pin picker, regional map fallback/notices, saved-place/profile picker interactions and Today manual-map editing. No tests were disabled or their assertions weakened for this feature. Enlarged-text sheet tests now wait for layout to settle and bring the entire action into view before tapping; they still assert retained lists and the exact settled per-errand scroll offset. The final full log is the ignored .tools/hours-release-check-suite.log.

The guarded disposable Android fixture built in 357.2 seconds and passed in three seconds. It checks the native bridge profile version, weekly disclosure and missing-hours presentation using synthetic metadata and no live API key. It does not test an actual Google hours response. The owned emulator was shut down without wiping it; no personal-phone installation or data reset occurred. Final analysis passed with no issues in 53.5 seconds.

The final ordinary Android arm64 debug APK built in 120.9 seconds after the final source changes. The ignored log is .tools/hours-final-phone-build.log. The delivery copy is .tools/artifacts/wayday-d63-personal-debug.apk (229,612,772 bytes), verified as package dev.wayday.wayday, version 0.1.0/code 1 and SHA-1 signing fingerprint DB:F4:CB:E2:C5:F4:D0:39:27:E8:3D:C0:87:0C:57:5C:5B:43:8A:1B. Its SHA-256 is 7CB29F9A37E39B320689904899ED59381130971FB2E96DA402860D03C538EF3E. The workspace Gradle daemon was stopped after delivery. This artifact was built and inspected, not installed on the personal phone. Changed-document links, whitespace checks and a tracked-diff Google-key-pattern check passed.

## Remaining qualification and owner rehearsal

Mocked tests do not establish that every Google listing has accurate hours. Actual Philippine listing coverage, holiday completeness, charged Text Search SKU, physical TalkBack/native gestures and unplugged-phone behavior remain separate qualification. The source requires the existing enabled Places API (New) and restricted identity; no additional hours-specific API is introduced. The earlier disconnected-phone symptom is not claimed resolved by these checks.

Update the phone app without uninstalling or clearing data, choose a future trip date/time, then check:

1. Details shows hours when Google provides them, Weekly hours expands, and Checked describes retrieval. Missing hours says so; dropped pins do not acquire invented business hours.
2. Choose a place shows trip-day periods while preserving current place, pager, Show more, manual cancellation and list position. A branch whose whole visit cannot fit must not become a validated recommendation.
3. Test a business closed now but open during the trip. It should remain eligible. Test a branch that closes before the visit finishes; change the branch/time rather than adding opening-time waiting.
4. Replace a branch and check automatic route/timing updates. If refined timing misses closing, choices remain and Start trip is blocked with an actionable conflict.
5. Test a later trip outside current seven-day coverage. Regular data must say Usual hours with special-date uncertainty; absent applicable data must remain unknown. Reuse a saved trip without carrying old hours forward as durable truth.

Keep any live manual requests inside the existing personal allocation. Do not reset counters, seed personal journals, remove restrictions or use the personal-phone harness to repeat tests.
