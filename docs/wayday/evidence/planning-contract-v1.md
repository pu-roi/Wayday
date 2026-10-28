# Wayday pilot planning contract v1

M5-02 specification, 2026-10-27. This contract follows the measured [routing gate](routing-pilot-2026-10-27.md). It defines future mobile/domain/API behavior; it does not implement FastAPI, recommendation, a solver or mobile planning. The [JSON Schema](planning-contract-v1.schema.json) and [14 synthetic acceptance examples](planning-contract-v1.examples.json) are executable specifications. Their businesses, times and geometry are fixtures, not real planning results.

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
