# Plan my day implementation plan

Updated: 2026-10-30, Asia/Manila.

Status: The owner authorized implementation after this document was written. A bounded Android presentation implementation connects interpretation review, visible candidate comparison, on-device scheduling, route review, accepted-plan persistence and embedded guidance. This is a private debug pilot, not a verified all-mode release. D55 supersedes the earlier Gemini presentation allocation: use persistent understanding reuse without app-imposed daily/monthly or total-attempt caps. Failed/interrupted processing still requires explicit retry. The owner reported updating Google billing; its current live status was not independently verified. See [implementation evidence](evidence/phone-planner-implementation-2026-10-30.md) and [D55 qualification](evidence/gemini-reuse-and-actions-2026-10-30.md) for checks and remaining limits.

The owner explicitly requested this focused planning document before implementation. It replaces neither the product requirements nor completed-work evidence and does not restore the former project-wide roadmap or task board. The presentation is expected within two to three days; an exact date/time has not been supplied.

## Goal and current state

Wayday will turn user errands and notes into a reviewable day plan: understand the intended needs, recommend suitable places, choose branches and stop order, combine compatible errands into shared visits, and calculate an estimated schedule. Users can accept the recommendation or correct its interpretation and selected places. Starting the trip must open navigation inside Wayday rather than redirecting to the Google Maps application.

The Android phone and ordinary internet connectivity must be sufficient during the presentation. No USB connection, ADB forwarding, reachable laptop, local API, PostGIS installation or Valhalla service may be a runtime prerequisite. Personal errands and progress remain local by default. Online interpretation, new place discovery and fresh traffic-aware estimates still require their online services.

Existing foundations include Today, Recurring, focused errand editing, local Drift/SQLite persistence, a shared location picker, Google-first Places UI Kit search, explicit Other sources and temporary Google coordinate references. Plan my day now opens the preparation flow. The implementation uses Gemini 3.1 Flash-Lite through a native private-installation bridge, a worker-isolate Dart scheduler, restricted Google Routes requests and the Google Navigation Flutter plugin. Fixture verification and a successful build do not establish live interpretation quality, branch suitability or real-road guidance.

