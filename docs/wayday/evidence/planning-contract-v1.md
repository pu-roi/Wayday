# Wayday pilot planning contract v1

Current implementation planning now lives in the owner-requested [Plan my day implementation plan](../PLANNING.md), created on 2026-10-30 under D46. This evidence document, including the earlier phone-only handoff below, preserves specification history. Use PLANNING.md for the latest presentation-mode boundaries, interface sequence and outstanding technical gates; the original schema/examples are not silently upgraded by that plan.

M5-02 specification, 2026-10-27. This contract follows the measured [routing gate](routing-pilot-2026-10-27.md). It defines future mobile/domain/API behavior; it does not implement FastAPI, recommendation, a solver or mobile planning. The [JSON Schema](planning-contract-v1.schema.json) and [14 synthetic acceptance examples](planning-contract-v1.examples.json) are executable specifications. Their businesses, times and geometry are fixtures, not real planning results.

Current direction note, 2026-10-30: D44 requires phone-only scheduling without a reachable laptop. The original v1 schema, synthetic examples and HTTP descriptions below remain historical specifications. The [mobile planning handoff](#phone-only-planning-handoff-2026-10-30) proposes the revised implementation boundary and shared-stop behavior; it is not an implemented or schema-compatible extension of those examples.

## Ownership, operations and wire values

Keep editable `day_input` separate from calculated `plan_snapshot`. The current Flutter `DayPlan` remains unchanged until its implementation task. The phone owns errands, confirmed places, saved plans, completed history and revisions. The backend calculates transiently; do not persist request bodies, notes or personal history as a side effect. Initial deployment is the existing computer, with no public endpoint or account requirement.

Use JSON requests under the existing proposed `POST /v1/plans` and `POST /v1/plans/replan` boundaries. Both use `contract_version: wayday.planning.v1`, opaque `request_id`, monotonically increasing local `input_revision` and the same `day_input` envelope; `operation` must match the endpoint. Replanning also supplies the previous plan ID, explicitly confirmed current position/time and completed history. No HTTP server is added here. Clients apply a result only when both request ID and revision still match their submitted/current input; completed-stop changes also increment the revision. Preserve the last saved result with its age when offline or when a newer calculation fails.

| Value | Contract |
| --- | --- |
| Confirmed place | Label, WGS84 decimal `latitude`/`longitude`, nullable address and source provider/identity/snapshot date. Unresolved old labels remain local labels; a null endpoint or fixed place needs clarification, never invented coordinates. Manual pins may have no external source ID/date. |
| Date and time | Explicit `plan_date`, IANA `Asia/Manila` and offset-aware local instants with `+08:00`. Calculation/source timestamps may be UTC. Integer seconds for durations, meters for application distances; adapters convert Valhalla kilometers to meters and round fractional travel seconds upward before scheduling. GeoJSON geometry uses `[longitude, latitude]`. |
| Planning day | v1 is one local calendar day. Deadline must follow departure on that same explicit date. A deadline after midnight requires a new explicitly dated day; do not silently roll a smaller clock value into tomorrow. Overnight planning is unsupported in v1. |
| Errand | Stable ID, preserved original text/notes, category and interpretation state, flexible or fixed destination, timing rule, optional status, prerequisite IDs and editable visit/buffer durations with provenance/policy. |
| Candidate | Internal bounded candidate record: confirmed place, category qualification reason, available source/address/hours, freshness and branch identity. A category is not proof of item inventory or a pharmacy dispensing counter. Fixed branches bypass replacement by automatic recommendations. |
| Result | Correlated request/revision, calculation time, explicit status/issues and either an accepted plan snapshot or null. A snapshot includes selected branches/order, schedule/waiting, route geometry, omissions, completed history, provenance and warnings. Saved trips later retain the submitted input/profile/vehicle snapshot alongside this result. |

Strictly reject unknown request fields in v1 to avoid silently ignoring a constraint. Optional/unknown values use the explicit nullable fields in the schema. A future incompatible meaning requires a new contract version; documentation examples are not a claim that a released API already exists.

## Interpretation and scheduling policy

Preserve user-confirmed structured values across title edits and backend validation. Limited phone-side suggestions may map explicit `palengke` to wet market, `gamot/botika/pharmacy` to pharmacy, `bank/bangko` to bank, `gupit/haircut/barber` to haircut, `grocery/groceries` to groceries, and `kain/lunch/food/coffee` to food. These are proposed finite vocabulary cases, not a language model or an implementation in this change. Multiple plausible categories, unsupported phrases or ambiguous references such as “lunch with her after” produce focused clarification. Do not guess a person, branch or dependency. A suggested category needs confirmation before calculation. Timings such as “before 4pm” must not silently choose arrival versus completion semantics.

The versioned policy `pilot-2026-10-27-v1` supplies the following **editable assumptions**, not observed service times:

| Category | Visit estimate | Stop buffer |
| --- | --- | --- |
| Groceries | 20 minutes | 5 minutes |
| Wet market | 30 minutes | 5 minutes |
| Pharmacy | 10 minutes | 5 minutes |
| Bank | 30 minutes | 5 minutes |
| Office | 45 minutes | 5 minutes |
| Food/coffee | 30 minutes | 5 minutes |
| Haircut | 45 minutes | 5 minutes |
| Landmark | 15 minutes | 5 minutes |

Explicit user duration/buffer values take precedence and retain `visit_source: user`; category defaults must match the policy. Visit bounds are 1–28,800 seconds and buffer 0–3,600 seconds. These bounds cap a single-day pilot request, not business facts. A flexible errand with an unknown category needs clarification rather than a hidden duration fallback. A fixed confirmed place with explicit user duration and confirmed timing does not require an inferred category. Keep buffers distinct from road travel and queue/traffic observations.

- `anytime` has no user time constraint. `at` fixes service start and allows waiting after early arrival. `arrive_by` limits arrival. `finish_before` limits completion **including the stop buffer**. Final arrival must meet the day deadline.
- Known or explicitly corrected business intervals must cover service start through departure, including the buffer. Corrections require their source/date. Unknown or stale/unparsed hours remain unknown; retain a qualified candidate only in a `provisional` plan with a `check_hours` notice. Do not claim an unknown-hours business is open.
- Complete every unfinished mandatory errand at exactly one branch. Optional errands have at most one branch and require an explicit omission reason when dropped. Hard feasibility comes first, then maximum optional count, then lower road travel time; stable errand/candidate IDs break remaining ties. Never use an arbitrary penalty that permits dropping mandatory work.
- Prerequisites mean the predecessor is completed before the dependent's service. Reject cycles, duplicate IDs, self/unknown references. Selecting a dependent requires every prerequisite, even an optional one. A mandatory dependent therefore makes its optional ancestor necessary for that accepted plan. If an optional prerequisite is omitted, omit its optional dependents with reasons; never silently erase a dependency. Already completed prerequisites are satisfied by preserved completion history.
- Replan only unfinished work from the supplied current location/time, preserving the exact completed history. Do not revisit a completed errand or let an older result/retry overwrite newer edits or completion state.

## Routing, limits and outcomes

The five product profiles remain walking, biking, motorcycle, sedan and truck. Truck requires `pickup_light` or `heavy_delivery` plus explicit dimensions/weight. Heavy delivery additionally requires axle load/count and hazard status. No user vehicle dimensions are inferred from the profile label. Pickup uses auto costing in the evaluation; heavy delivery uses truck costing. Dimension/axle/access completeness is **not independently certified** by successful route requests. All profiles report `ground_clearance_verified: false`, `restriction_coverage: incomplete` and no live traffic. Unknown vehicle capability must produce `unsupported_profile` or a focused missing-parameter issue rather than silently substituting a different profile.

Preserve asymmetric matrix values and null unreachable legs. Routing cache identity includes ordered coordinates, full profile/subtype/vehicle/engine costing options, graph/source identity and applicable departure/date-time semantics; never reuse a sedan or old-graph matrix for an incompatible request. Missing road estimates cannot be replaced with straight-line time or zero. Surface/overhead restrictions are distinct from ground clearance. Heavy restrictions and motorcycle beta behavior require visible limitations, not safety guarantees.

Initial pilot policy caps each request at 12 errands, three candidates per flexible errand and 38 matrix locations including endpoints. A single calculation has a five-second solver budget inside a 20-second orchestration deadline; timeout preserves the last saved result. These are deliberate resource bounds, **not** demonstrated performance at that size: M5-01 measured only 4x4 matrices. Later implementation must measure the full cap before promising response times and may revise the versioned limits with evidence. Do not expand candidate search unboundedly after no matches.

| Outcome | Meaning / proposed HTTP behavior |
| --- | --- |
| `feasible`, `provisional` | HTTP 200 with an independently validated plan; provisional requires visible data limitations. A time-limited search with a validated solution uses these statuses plus `solver.termination: time_limit_feasible`, never a global-optimality claim. |
| `needs_clarification` | HTTP 200 with actionable missing/ambiguous fields, including unresolved endpoints/categories. |
| `no_candidates`, `no_route`, `unsupported_profile` | HTTP 200 with distinct missing catalog, road-connectivity or capability issues. An outside-pilot destination reports an `unsupported_area` issue; it does not imply nationwide search. |
| `conflict` | HTTP 200 only for an independently established hard constraint conflict; no plan and no silently omitted mandatory work. |
| `invalid_input` | HTTP 422 for schema/reference/date/cycle errors; malformed JSON is HTTP 400. Include safe field issues without logging request bodies. |
| `timeout` | HTTP 504 when no validated feasible result is available before the bound; not proof of infeasibility. |
| `unavailable` | HTTP 503 for absent/disconnected/asleep local backend, unavailable graph or provider failure; retain local edits and saved results with timestamps. |

Every non-success outcome carries issues and a null plan. The client must handle absent/non-JSON network failures as unavailable without needing a valid error body. Domain validation remains independent of solver construction; schema/fixture validation here does not prove route geometry, recommendation quality or schedule optimality.

## Verification and implementation handoff

From the repository root:

```powershell
./.tools/routing-venv/Scripts/python.exe tools/routing/planning_contract.py
./.tools/routing-venv/Scripts/python.exe tools/routing/contract_examples.py
./.tools/routing-venv/Scripts/python.exe -m unittest discover -s tools/routing -p "test_*.py" -v
```

The fixtures cover automatic pharmacy choice with unknown hours, fixed branch override, duration correction, ambiguous text, optional omission/dependency, appointment waiting, missing endpoint, every operational outcome and preserved-history replanning. Negative tests cover stale revisions, mandatory omission, cycles/references, swapped coordinates, same-day/midnight boundaries, truck parameters, known-hour coverage and false timeout/global-optimality claims. They are specifications for later service/mobile implementation; future solver checks still need fixed matrices, tiny exhaustive comparisons and independent road/schedule validation.

## Phone-only planning handoff, 2026-10-30

### Status and responsibilities

The owner requires the presentation to work using the Android phone and internet alone. Personal state stays local; no laptop, USB connection, developer proxy, local FastAPI service, PostGIS catalog or Valhalla server is a runtime prerequisite. Google-first discovery, traffic-aware Google Routes inputs and a Google map for route review remain the selected direction. Embedded Navigation SDK integration remains separate from calculating and reviewing a plan; route/path rerouting does not automatically reorder errands.

This section is the proposed implementation design following those requirements. The existing v1 schema/examples are preserved. Define and test a versioned mobile input/result extension before using shared stops or changing provider retention semantics; do not silently send the new meaning to the old API. No application implementation, native qualification or capacity benchmark is established by this handoff.

### Inputs, interpretation and correction

- Preserve the current title, free-form notes, original text, confirmed structured values and their provenance. Current title/notes guide new suggestions; an older preserved original title must not reinterpret a renamed errand. Explicit timing, branch and duration overrides win over suggestions.
- D45 selects Gemini as the sentence interpreter for English, Filipino and Taglish titles and notes, superseding the earlier vocabulary-only proposal. Produce typed, reviewable suggestions for intent, shopping needs, preferences, times and dependencies. Preserve unknown items and original wording. Confirm proposed extra errands or new dependency rules before applying them, and ask focused questions for ambiguous references. Existing finite aliases can support search; they do not define the intended interpretation limit. A failed Gemini request leaves structured editing available. Model selection and protected integration remain pending.
- Distinguish a fixed specific destination, a flexible need and an unresolved private meeting point. The last case opens the existing search/map-pin picker and requires confirmation. Cancellation retains all entered text. An expired Google reference uses explicit refresh or a new confirmed location.
- Qualify grocery candidates across supermarkets, discount stores, convenience stores and wet markets using the stated items/preferences. A type/brand is not proof of stock or meal availability. Pares needs a suitable paresan or supported meal evidence, not an arbitrary restaurant substitution.
- Retain explicit date/timezone. If the selected day is past or its departure has already passed, ask whether to use another dated departure or plan from the current time. Never silently overwrite the draft date or calculate a journey as if a past departure were still possible.

### Dependency order and local consistency

A shared dependency-order operation validates IDs/references/cycles and produces a stable valid ordering. Preserve existing relative order among otherwise unconstrained errands where possible. Saving a dependency edit must update both numbered rows and persisted positions through one repository transaction. Apply it consistently to Today edits, manual review, Recurring drafts and copied groups. Recurring copies still remap dependency IDs and remain independent.

Use the same validated operation for older inconsistent saved lists, with a brief explanation and Undo after a successful correction. Do not erase missing references or circular constraints to force an order. An attempted manual move that breaks a rule is reconciled visibly or rejected with the reason; no accepted displayed order may contradict its saved dependency graph. Changing order alone does not establish travel-time feasibility. Increment the input revision for meaningful edits, accepted order changes and completion changes; apply network/solver results only to the matching request and revision.

The storage audit found existing editable values wired through saving/loading, but revision increments and complete confirmation provenance need implementation. SavedPlace.intent also needs to preserve category/brand metadata when a saved place is reused. Keep any migration additive and preserve the existing v2 records and Google coordinate-lease rules.

### Candidate discovery and recommendation review

Use an explicit preparing/recommendations surface after Plan my day. Search fixed-route anchors and a bounded nearby area for flexible needs; do not restrict every query to the initial device position. Deduplicate request identities and compare at most three qualified candidates per flexible errand initially. Known explicit branch choices remain fixed. Broadening the area, changing the source or retrying a failed request is explicit, not an automatic fan-out.

The proposed Google path extends the existing standard visible UI Kit search session to pass the documented onLoad ID/coordinate records into a bounded candidate session. Validate Philippine eligibility and acquisition times exactly as for selected references. Preserve original native card order, names/details, notices and attribution; a recommended chosen branch can use a standard native details component. Never scrape card text or treat missing callback hours/name/address as available custom data. Do not create an invisible headless UI Kit catalog. Prove this batch/recommendation flow on Android before depending on it; if insufficient, retain the clarified requirements and assess a separately scoped data-access option instead of replacing recommendations with mandatory manual branch selection.

Keep Google-first and explicit Other sources. Automatic provider failure does not silently change sources. Other-source candidates retain complete source records and existing scheduler/cache policies. Search produces candidates; the scheduler compares branch combinations and order. Users may accept the recommendation as a whole or inspect/change alternatives; each accepted override invalidates affected estimates and triggers a bounded recalculation.

### Shared visits and scheduling

Keep errand identity separate from physical stop identity. A proposed stop contains a selected place reference and one or more assigned errand IDs, an internal task order, service durations/buffers, qualification reasons and confidence/provenance. A grocery and ice-cream task can share one visit when the selected place is suitable, or use two nearby stops. Keep separate checkboxes and completed history. Never treat geographic proximity alone as identical businesses or as proof of item availability.

Within a shared visit, respect dependency and timing rules for each task. Explicit durations remain intact; sum sequential task durations unless the user confirms overlap. Apply one documented stop-level arrival/parking buffer rather than duplicating it merely because two errands share the stop. The original per-errand buffer fixtures do not specify this extension; version and test the policy before implementation. A dependency may require internal task sequencing or separate visits; merging must not defeat it. Fixed incompatible places cannot be merged.

Proposed search uses bounded precedence-aware branch-and-bound in a Dart worker isolate, starting from an early feasible schedule and retaining the best independently validated solution within the time limit. Branch over eligible next errands, candidate places, shared visits and optional omission. Do not prune merely because another branch is closer: preserve asymmetric road times, waiting, known hours and the full duration of the visit. Hard constraints and mandatory completion come first, then optional completion, then lower road travel and fewer distinct visits as a tie-breaker. Unknown business hours require a provisional/check-hours result; uncertain item suitability requires a visible qualification rather than a stock claim.

Use the existing five-second solver budget only as an initial policy pending phone benchmarks. UI responsiveness, cancellation and bounded memory must hold throughout; terminate or discard obsolete worker results. Failure to find a solution before the bound is timeout. Only an independently established contradiction or a completed exact search can support a conflict claim. A valid result found before timeout is a feasible estimate, without global-optimality language.

### Road data, request limits and map presentation

Google Routes adapter inputs include coordinates/references, selected mode, explicit date/departure and applicable options. Preserve per-element errors, unreachable pairs, asymmetric values, fallback metadata and source/calculation time. Do not reuse a car matrix for motorcycle/bicycle/truck or turn provider fallback into unqualified traffic certainty. Qualify the actual selected motorcycle mode and the relevant route/matrix endpoints before using them for the owner's demonstration; prior DRIVE qualification is insufficient. Unsupported profiles need an honest message, never silent conversion to DRIVE.

Budget matrix origin-destination elements rather than counting HTTP starts alone. Shared places can reduce distinct matrix nodes; alternative candidates can expand them. The old maximum of 38 locations would imply 1,444 elements in a naive full square, exceeding an ordinary single matrix request; do not carry that assumption into Google unchanged. Estimate the actual pair budget, batch within provider limits, reserve usage before dispatch, honor the configured account/project allowance and stop safely at exhaustion. Confirm Console capacity separately; this design authorizes no quota edit or billing change. No unbounded retries or paid automatic fallback.

An initial matrix may use a common planning departure approximation. After selecting order/branches, obtain a bounded final route validation accounting for intended leg departure times and visit/waiting durations where the endpoint permits it. Do not request all legs as if they start simultaneously or claim that a multi-waypoint route includes Wayday's visit time. Revalidate the schedule and surface changes; cap refinement passes and preserve the last accepted plan on failure.

Render Google Routes content on a Google map with attribution. Navigation SDK supplies map functionality; verify plugin/native dependency compatibility with the current Places bridge before choosing an integration. Existing MapLibre/manual/offline experiences remain separate. Reviewing a map must not start guidance or consume navigation destinations automatically.

### Persistence, failures and verification

Separate editable day input, calculation draft and accepted plan. Save task-owned inputs, accepted branch references, stop-to-errand assignments, revision, provenance and completion state transactionally. Review provider-specific permission for computed schedule values and route geometry before choosing persistent fields. The 30-day coordinate exception does not authorize indefinite route-content storage. Retain user-owned labels and permitted IDs durably; use existing expiring Google coordinate leases and permitted transient response state. No blanket offline Google maps/navigation promise.

Distinguish clarification, unavailable candidates, unavailable road data, unsupported mode, invalid dependencies, independently proven conflict and timeout. Every failure preserves local inputs and the last permitted saved result. Do not invent a business, stock item, opening interval or road estimate to complete the example.

Implementation verification must cover independent schedule checking against fixed asymmetric matrices and exhaustive tiny cases; compatible/incompatible shared visits and durations; missing/private places; current-title versus old-original-text handling; notes with known and unknown items; dependency edits/copies/Undo/restart; stale callbacks and revision changes; optional ancestors and omissions; hours/waiting/deadlines; provider limits/unreachable legs/fallbacks; expired references and storage migration. Measure four-, eight- and twelve-errand workloads on the physical Android device before enabling the corresponding limit.

The decisive presentation check is a standalone APK on the phone with USB/ADB forwarding and development services unnecessary: create/edit errands, calculate real bounded recommendations and a validated schedule over mobile data or ordinary Wi-Fi, change a recommendation, restart, and recover permitted saved state. Repeat with internet disabled to confirm honest failure and retained local inputs. Run Flutter analysis, focused/full tests and an Android build, recording existing failures separately. Native candidate/mode/map/retention qualifications remain gates inside implementation, not capabilities established by this document.