Read [product requirements](../../README.md#product-requirements), [Design](../../DESIGN.md), [Architecture](ARCHITECTURE.md), [Stack](STACK.md) and D42–D46 in [Decisions](DECISIONS.md) alongside this plan. The [v1 contract](evidence/planning-contract-v1.md), schema, synthetic examples and measured routing study remain specifications and historical evidence, not a production API or solver.

## Agreed product rules

- Gemini is the selected interpreter for English, Filipino and Taglish sentences in titles and notes. Preserve original wording, current titles, explicit edits and confirmed fields. Search aliases may assist matching but do not replace the sentence interpretation requirement.
- Model output proposes structured needs and clarification questions. It must not invent businesses, inventory, menu items, coordinates, opening hours or road travel estimates. Extra errands or new dependency rules extracted from notes require visible confirmation before application.
- Fixed destinations remain fixed until the user changes them. Flexible errands such as grocery receive recommendations. A missing private meeting point requires explicit selection through search, a saved place or a positioned map pin.
- Grocery candidates can include supermarkets, discount stores, convenience stores and wet markets, qualified by notes and preferences. A category or brand alone does not establish stock. A food request such as pares needs relevant place evidence, rather than an arbitrary restaurant.
- Several errands may share a physical visit while retaining separate IDs, durations, dependency rules and completion states. A nearby separate visit is another option. Geographic proximity alone does not establish the same business or prove that it can satisfy both needs.
- All active unfinished mandatory errands must be included in an accepted feasible plan. Users may explicitly defer errands after reviewing their dependent tasks; deferred tasks stay in Today and retain their required/optional status. Optional active errands may be omitted with a reason. Respect known business intervals, appointments, arrival/completion deadlines, waiting, buffers and the final destination deadline. Unknown hours require a provisional/check-hours notice.
- Replanning preserves completed history and newer edits. Navigation rerouting changes a road path; it does not independently establish a new feasible errand order or silently complete a task.

## Clarification answers and flexible recommendations — D57

The owner authorized this implementation on 2026-10-30. A question opens a focused modal answer sheet rather than the errand editor. It contains the errand name, question, answer field, relevant action and Use answer. Free-form English, Filipino and Taglish go through Gemini. Typed optional preferences can also use the explicit local Let Wayday recommend choice. Processing disables duplicate submission. Successful storage closes the sheet and replaces the question with an editable summary. Essential unknowns keep an actionable follow-up and offer the existing location/time control or Plan the other errands.

Unknown grocery items mean general shopping-place recommendations and choosing items on arrival. Neither Gemini nor Wayday invents a shopping list or asserts inventory. Existing items, explicit place preferences, selected points, timing and durations remain authoritative. In particular, an unconfirmed 15-minute estimate remains 15 minutes and remains labelled estimate. Timing and dependency proposals require a separate visible approval; existing dependency rules are retained.

Question records own drafts, submitted answers, statuses, validated results and rule approvals. Editing another field cannot resolve a question. A source-context hash binds local sessions to the original interpretation inputs; dated deferrals belong only to their selected plan date. Closing before submission keeps a draft without applying it. Closing during processing keeps the submitted work. Reopening pending work checks saved output without generating. Failures retain the answer and require explicit retry; retrying a failed local save does not call Gemini.

Initial interpretations now contain typed question scope and essential/optional metadata. The original payload builder remains a frozen legacy lookup path: compatible completed understanding is reused before a new typed request. Failed, pending or corrupt legacy entries do not become automatic retries through the schema change. Both workflows share transport, duplicate coalescing and validation. Native clarification snapshots have their own 32-entry no-backup journal, separate from the eight interpretation snapshots. Neither workflow imposes a daily, monthly or total-attempt allowance.

Drift v5 adds clarification_sessions without modifying Today, Recurring or accepted progress. Independent question revisions are merged to prevent late completion from overwriting a newer draft or another answer. Accepted itinerary payload v2 stores question summaries/results and explicit deferral reasons, and continues reading v1. Assigned tasks, optional omissions and explicit deferrals form distinct validated groups. A plan with no active errands cannot proceed. Excluding a prerequisite previews the dependent closure; re-inclusion is explicit and prerequisites must be included first. Relevant answer changes invalidate affected automatic candidates and the calculated schedule. Real provider results, native Google presentation, attribution and temporary-coordinate rules remain unchanged.

Qualification uses mocked services, additive-migration/restart tests, sheet/accessibility renders and an isolated .maptest emulator with no personal package. Never use the integration harness on the personal phone or spend live requests for these checks. [D57 evidence](evidence/clarification-flow-2026-10-30.md) records the results and remaining limitations.

## Interface and design contract

Use the implemented single light Canvas/Cornflower theme, Figtree typography, compact numbered rows, quiet outlined surfaces, focused editors, existing numeric time entry, selection sheets and feedback. Reuse Flutter theme tokens and shared widgets rather than creating a separate planning design system. Maintain 48-dp touch targets, readable action text, safe areas, keyboard handling, large-text reflow, semantic labels and reduced motion.

The existing Impeccable metadata is available, but its older Today surface brief describes superseded in-memory data and an illustrative map. Reconcile that context with current README, DESIGN and the Flutter theme before using it for design review. No active Impeccable tool was available during the readiness review; do not claim a tool-based review without performing it.

The main preparation pages are Review errands, Recommended places and Your day. Loading states, a conditional location picker and the accepted-plan summary connect them; avoid forcing every errand through an identical wizard.

| Screen or state | Visible content and interactions | Forward, Back and cancellation behavior |
| --- | --- | --- |
| Today | Existing From/Errands/To input and Plan my day action. | Immediately open the understanding/loading state for the current input revision, reusing a matching saved interpretation. Preserve existing input and the previously accepted plan. |
| Understanding your errands | The first preparation screen, with no introductory page or Continue button. Check local saved understanding first; Gemini runs only when matching saved understanding is absent. No invented percentage or simulated result. | Back/Close returns to Today. A bounded request already sent may finish and save its answer. Reopening attaches to in-flight work or restores the saved result. Interrupted/failed attempts require an explicit paid retry. |
| Review errands | Compact numbered rows show timing, visit length and optional status. Expand a row for notes, search/items, prerequisites, Edit errand, and only actual applicable Current/Suggested differences. Use suggestion and Keep current replace the per-errand approval checkbox. Trip details expands for date/time/endpoints. Questions and required location actions remain visible. | Explicitly choose proposed rules or add an extra errand before applying it. Next: find suitable places stays anchored and continues when required information is resolved. Review remains available to check trip inputs even when there are no suggestions. Back/Close returns to Today; re-entry reuses matching understanding. The redundant Review app-bar action is omitted on this page. |
| Missing location | Shared full-screen picker with search, saved places, interactive map and pin confirmation. It identifies which errand or endpoint needs a real location. | Confirm location commits the location to the preparation draft and returns to review. Cancel retains the preceding value. A flexible store need is sent to recommendations instead of being treated as a missing private address. |
| Building your day | Actual progress through place discovery, road-time checks, branch/order comparison and shared-visit assessment. Keep cancellation available. | Continue automatically after valid results. Distinguish missing candidates, unsupported mode, outage, timeout and proven conflict. Retain the draft and last accepted plan on failure. |
| Recommended places | Selected recommendations for flexible errands, available sourced details, reasons and visible limitations. Existing fixed places remain selected. Shared-visit suggestions retain individual errands and flag uncertain availability. | Change place opens alternatives; user can also choose a specific place through the picker. Return to recommendations and recalculate affected estimates. Next: see my day opens the valid proposed itinerary. No mandatory manual selection of every branch. |
| Your day | Google map, road route and numbered stops above a readable timeline. Show arrival/service/departure estimates, waits, relevant constraints and a separate explained list of omitted optional errands. | Tap a map pin or timeline row to select the same stop and reveal details/actions. Pan/zoom only inspects the map. Changing place/time invalidates affected estimates and requires recalculation. Use this plan is available only for an accepted feasible/provisional result without unresolved mandatory issues. |
| Your plan | Accepted itinerary summary, first stop, relevant notices and access to the stop list. This can reuse the result layout with accepted-state actions. | Save the accepted snapshot transactionally before offering Start trip. Return to Today preserves the accepted plan. A save failure offers retry and does not claim success. |
| Your trip | Embedded Google navigation where supported, next-stop details, errands and explicit completion controls. | Start trip initializes guidance deliberately. Arrival does not mark an errand complete. Branch changes or delays can request replanning of unfinished work. Stop guidance and return to the itinerary without discarding progress. |

Within preparation, Back preserves the current session draft. Closing preparation does not replace the last accepted itinerary. Reopening after a process restart must recover persisted source inputs and permitted accepted-plan state; interrupted provider work is not resumed automatically. The existing editor's Save/Cancel behavior remains explicit. Map attribution and required native controls must remain visible.

## Transportation and map boundaries

The owner requested all five top-level choices for the presentation, then clarified the following practical boundaries after regional coverage was reviewed. These are intended behaviors, not verified service capabilities.

| Choice | Planning and guidance boundary |
| --- | --- |
| Walking | Qualify actual walking estimates and in-app walking guidance. Show applicable provider limitations. |
| Biking | Reuse the motorcycle interface structure while using actual bicycle-specific road calculations. Qualify routing and guidance separately, and assess an alternative provider when necessary. Never relabel a motorcycle or car route as a bicycle route. If a suitable route/guidance capability cannot be obtained, show an explicit unavailable state. |
| Motorcycle | Qualify the actual two-wheeler routing and embedded navigation paths in the Philippine presentation area. Earlier driving qualification does not establish motorcycle support. |
| Sedan | Use qualified ordinary driving estimates and embedded driving guidance. Do not claim low-ground-clearance verification. |
| Truck | Limit the initial usable option to an explicitly identified light pickup compatible with ordinary driving assumptions. Label it as an ordinary driving estimate without truck-restriction or clearance verification. Heavy/restricted delivery vehicles, including ten-wheelers, remain unavailable. Do not infer a permitted vehicle class from height or wheel count alone. |

Before an ambiguous Truck selection can start calculation, require the user to identify the light-pickup case or show the unavailable heavy-vehicle explanation. This narrows the presentation behavior, not the enduring requirement to investigate genuine truck restrictions and dimensions. Preserve the distinction between ground clearance and overall height, weight and legal access.

Google's published Philippine navigation table marks bicycle guidance as unavailable or low data quality. Google's truck-specific large-vehicle routing is limited to provisioned customers and documented US/Japan coverage. Therefore, all-five end-to-end readiness is not guaranteed within two to three days. A warning is not a substitute for a missing capability. [Navigation coverage](https://developers.google.com/maps/documentation/navigation/android-sdk/coverage-nav-sdk), [large vehicle routing](https://developers.google.com/maps/documentation/routes/lvr).

Keep MapLibre for the existing location/manual/offline experiences. Google Routes content must use a Google map during route review. Use embedded navigation inside Wayday for supported trips; external app redirection is not the primary experience. An alternative bicycle provider must be qualified for its own route data, in-app guidance, display terms and credentials; generating a polyline alone does not complete navigation support.

## Implementation structure and minimum interfaces

Keep the Flutter feature/view-model/repository structure and the existing provider adapters. Add planning and trip domain logic behind feature controllers, not inside widgets. Run bounded CPU-heavy schedule search in a Dart worker isolate; no laptop-hosted solver is required.

Separate these internal values and operations; choose an explicit mobile format version before persistence or interoperability work:

- Planning input: stable errand IDs, current/original text, notes, confirmed values and provenance, fixed/flexible/meeting-point intent, editable needs/preferences, durations, timing, dependencies, date/timezone, endpoints, profile and input revision.
- Interpretation result: typed proposed changes, proposed extra errands, references to existing IDs and focused clarification issues. It cannot directly mutate saved tasks. Validate model output and user approval before merging it into a draft.
- Candidate result: provider reference, permitted coordinate lease, qualification evidence, known/unknown hours and inventory limitations, and the owning search-session/revision. Keep source records and native Google presentation intact.
- Plan result: correlated request/revision, outcome, selected physical stops, ordered errand assignments within each stop, schedule/waiting/buffers, omissions, source timestamps and warnings. Keep permitted transient route content separate from durable task-owned state.
- Accepted plan and trip progress: accepted input/profile snapshot, stop-to-errand assignments, permitted place references, calculation metadata, active stop and per-errand completion history. Save atomically and restore independently of the current preparation session.
- Services: an injectable interpretation adapter, candidate-session adapter, road-estimate adapter, bounded scheduler with independent result validation, accepted-plan repository and navigation adapter. Use typed failures and cancellation/revision guards across them.

The original wayday.planning.v1 HTTP schema does not specify shared stops or the revised Google retention boundary. Preserve its examples and tests; do not silently change their meaning or advertise an API that does not exist. A future backend remains separately scoped.

## Implementation sequence

The sequence below remains the feature contract. D47 records the implementation boundary: a private Android debug installation uses Android Keystore encryption and explicit finite generation provisioning instead of introducing an unconfigured Firebase project or laptop service. Release/public Gemini access remains unavailable until a managed protection boundary is qualified. The owner confirmed paid Gemini billing and then authorized proceeding while conserving roughly $4 remaining credit. Default provisioning remains zero; the authorized presentation allowance is ten total attempts, split as one qualification request and nine phone requests. Request caps are per installation and do not control other Cloud usage.

The initial visible discovery step compares at most three eligible results from each search around the starting point. Users can refine the query or choose another location through the existing picker. It does not automatically search every route anchor or certify inventory. The bounded matrix allowance can require fewer alternatives. These are current pilot limitations against the broader discovery goals below.

### 1. Qualify the external integration boundaries

Resolve these checks first, using bounded explicit experiments and sanitized evidence rather than repeatedly calling providers during automated tests:

- Select the Gemini model and protected mobile connection, validate the actual project availability/pricing/data terms, and set finite timeout/request budgets. Firebase AI Logic is the recommended connection to assess, not a configured dependency. The supplied key is stored in ignored .env.local; do not compile it into Flutter defines or the Android manifest. Gemini adoption is agreed; a vocabulary-only replacement is not the intended feature.
- Prove that standard visible Google UI Kit components can supply eligible candidate ID/coordinate batches for branch comparison and display the recommended selection. The current Flutter bridge receives counts and selected metadata. Preserve native cards/order/attribution; no scraping, hidden catalog, invented names/hours or automatic raw-API substitution.
- Qualify route/matrix behavior and guidance for each intended mode. Establish an actual bicycle-provider path if Google cannot support the demonstration. Check the Navigation SDK/plugin dependency boundary with the existing Places bridge before adding packages.
- Confirm saved Console quotas and actual remaining account capacity. Budget matrix elements, route requests, place component loads and navigation destinations separately. Preserve restrictions and fail closed at the configured limit. No billing activation, purchase, unrestriction or automatic paid fallback.
- Resolve provider-specific permissions for persisting route geometry, computed schedule values and other response content. The thirty-day coordinate-caching exception is not permission for indefinite route-content storage. Persist user-owned text, task rules/progress and permitted IDs; retain existing coordinate expiry.

If a check fails, retain the agreed product requirement and record the concrete failed capability. Narrowing the selected service or presentation behavior needs an explicit decision; do not disguise manual-only work or unsupported routes as successful automatic planning.

### 2. Repair input consistency and establish safe drafts

- Add one shared dependency-order operation with stable ordering, cycle/missing-reference validation and preservation of unrelated order where possible. Use it for Today, Recurring drafts/copies and manual review.
- Persist corrected order and dependency values together. Reconcile previously inconsistent valid lists through the same path with explanation and Undo; do not silently delete references to force an order.
- Advance input revision for meaningful edits/order/completion changes, preserve complete confirmation provenance, and retain category/brand metadata when reusing a saved place.
- Separate source input, preparation draft and accepted itinerary. Reject obsolete provider/solver completions after edits, cancellation, source changes or backgrounding. Preserve the last accepted result when new preparation fails.
- Keep migration additive and preserve existing v2 SQLite rows. Do not reset the owner's data or restore sample seeding.

### 3. Connect interpretation, clarification and candidate review

- Connect Gemini through the qualified adapter. Minimize submitted data to the text and structured context needed for interpretation; do not send home/GPS coordinates or full private history by default. Explain online text processing at the relevant first use without introducing account or task-sync requirements.
- Validate typed suggestions and separate them from confirmed values. Current title/notes guide new suggestions; preserved old original text must not reinterpret a renamed errand. Require approval for new errands/dependencies and clarification for ambiguous people, places or times.
- Implement Review errands and conditional location correction using existing editors/pickers. A past date/departure requires an explicit updated dated departure or a current-time planning choice, not silent rollover.
- Retrieve bounded candidates for flexible needs around relevant route anchors. Keep fixed overrides, session identity, attribution and existing source-choice behavior. Compare at most three qualified candidates per flexible errand initially; widening the search or changing source is explicit.
- Implement recommendations and alternatives without requiring every store to be manually selected. Record why a candidate matches the stated needs and whether suitability is established, inferred or needs confirmation.

### 4. Calculate and independently validate the itinerary

- Fetch asymmetric road estimates for the selected profile/date/options. Preserve unreachable elements, failures and fallback metadata. Do not substitute straight-line or zero travel times, and never reuse another mode's matrix silently.
- Search branch alternatives, eligible next errands, optional omissions and shared visits. Hard constraints and mandatory completion come first, then optional completion, then lower road travel, with fewer distinct visits as a tie-breaker. Independently validate every proposed accepted schedule.
- A shared stop retains internal task order. Sum sequential explicit durations unless the user confirms overlap. Use one documented arrival/parking buffer per visit rather than duplicating it because two errands share a place; version and test that extension of the old per-errand policy.
- Respect service-start appointments, arrival deadlines, finish-before including buffer, business intervals, waiting, prerequisites and final arrival. Reject cycles before solving. Missing hours may be provisional; known closure cannot be ignored.
- Use the existing five-second solver budget and twelve-errand/three-candidate caps only as provisional resource policies. Measure four-, eight- and twelve-errand workloads on the physical phone before enabling their supported capacities. Timeout is not proof of conflict or global optimality.
- Count distinct matrix locations and actual pairs before dispatch. A naive 38-by-38 matrix has 1,444 elements and must not be treated as one ordinary Google request. Batch within endpoint/account limits and cap refinement passes.
- Validate the selected sequence with intended leg departure times and stop/wait durations where supported. A common-departure initial matrix is an approximation; a route through waypoints does not automatically include Wayday's service times.

### 5. Implement review, acceptance and embedded trip execution

- Build the Google route map and synchronized timeline using existing visual tokens. Map interaction selects a stop or changes the camera; it does not automatically issue new planning requests.
- Recalculate after an explicit alternative/time/profile change. Show provisional limitations, optional omissions and actionable failures distinctly. Never enable acceptance for unresolved mandatory data or an invalid schedule.
- Commit the accepted itinerary and task-owned progress through the versioned repository transaction. A failed save leaves the draft available and offers retry; do not start a trip against an unpersisted accepted snapshot.
- Start supported embedded navigation only after the user taps Start trip. Keep per-errand completion explicit, prevent duplicate completion, and recover the active itinerary after restart. Stop guidance without deleting the itinerary. Replanning starts from explicitly acquired current position/time and preserves completed work.
- Keep guidance, road rerouting and Wayday schedule replanning separate. Background tracking, follower alerts, reminders and killed-app delivery guarantees are outside this implementation.

## Verification and acceptance

- Input/storage: version upgrade and restart, current notes, confirmation provenance, revision increments, dependency correction/Undo, missing/circular references, stable IDs and independent Recurring copies. Verify that cancelled review does not replace the accepted itinerary.
- Interpretation: English, Filipino and mixed sentences, multiple needs in notes, unknown items, ambiguity, proposed extra errands, invalid model output, service failure and stale completions. Use fixtures in routine tests; never assert unrestricted language understanding.
- Discovery: fixed-place preservation, bounded batch candidates, explicit source changes, native attribution, missing metadata/hours, duplicate branches, no candidates, quota exhaustion and expired coordinate references. No stock or menu guarantee from category alone.
- Scheduling: compare tiny cases with exhaustive enumeration and independently validate fixed asymmetric matrices. Cover shared visits/internal task order, incompatible places, duration/buffer accounting, waiting, arrival versus completion deadlines, optional ancestors/omissions, unreachable legs, timeout and replanning history.
- Navigation: actual mode reaches routing and guidance; bicycle routes remain bicycle-specific; light pickup is labelled accurately; heavy vehicles are blocked. Test missing permission, unavailable services, Stop/Back, explicit completion, route changes and restart recovery.
- Design: compare every new screen with DESIGN and the existing Flutter app on a small physical Android viewport, with long Filipino text, increased text scale, keyboard open/closed and reduced motion. Check touch targets, TalkBack labels/focus, visible attribution and draft-preserving Back/Cancel behavior.
- Run Flutter analysis, focused tests, the full suite and an Android build through the mobile guide. Establish the current baseline before changes; earlier recorded failures are not a substitute for a fresh baseline. Attribute regressions separately and record actual checks in Progress.
- Final presentation rehearsal: use a standalone APK on the phone with USB, ADB forwarding and developer services disconnected. Enter sentence-level notes, clarify a missing meeting point, obtain real bounded recommendations, change one recommendation, inspect the route/timeline, accept, start supported embedded guidance, complete an errand and recover permitted state after restart. Repeat without internet to confirm retained local input/progress and honest unavailability for fresh online work.

## Readiness and documentation updates

Gemini model/connection, automatic candidate access, bicycle routing/guidance, real quota capacity, full-size phone performance and provider-specific result retention remain open technical gates. The product and interface requirements above are sufficient to plan their qualification, but the entire feature must not be labelled implemented or verified until those gates and the final rehearsal pass.

Implement this focused plan only in a subsequent implementation step, as requested by the owner. No app code, migration, SDK installation, external configuration or live provider request is part of this documentation update. Keep the owner's existing uncommitted work intact.

During implementation, update Decisions for changed assumptions, Architecture/Stack for verified integration choices, the mobile README for executable setup/checks, DESIGN and relevant Impeccable context for actual UI behavior, and Progress for completed work and evidence. Do not create a separate project-wide roadmap, duplicate task board, public deployment or billing setup as a side effect.


## D48 — Direct entry and durable interpretation reuse

The owner removed the introductory Plan my day page and requested persistent result reuse after Back/app closure. Entry now shows Understanding your errands immediately and starts a cache-first lookup. There is no initial Continue with Gemini action. Successful results go to Review errands; failures show recovery actions rather than the removed introduction.

A bounded native response journal in app-private no-backup storage retains up to eight interpretation snapshots (at most approximately 1.3 MB). This is kept at the native request boundary so an answer can be saved before a Flutter callback, even when the originating screen/engine closes. No SQLite schema migration or new storage dependency is needed. The key is SHA-256 over a versioned model/policy prefix and the exact canonical request, including prompt/schema/generation settings. Input context includes current IDs/order, titles, notes, explicit timing, visit duration/confirmation, optional status, prerequisites, confirmed fields, fixed-place intent and flexible place preferences. Equivalent confirmation/dependency sets are canonicalized. Changing any submitted context invalidates that snapshot; old snapshots can be reused when an edit is undone.

Route date/profile/departure/endpoints and raw coordinates are not sent to Gemini, so changing those alone does not consume another interpretation request. Expiring a Google coordinate lease also does not reinterpret the same fixed-place intent. Relative dates require structured clarification instead of resolving against the clock. Real place/road data and schedule validation are recalculated separately and are not stored in this journal.

Persist pending state before dispatch and completed state before callback; revalidate cached model output against the current errand IDs/types. Reuse completed answers without checking credential allowance or reserving another request. Back/Close does not deliberately cancel an already-paid interpretation; matching concurrent callers share it. A process killed before completion leaves a pending marker. That marker cannot prove whether Google charged or returned an answer; never automatically send a replacement. Check saved understanding is safe for an existing pending/failed marker; Retry Gemini explicitly permits another bounded attempt. Corrupt/unvalidated records similarly fail closed rather than masquerading as a cache miss. Ordinary count limits remain unchanged, and no allowance is refilled by this feature.

This caches Gemini understanding, not unaccepted review checkboxes, Google search results, route geometry or ETA data. Normal accepted plans/progress retain their separate local persistence.


### D49 review refinement acceptance

The compact review preserves D47 approval semantics and D48 cache-first entry. Only domain-applicable changes are offered; confirmed or equal values do not create review work. Named suggestion selection is reversible after moving forward and returning. Extra errands remain opt-in, while missing private locations and clarification questions remain discoverable without opening every row. The primary action stays visible independently of list scrolling. Verify narrow/large-text wrapping, reduced motion, and the existing direct-entry/cache regression cases without live Gemini requests. Native accessibility and a complete live itinerary rehearsal remain separate qualification checks.


### D50 location-question correction

Use current structured place state before requiring a location answer. Saved usable coordinates satisfy the location requirement. Unattached business/activity errands proceed to recommendations, including when a user cleared an earlier place. Show Place recommendations next rather than asking the user to provide a store. Private pickup/meeting points and expired explicit place references retain their location-confirmation path. Review display and Next validation must share this policy. Suppress recognized location-only questions from existing cached results without altering their cache identity; retain genuine timing/order/mixed/unknown clarification questions. Regression checks must use cached/fixture answers without paid generation.


### D51 preparation feedback acceptance

Reproduce an invalid past departure, correct its date through the existing calendar, and confirm that the old warning clears before pressing Next. Repeat for departure/deadline corrections through numeric time entry. Cancelling the date editor must leave the original warning/input intact. Next must still reject a genuinely past departure and proceed for valid future input. No interpretation request or automatic date change is part of this correction.


### D52 investigation and acceptance

D51's stale-label correction did not retain edited review settings after Close, app termination or an update. The current behavior adds local, source-bound retention of explicitly saved review date/departure/deadline while leaving Today and accepted progress untouched. Restore those values before interpretation; the existing cache identity excludes this route context. Ignore a snapshot after source input changes, expose storage failures, and keep replanning/history inputs independent. The first correction still requires the user to choose a future departure; there is no automatic date or appointment adjustment.

Preview selected After rules immediately with the same effective projection used by forward validation. Test selection/reversal before Next, including an invalid departure that previously prevented reconciliation. Preserve explicit dependency values and source records. Show exact expired-date/time recovery actions and keep Next unavailable until corrected. Verify both reported clock cases: October 30 at 3:27 AM is before an October 30 8:30 AM departure, whereas October 30 at 11:49 AM is after it and after an October 29 departure.

Verify v3-to-v4 migration, actual SQLite close/reopen, source invalidation, serialized edits, failed-save retry, review Close/reopen and replanning isolation. Use the isolated Android planning recovery fixture, never paid Gemini generation or the personal app's cache. Record test/build/device evidence separately from a complete live itinerary rehearsal.

### D53 field verification acceptance

Before place discovery, verify the selected date/time zone, departure/final window, errand identities/titles/count, visit duration and timed-rule minute values. Reject a mandatory arrival/start before departure and impossible service/finish/dependency lower bounds even without road travel. Show the conflicting errand with an Edit action and disable Next. Retain optional omission and shared-stop arrival semantics. Recheck elapsed departure and broken graphs before road requests. Real road feasibility, opening hours and inventory certainty remain separate from these structural checks.

Retain manually corrected errand timing after Close/reopen and SQLite recreation, without modifying Today. Restore it only after interpreting the unchanged original source, preserving the existing cache identity. Test legacy three-field review payloads, corrupt clock values, source invalidation, manual-only retention, unrelated clarification preservation and normal editor removal behavior. Inspect normal/narrow large-text conflict recovery. Qualify through synthetic Android fixtures without paid requests. See the [field audit](evidence/planning-field-validation-2026-10-30.md) for every checked boundary and remaining limitation.

D54 verification constraint: use a disposable emulator without the personal package for the native harness. The phone recovery probe demonstrated an explicit retry prompt with the same seven-attempt balance, not a regenerated interpretation or full itinerary. The original journal was lost during the test/install reset; do not auto-spend or seed it to replace the missing result.

### D55 cache-first requests and consistent recovery acceptance

Gemini has no Wayday daily/monthly or finite-attempt cap. Matching stored results and identical in-flight requests reuse understanding; changed interpretation inputs require new processing. Routing-only changes remain outside interpretation identity. Check saved understanding is strictly read-only, including on a cache miss. Explicit Retry may generate, but ordinary reopen never automatically retries pending/failed/corrupt/recovered work. Preserve source validation and credential protection.

Verify repeated/reopened inputs, changed-input misses, concurrent taps, explicit retry, more than three fresh mocked requests and legacy zero counters. Verify filled/outlined recovery actions share normal-size geometry and remain usable at narrow/large text and by keyboard. Google provider limits and unrelated route/search limits remain separate.
