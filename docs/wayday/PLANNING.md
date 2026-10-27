# Wayday planning and task board

Updated: 2026-10-27 (Asia/Manila).

This is the single implementation-planning document: execution order and checkpoints own milestone outcomes, the table owns live status and assignment, and task specifications own dependencies, inputs, expected results, acceptance criteria, and checks. [Progress](PROGRESS.md) records completion evidence; [README product requirements](../../README.md#product-requirements) define product behavior. Do not create a separate roadmap, plan, or duplicate live checklist.

Stage 1, M2-01 through M2-04, is complete and verified using team agents. Stage 2 coverage, regional package preparation, qualified local routing feasibility and the planning contract are complete. Android renderer verification, M3-03, remains in progress; the other Stage 2 results do not imply it has passed. Stages 3–5 remain pending. Preserve existing saved rows and completed M1-01 evidence.

## Release goal and confirmed decisions

- Cleanup comes first: remove production samples, reset-example actions, invented destinations, and stale preview copy. Replace each functional placeholder through its assigned feature task; keep honest unavailable states until that feature works.
- The first usable release includes automatic store recommendations, branch selection, stop ordering, and estimated scheduling. Users supply errands and necessary constraints, then review or correct the result. A manual-only trip is an internal checkpoint or optional override, not the release goal.
- Use editable, clearly labeled visit-duration estimates. A missing-hours store can appear in a provisional plan with a visible check-hours notice; known closures still constrain scheduling.
- Keep five travel choices. The high-clearance category includes pickups/light trucks and heavy delivery vehicles, with subtype and needed vehicle parameters distinguished before applying restrictions. Ground clearance, vehicle height, weight, and road access have different meanings.
- Use MapLibre, Protomaps regional PMTiles, a custom Wayday style, and a separately searchable OSM catalog. Overture is optional after coverage/provenance/license validation. Start with measured Pasig/Ortigas coverage; no nationwide completeness claim exists.
- Keep personal errands, saved places, itineraries, and progress local in Drift/SQLite. Public map/catalog refresh is separate from personal-data synchronization. Automatic calculation initially uses a backend running on the existing computer during development/demos.
- Users explicitly open Google Maps after plan review. Next-stop navigation is primary; whole-trip handoff respects target limits. Returning does not automatically complete an errand.
- Retain the fixed light Cornflower application UI. Map-style choices apply to the map. Repeat metadata does not automatically schedule lists.
- AI, public-commute planning, automatic recurrence, live traffic, reminder integration, public deployment, accounts/sync/analytics, iOS, and in-app turn-by-turn navigation remain outside this release plan.

## Current baseline

Today and Recurring editing, notes, timing/repeat metadata, independent manual copies, the shared UI, and Android Drift/SQLite storage are implemented. M1-01 records force-stop/relaunch on the API 37 x86_64 emulator on 2026-10-27, analyzer/tests, and debug builds. Stage 1 is implemented and verified: production examples/reset actions are removed, new state starts with empty lists and unset endpoints, and shared timing/repeat/weekday/monthly-day controls are in use. M2-04 records the 48-test suite, clean analyzer, ARM64/x86_64 debug APK, and API 37 emulator upgrade/restart evidence. Maps remain illustrative. Browser preview storage remains in memory. A planned feature below is not evidence of runtime implementation or physical-device verification.

The owner requested a source audit before further changes. The read-only audit on 2026-10-27 confirmed the following integration boundaries; analyzer and all 48 existing tests passed again during that audit.

| Existing implementation to reuse | Missing capability and owning task |
| --- | --- |
| One shared `choosePlace` / `PlacePicker` screen, used by Today endpoints and the shared errand editor | Geographic rendering in M3-03; coordinate persistence in M3-04; confirmed pin selection in M3-05; catalog search in M3-06/M3-07 |
| `Errand`, `DayPlan`, Today/Recurring controllers and repository interfaces | Place identity/provenance in M3-04; planning input/result contract in M5-02; separate saved-trip state in M4-01 |
| Four-table Drift schema v1, serialized transactional saves, native provider injection and memory preview repositories | Data-preserving schema extensions through the existing database; no parallel personal-data store |
| Shared errand rows/composer/editor, selection and time sheets, feedback, motion and Cornflower theme | Feature-specific map/search/review controls; preserve existing draft, focus, cancellation and copy behavior |
| Plan my day action with an unavailable-feature explanation | Planning services in M5-03 through M5-05 and mobile review/replanning in M5-06 |

`DayPlan` currently stores editable input, not a computed itinerary. Existing place values are labels without coordinates. The map is a custom-painted illustration, and the search icon does not query a catalog. No map, location, network-client or external-navigation integration dependency, backend implementation, saved-trip model or completion state exists. Keep new catalog, routing and solver logic out of Today and picker widgets.

The audit also found that optimistic controller saves report failures only to the debug log. Transaction rollback protects stored rows, but the UI has no save-failure or retry state. Address that bounded gap as part of M4-01 before claiming reliable saved-trip persistence; it does not require rewriting the current editing architecture before map feasibility.

## Execution order and checkpoints

The owner selected five combined stages on 2026-10-27. IDs remain stable for existing milestone references; dependencies, rather than numeric sorting, determine build order. Map rendering and routing feasibility run early because both are prerequisites for the intended release. These stages group checkpoints; implementation still proceeds through focused, verifiable tasks with their existing acceptance criteria.

| Stage | Tasks | Exit condition |
| --- | --- | --- |
| 1. Clean and stabilize input | M2-01, M2-02, M2-03, M2-04 | User-created data, predictable editing, and restart checks pass |
| 2. Resolve feasibility and contract gates | M3-01, M3-02, M3-03, M5-01, M5-02 | Pilot POI coverage, licensed regional package, Android map rendering, road/vehicle support, and input/result contract are verified or documented as required by their tasks |
| 3. Build maps, places, and saved-trip foundations | M3-04 through M3-09, M4-01 | Confirmed places, searchable regional catalog, map selection/styles, offline update/recovery, and saved-trip restore checks pass; synthetic plans remain test fixtures |
| 4. Deliver automatic planning | M5-03, M5-04, M5-05, M5-06 | Real alternatives and matrices produce independently validated branch/order/time results, review, corrections, and remaining-trip replanning in the app |
| 5. Complete navigation and release evaluation | M4-02, M4-03, M5-07 | Google Maps handoff and integrated Android checks pass before pilot evaluation demonstrates the automatic-planning release criteria and records actual limitations |

Use the following dependency paths within the combined stages:

- **Stage 1:** M2-01 and M2-02 can proceed independently; M2-03 follows M2-02. M2-04 verifies both completed paths before feasibility work begins.
- **Stage 2:** Complete M3-01 first. Then the map package/rendering path (M3-02 -> M3-03) can overlap the routing/contract path (M5-01 -> M5-02). Finish each feasibility gate before its dependent implementation.
- **Stage 3:** Complete M3-04 before map selection (M3-05), catalog import (M3-06), or trip storage (M4-01). M4-01 also requires M5-02. Integrate M3-05 and M3-06 in M3-07, then complete M3-08 and M3-09. Serialize shared Drift schema changes and migrations even when the surrounding UI or catalog work overlaps.
- **Stage 4:** M5-03 can begin after M5-02; M5-04 can begin after M5-02 and M3-06. These independent paths can overlap remaining Stage 3 work without waiting for its full checkpoint. M5-05 requires both; M5-06 additionally requires M4-01 and M3-07.
- **Stage 5:** Complete M4-02 after M5-06. Run M4-03 only after M4-02 and M3-09; run M5-07 only after M4-03. Grouping navigation and evaluation does not make either checkpoint optional.

When using multiple contributors or agents, agree on shared interfaces first and give each implementation slice a distinct owner and bounded responsibility. Sequence edits to shared contracts, repositories, schemas, and migrations. Run focused checks for each slice and retain every existing Android, offline, integration, and pilot acceptance checkpoint. Combining stages reduces handoffs and permits independent work to overlap; elapsed-time savings depend on available contributors and feasibility results.

If a feasibility gate fails, record the measurements and revise the affected architecture or supported scope before dependent implementation. Do not silently label a map-only or manual-only result as the requested release.

## Stage 2 execution brief

This brief makes the next execution concrete without starting runtime work. Preserve the five stages and task IDs above. The first executable task remains M3-01; the source audit does not satisfy its real-data acceptance criteria.

1. **M3-01: establish the pilot evidence.** Select 35 public destinations independently of OSM availability: five each for groceries/wet markets, pharmacies, banks, offices, food, haircuts and landmarks, with three groceries and two wet markets in the combined grocery category. Record the sample and exact Pasig/Ortigas study bounds before comparing source records. Review exact branches, positions, duplicate/missing records, business-status signals and hours. Keep unavailable evidence unknown. Publish stable sample IDs, independent dated references, expected branch/address, source matches/IDs and the evidence behind each assessment. Record extraction bounds/filter, tool versions, snapshot/retrieval dates and raw-extract checksums with the reproducible recipe. Evaluate Overture against the same sample only where OSM gaps justify supplementation; record an explicit include/defer decision. Finish with supported region/categories and limitations or a required revision; sample match rates are not population completeness estimates.
2. **M3-02 then M3-03: prepare and display the real map.** Prepare the licensed regional tiles and all style/font/sprite resources, measure their storage requirements, and validate a pinned Flutter/native renderer on Android. Replace the existing picker's illustrative surface through one shared map component, retaining its page layout and all current callers. During renderer feasibility, keep `choosePlace` returning a manual label and label that behavior accurately; render public geographic markers only as verification data, without attaching invented coordinates to user labels. Saving a selected pin belongs to M3-05.
3. **M5-01 then M5-02: validate roads and define the planner contract.** After M3-01, this path may run alongside the map path. Measure a bounded local road-engine setup against public journeys and transport/vehicle restrictions, then define versioned inputs/results from demonstrated support. Distinguish the supported pilot boundary from any surrounding-road buffer needed for the graph; investigate clipping before calling a sampled journey unreachable. Complete the named duration/buffer, date/timezone, dependency, candidate/solve-limit and error-state decisions before dependent planner code. Evaluation tooling is separate from the production API; service implementation remains M5-03.
4. **Integrate and review the checkpoint.** Verify the renderer through existing From/To and errand entry points, online and after an offline cold start. Preserve manual-label editing, draft cancellation, list persistence and independent Recurring copies. Record measurements, unsupported capabilities and emulator versus physical-device evidence; complete each task only against its own acceptance criteria.
5. **Hand off to Stage 3 through the existing boundaries.** M3-04 adds confirmed-place values and one data-preserving migration. M3-05 then changes the shared picker result once and connects pin confirmation to the current endpoint/editor drafts. M3-06/M3-07 add the separate catalog and search. M4-01 adds saved computed trips after M3-04 and M5-02. Keep the current editable day model separate from computed plans, progress and stale-result state.

### Team ownership and integration rules

| Owner | Bounded responsibility | Shared-file rule |
| --- | --- | --- |
| Data agent | M3-01 extraction/matching evidence, then M3-02 public map-package preparation | Own assigned data tooling/evidence only; return findings to the lead for maintained documentation |
| Map/mobile agent | M3-03 shared map component, existing picker integration and focused Android/widget checks | Own assigned map/picker/tests; lead serializes dependency and Android configuration edits |
| Routing/planning agent | M5-01 road-engine evaluation, then M5-02 contract proposal and synthetic acceptance examples | Own separate evaluation/contract artifacts; no edits to the shared personal database or map UI |
| Lead agent | Source baseline, prerequisites, shared interfaces/configuration, documentation, tracking and combined checks | Sole editor of shared maintained documents, dependency files and schema changes unless explicitly reassigned |
| Review agent | Inspect each combined checkpoint for regressions, evidence and data preservation | Read-only review after integration; lead applies fixes or reassigns bounded files |

Use at most two workers alongside the lead, consistent with the available team slots; bring in the reviewer after a worker finishes. After M3-01, the data agent completes M3-02 before handing the map path to the map/mobile agent, while the routing/planning agent owns the other path. Assign exclusive file ownership before each slice; creating parallel agents does not permit concurrent edits to contracts, dependencies, schemas or maintained documents.

Keep raw geographic downloads, generated packages/graphs, database files and native captures in existing ignored data/review locations. Track only lawful bounded audit evidence, small synthetic fixtures, authored tooling, configuration examples and preparation recipes. Recheck official package/provider documentation and licenses when adopting actual versions; no package version or regional size is claimed verified by this planning update.

**Stage 2 exit evidence:** reproducible pilot coverage and source decision; complete regional package and measured size; real Android rendering/pan/zoom/labels/markers/attribution and offline cold start; measured road/vehicle support and limits; reviewed planning input/result contract. Run the mobile README's analyzer, full tests and debug build for renderer integration, including existing editing/persistence regressions. Check Back, keyboard/insets, large text, reduced motion and attribution through the existing picker; renderer feasibility must not require a location permission prompt. Missing/corrupt packages must show an honest unavailable state without modifying personal data. A failed gate keeps dependent tasks pending until the affected choice is revised and verified.

## Status legend

- `[ ] TODO`: planned, not implemented.
- `[-] IN_PROGRESS`: actively being worked on.
- `[x] DONE`: acceptance criteria verified and evidence recorded in Progress.

## Tasks

| Task ID | Component | Task Description | Status | Assignee | Completed Date |
| :--- | :--- | :--- | :--- | :--- | :--- |
| M1-01 | Mobile · local data | Persist Today and Recurring data in SQLite while preserving first-launch examples and verify data survives an Android app restart. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| DOC-01 | Documentation | Audit document ownership and record the selected mapping direction and implementation plan. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| DOC-02 | Documentation | Consolidate the detailed plan into PLANNING.md and record the clarified automatic-planning release requirements. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| DOC-03 | Documentation | Move root project documentation into docs, consolidate the redundant product pointer, and repair references and task tracking. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| DOC-04 | Documentation | Consolidate current project documentation in docs/wayday and merge redundant product, roadmap, and development files into their remaining authorities. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| DOC-05 | Skills · documentation | Audit all project skills against the consolidated documentation and update affected references, design guidance, and implementation boundaries before pushing. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| DOC-06 | Documentation · execution plan | Consolidate seven execution stages into five with explicit dependency paths, safe overlap, and preserved verification gates. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| DOC-07 | Documentation · entry point | Move the canonical README to the repository root and repair documentation rules, links, and skill references. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| DOC-08 | Documentation · implementation readiness | Ground Stage 2 execution and integration boundaries in the source audit, with team ownership and verification gates. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| M2-01 | Mobile · real data | Start with user-created data. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| M2-02 | UI · shared design | Define shared selection patterns. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| M2-03 | UI · selectors | Replace unpredictable form dropdowns. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| M2-04 | Android · checkpoint | Verify the empty-state editing workflow. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| M3-01 | Data · feasibility | Audit pilot place coverage. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| M5-01 | Routing · feasibility gate | Validate regional routing and vehicle support early. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| M5-02 | Planning · input contract | Define automatic-planning inputs and outcomes. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| M3-02 | Maps · data packages | Prepare a licensed regional map package. | [x] DONE | Roi Cambe (@pu-roi) | 2026-10-27 |
| M3-03 | Maps · Android feasibility | Render the regional map on Android. | [-] IN_PROGRESS | Roi Cambe (@pu-roi) |  |
| M3-04 | Local data · places | Persist confirmed place coordinates. | [ ] TODO |  |  |
| M3-05 | Places · manual selection | Save a place chosen on the map. | [ ] TODO |  |  |
| M3-06 | Places · local catalog | Import a searchable regional POI catalog. | [ ] TODO |  |  |
| M3-07 | Places · search UI | Choose real stores and landmarks. | [ ] TODO |  |  |
| M3-08 | Maps · design | Apply Wayday styles and POI priorities. | [ ] TODO |  |  |
| M3-09 | Maps · offline checkpoint | Verify package updates and offline recovery. | [ ] TODO |  |  |
| M4-01 | Trips · local storage | Persist and restore a planned trip. | [ ] TODO |  |  |
| M5-03 | Routing · service | Expose validated regional travel matrices. | [ ] TODO |  |  |
| M5-04 | Planning · recommendations | Recommend suitable stores and branch alternatives. | [ ] TODO |  |  |
| M5-05 | Planning · solver | Choose branches and produce validated schedules. | [ ] TODO |  |  |
| M5-06 | Planning · mobile | Review automatic plans and replan remaining stops. | [ ] TODO |  |  |
| M4-02 | Trips · navigation | Open Google Maps from an automatically planned trip. | [ ] TODO |  |  |
| M4-03 | Android · integration checkpoint | Verify the complete automatic-plan handoff workflow. | [ ] TODO |  |  |
| M5-07 | Planning · release checkpoint | Evaluate the automatic-planning first release. | [ ] TODO |  |  |

## Tracking and verification rules

Use the existing task tracker from the repository root:

```powershell
py .agents/skills/wayday-task-tracker/scripts/track_task.py list
py .agents/skills/wayday-task-tracker/scripts/track_task.py start M2-01
py .agents/skills/wayday-task-tracker/scripts/track_task.py done M2-01 --notes "Acceptance and verification evidence"
```

Record task statuses only in the table above. Preserve completed task history; M2-01 changes future example seeding without undoing M1-01's data-persistence work. The unstarted M5 tasks have been split/reworded so candidate recommendation and scheduling are separate implementation tasks.

For runtime milestones, use the analyze, test, Android run, and debug-build commands in [the mobile README](../../apps/mobile/README.md). Run focused behavior checks during small slices and full checks at milestone checkpoints. Exercise migrations with synthetic/authorized disposable data, then Android restart and offline scenarios. Avoid routine tests against community endpoints. Record physical-device versus emulator coverage honestly.

For documentation-only changes, verify local links/anchors, task dependencies, current-versus-planned claims, tracker totals, and ignore rules. Documentation-only work does not imply runtime implementation or an app test run.

Keep downloaded map data, generated catalogs/graphs/packages, private coordinates, databases, signing credentials, and local configuration out of Git. Recheck package/native notices and provider policies at adoption time. Free software still consumes storage, compute, electricity, and bandwidth; measure before promising service or distribution budgets.

## Task specifications

Every runtime task below includes prerequisites, inputs, expected result, acceptance criteria, verification, and likely affected areas. Keep user-facing uncertainty separate from failures that block a valid calculation.

### M2-01: Start with user-created data

Remove sample seeding, example-reset actions, and fabricated endpoint defaults from Android and the browser preview.

**Dependencies:** M1-01. **Estimated scope:** M; normally 3–5 authored files per session. Split further if source inspection reveals a larger independent change.

**Inputs:** Existing schema-v1 personal data, fresh database startup, browser defaults, and explicit test fixtures.

**Expected result:** Empty new user state and editable unset endpoints; existing saved rows and undo/copy behavior retained.

**Acceptance criteria:**

- New installs start with empty Today and Recurring lists and unset endpoints; useful empty states lead to creating real errands.
- Keep all existing database rows, including edited examples; do not guess which rows are safe to delete. Preserve clear/undo and independent recurring copies.
- Examples live only in explicitly supplied test fixtures; intentionally empty lists stay empty after restart.

**Verification:** Repository/widget regression cases plus Android restart; update stale preview copy.

**Likely areas:** features/today/, features/recurring/, core/data/local_repositories.dart, app/settings_view.dart, affected tests.

### M2-02: Define shared selection patterns

Extend the current Material 3 theme and shared components with the patterns needed by the upcoming forms.

**Dependencies:** M1-01. **Estimated scope:** M; normally 3–5 authored files per session. Split further if source inspection reveals a larger independent change.

**Inputs:** Current Material 3 tokens, repeated selection needs, accessibility requirements, and editor draft behavior.

**Expected result:** Documented shared controls and a tested single-choice sheet using the existing theme.

**Acceptance criteria:**

- Document shared spacing, selection states, labels, touch targets, and keyboard/focus behavior in DESIGN.md; reuse the existing Cornflower theme.
- Provide a reusable single-choice sheet with a visible title, current selection, cancellation, and focus restoration; preserve editor drafts.
- Show a small component preview using synthetic values; no broad third-party UI kit is required.

**Verification:** Widget checks for selection, dismissal, focus, and large text; Android visual inspection.

**Likely areas:** app/theme.dart, core/widgets/, DESIGN.md, component tests.

### M2-03: Replace unpredictable form dropdowns

Use controls appropriate to each choice set instead of the legacy selected-item-aligned dropdowns.

**Dependencies:** M2-02. **Estimated scope:** M; normally 3–5 authored files per session. Split further if source inspection reveals a larger independent change.

**Inputs:** Draft timing/repeat/day values and the shared selection patterns.

**Expected result:** Predictable choices committed only through existing save behavior, with valid monthly day input.

**Acceptance criteria:**

- Timing and repeat frequency use labeled radio rows; weekday uses the shared selection sheet; monthly day uses validated numeric entry from 1 to 31.
- Keep timing meanings, optional status, draft save/cancel, and repeat-as-metadata semantics intact.
- Repeated opening, scrolling, keyboard changes, and large text do not move a floating choice menu between opposite sides of its field.

**Verification:** Focused widget cases and Android walkthrough of Today and Recurring editors.

**Likely areas:** features/errands/presentation/errand_editor.dart, features/recurring/presentation/group_editor.dart, tests.

### M2-04: Verify the empty-state editing workflow

Verify the complete user-created Today and Recurring flow before adding map dependencies.

**Dependencies:** M2-01, M2-03. **Estimated scope:** S; normally 3–5 authored files per session. Split further if source inspection reveals a larger independent change.

**Inputs:** The cleaned Today/Recurring workflow and its persistence/selection changes.

**Expected result:** Android editing/restart evidence and a list of actual remaining limitations.

**Acceptance criteria:**

- Create, edit, copy, remove, clear, and undo errands with no runtime example-loading path.
- Edits, order, notes, timing, and repeat metadata survive force-stop/relaunch; cleared data stays empty.
- Record analyzer, tests, debug build, emulator evidence, and any physical-device limitations.

**Verification:** Run the mobile checks in apps/mobile/README.md and the stated Android restart scenario.

**Likely areas:** apps/mobile/README.md, docs/wayday/PROGRESS.md, small focused fixes if needed.

### M3-01: Audit pilot place coverage

Measure whether open place data supports real errands in Pasig/Ortigas before promising broader coverage.

**Dependencies:** M2-04. **Estimated scope:** M; normally 3–5 authored files per session. Split further if source inspection reveals a larger independent change.

**Inputs:** The bounded Pasig/Ortigas region, public destination sample, OSM records, and optional Overture records.

**Expected result:** Reproducible coverage/provenance findings that determine supported categories, region, and supplemental-source inclusion.

**Acceptance criteria:**

- Compare OSM and optional Overture records against a documented sample of at least 30 public destinations across groceries/wet markets, pharmacies, banks, offices, food, haircuts, and landmarks.
- Use the 35-destination stratified sample in the Stage 2 execution brief; select it independently of source matches and record the exact study bounds before extraction. Retain unmatched and ambiguous sample entries in reported denominators. Record a repeatable matching method and the evidence supporting branch/pin judgments rather than treating source presence as proof of accuracy.
- Record source/license/date, branch accuracy, pin accuracy, duplicates, missing names, closed-business signals, and hours availability; use permission-compatible references and no personal addresses.
- Publish measured findings and supported boundaries; record an explicit decision if coverage requires a different region, source, or narrower feature claim.

**Verification:** Manually review the sample and reproduce the bounded extraction; publish results rather than invented completeness percentages.

**Likely areas:** docs/wayday/STACK.md, docs/wayday/DECISIONS.md, future data-tool documentation and synthetic fixtures.

### M5-01: Validate regional routing and vehicle support early

Evaluate a bounded regional Valhalla setup before extensive planner integration. This gate runs early because automatic planning is required for the first usable release.

**Dependencies:** M2-04, M3-01. **Estimated scope:** M; split any independent change that exceeds one focused implementation session.

**Inputs:** A bounded pilot road extract, existing hardware, sampled public journeys, and representative transport/vehicle definitions.

**Expected result:** A measured routing support matrix, graph/update resource budget, and explicit limitations or a recorded architecture revision.

**Acceptance criteria:**

- Measure build/runtime memory, disk, supported journeys, disconnected pairs, and restrictions for walking, biking, motorcycle, and sedan on actual pilot data.
- The high-clearance category includes pickup/light trucks and heavy delivery vehicles. Distinguish subtype and needed dimensions/weight/access parameters; ground clearance is separate from overall vehicle height and never grants road access.
- Verify engine/data support before enabling a capability. A failed gate requires revising the plan; it does not make a manual-only app meet the automatic-planning release goal.

**Verification:** Recorded engine versions, hardware measurements, and sampled road/access comparisons. Keep clear unsupported cases and avoid private-address evidence.

**Likely areas:** Future routing evaluation tooling, stack/architecture decisions, and synthetic restriction fixtures.

### M5-02: Define automatic-planning inputs and outcomes

Specify the mobile/domain/API contract for user-supplied information and system-generated planning before implementing the calculation.

**Dependencies:** M5-01. **Estimated scope:** M; split any independent change that exceeds one focused implementation session.

**Inputs:** Original errand text, limited category rules, optional fixed locations, date/timezone, endpoints, transport/vehicle information, deadlines, priorities, and visit-duration edits.

**Expected result:** Versioned domain and wire contracts with synthetic examples and explicit handling of missing information.

**Acceptance criteria:**

- Preserve original text and confirmed user values. Infer supported English/Filipino/Taglish categories through limited rules; ask only for missing/ambiguous information, not for the user to build the whole itinerary.
- Define editable, clearly labeled category-based visit estimates and precedence for user changes; document the actual default-duration/buffer table before solver code. Do not present defaults as measured business service times.
- Define flexible versus fixed destinations, unknown-hours provisional outcomes, single-day/overnight behavior, dependencies, input revisions, candidate/solve limits, and distinct missing/conflict/timeout/outage states. Ordinary fresh plans initially use the local development backend.

**Verification:** Review examples against product acceptance cases, including automatic pharmacy choice, explicit branch override, duration edit, unclear errand, and missing business hours.

**Likely areas:** Future planning models, API contract documentation, mobile input model, and domain fixture specifications.

### M3-02: Prepare a licensed regional map package

Produce a bounded Protomaps PMTiles package with the resources needed for Android rendering.

**Dependencies:** M3-01. **Estimated scope:** M; normally 3–5 authored files per session. Split further if source inspection reveals a larger independent change.

**Inputs:** Validated region bounds, selected tile schema, source notices, fonts/glyphs, sprites, and map style.

**Expected result:** A versioned/checksummed regional package, repeatable preparation recipe, and measured size/resource budget.

**Acceptance criteria:**

- Package tiles, an initial Wayday-compatible style, required fonts/glyphs, sprites, notices, and visible-attribution text; retain source dates, region bounds, and checksums.
- Measure package size and build resources on existing hardware; establish the supported region and storage budget from those measurements.
- Keep downloaded/generated files under ignored data directories; record a repeatable build or extraction recipe without adding paid services.

**Verification:** Inspect package manifest, resource completeness, attribution, and repeatable extraction on the existing computer.

**Likely areas:** Future package tooling, docs/wayday/STACK.md, docs/wayday/CONTRIBUTING.md.

### M3-03: Render the regional map on Android

Validate the selected MapLibre Flutter binding with the actual project toolchain before building the place workflow.

**Dependencies:** M3-02. **Estimated scope:** M; normally 3–5 authored files per session. Split further if source inspection reveals a larger independent change.

**Inputs:** The current Flutter/Android toolchain and complete regional map package.

**Expected result:** Verified native map rendering and offline cold-start evidence, or a recorded renderer/package revision.

**Acceptance criteria:**

- Render the regional package with working pan/zoom, labels, markers, and unobscured attribution; identify the exact pinned plugin and native requirements.
- Reuse the existing shared picker and allocated map area. Keep manual-label confirmation and editor cancellation intact at this gate; do not persist marker coordinates until M3-04/M3-05 supply the confirmed-place contract and migration. Keep downloaded-package/native failures isolated from personal data and preserve a readable browser fallback when native rendering is unsupported there.
- Verify an offline cold start with bundled or installed tiles, fonts, and sprites; a remote PMTiles URL alone is not an offline map.
- Record startup/rendering behavior, storage use, failure behavior, and supported-platform limitations; revisit the choice if this gate fails.

**Verification:** Android debug build and emulator/device smoke checks online and in airplane mode.

**Likely areas:** pubspec.yaml/lock, Android configuration, future map adapter, feasibility evidence.

### M3-04: Persist confirmed place coordinates

Add a provider-independent confirmed-place value to endpoints and errands through repositories and a data-preserving schema upgrade.

**Dependencies:** M3-03. **Estimated scope:** M; normally 3–5 authored files per session. Split further if source inspection reveals a larger independent change.

**Inputs:** Existing stored labels and an explicitly confirmed place value with source identity/coordinates.

**Expected result:** A data-preserving migration and repository contract that retain unresolved legacy labels and independent copies.

**Acceptance criteria:**

- Store label, latitude/longitude, optional address, source identity, and source date; distinguish unresolved labels from confirmed coordinates.
- Migrate existing schema-v1 rows without inventing coordinates; existing notes, timing, order, and source-copy IDs remain intact.
- Recurring copies carry independent confirmed-place values; invalid or swapped coordinates are rejected by the application contract.

**Verification:** Migration/round-trip cases from real prior schema fixtures and repository copy-independence cases.

**Likely areas:** core/data/, today/errand models and repositories, local repository tests; generated schema output as needed.

### M3-05: Save a place chosen on the map

Replace the illustrative place picker with real map pin selection for From, To, and errand locations.

**Dependencies:** M3-04. **Estimated scope:** M; normally 3–5 authored files per session. Split further if source inspection reveals a larger independent change.

**Inputs:** A From/To or errand draft and current confirmed/unresolved place.

**Expected result:** A saved confirmed coordinate/label or cancellation that leaves the previous draft intact.

**Acceptance criteria:**

- Move/select a pin, enter or confirm a label, and save coordinates through the shared place contract; cancellation preserves the original draft.
- Work from the supported regional package without requiring location permission; show a readable fallback when map coverage is unavailable.
- Reload selected places after app restart and preserve endpoint/errand edit behavior.

**Verification:** Widget/domain cases and Android pin-selection, cancellation, restart, and offline walkthrough.

**Likely areas:** core/widgets/place_picker.dart or future places feature, map adapter, affected editor tests.

### M3-06: Import a searchable regional POI catalog

Build an indexed regional catalog distinct from the visual basemap and personal task data.

**Dependencies:** M3-01, M3-04. **Estimated scope:** M; normally 3–5 authored files per session. Split further if source inspection reveals a larger independent change.

**Inputs:** Bounded licensed public POIs, source dates/identities, category normalization, and separate personal places.

**Expected result:** An indexed, idempotently imported regional catalog usable for recommendation and optional manual search.

**Acceptance criteria:**

- Import bounded OSM POIs with stable source IDs, categories, names/aliases, coordinates, available addresses/hours, and snapshot metadata.
- Search by text/category/area locally with bounded results and correct coordinate/distance units; rerunning an import does not duplicate records.
- Keep public catalog refreshes separate from personal pins and corrections. Add Overture only if the coverage audit justifies it, retaining source licenses and duplicate-resolution evidence.

**Verification:** Synthetic import/idempotency/search cases and measured pilot query time and package size.

**Likely areas:** Future catalog tooling, places repository/index, catalog fixtures and documentation.

### M3-07: Choose real stores and landmarks

Connect the search field, result list, and map to the same catalog queries.

**Dependencies:** M3-05, M3-06. **Estimated scope:** M; normally 3–5 authored files per session. Split further if source inspection reveals a larger independent change.

**Inputs:** Catalog text/category queries and the draft place or branch override.

**Expected result:** Synchronized map/list results and an explicitly chosen override; this is not a prerequisite for automatic store recommendations.

**Acceptance criteria:**

- Search by name/branch/category and inspect name, available address, source freshness, and pin before adding a confirmed place.
- Keep map and list selection synchronized; show explicit no-results, unsupported-area, loading/error, and manual-pin paths.
- Support local terms from the coverage audit; unknown opening hours stay unknown and straight-line distances are labeled appropriately.

**Verification:** Widget cases for selection/cancellation/no results plus Android searches against the pilot sample.

**Likely areas:** Future places search view/controller/repository and editor integration tests.

### M3-08: Apply Wayday styles and POI priorities

Refine the vector map for errand planning and expose a small, purposeful style selection.

**Dependencies:** M3-03, M3-07. **Estimated scope:** M; normally 3–5 authored files per session. Split further if source inspection reveals a larger independent change.

**Inputs:** The same filtered candidates used by search/recommendation, selected errand stops, and compatible vector styles.

**Expected result:** Readable map styles and POI priorities without hiding chosen stops or changing the core itinerary.

**Acceptance criteria:**

- Provide readable street/city/landmark labels and category icons with two evaluated map styles; app chrome remains the fixed light Cornflower theme.
- Keep selected errand stops prominent; category filtering, spatial clustering of candidate results, and zoom-dependent labels use the same filtered place set.
- Persist the map-style preference locally; required attribution remains visible with sheets, keyboards, large text, and system insets.

**Verification:** Android visual/accessibility review of dense and sparse areas and style changes; verify selected stops remain identifiable.

**Likely areas:** Map style assets, shared map controls, local preference repository, DESIGN.md, affected tests.

### M3-09: Verify package updates and offline recovery

Verify map/catalog availability and safe replacement of public data packages.

**Dependencies:** M3-05, M3-07, M3-08. **Estimated scope:** M; normally 3–5 authored files per session. Split further if source inspection reveals a larger independent change.

**Inputs:** Installed map/catalog manifests, last valid packages, available storage, and interrupted/corrupt updates.

**Expected result:** Verified offline readiness and safe public-package replacement without modifying personal errands or corrections.

**Acceptance criteria:**

- A cold offline restart restores selected places, local search, and complete downloaded/bundled map coverage within the supported region.
- Interrupted, corrupt, incompatible, or storage-exhausting updates preserve the last valid package and never overwrite user errands or personal places.
- Expose region, source date, and readiness accurately; outside coverage has a clear fallback and is not advertised as available offline.

**Verification:** Failure injection with disposable packages plus Android airplane-mode, restart, and storage scenarios.

**Likely areas:** Future package installer/manifest repository, integration checks, mobile README and evidence.

### M4-01: Persist and restore a planned trip

Build the local trip repository and review model used by automatic planning. Synthetic plans are test fixtures until the planner is connected; this task does not establish a release-ready manual planning product.

**Dependencies:** M3-04, M5-02. **Estimated scope:** M; split any independent change that exceeds one focused implementation session.

**Inputs:** A reviewed plan snapshot with selected branches, stop order, coordinates, estimates, source dates, profile/vehicle details, and input revision.

**Expected result:** An atomically saved trip with restored progress and explicit stale-plan state after relevant input changes.

**Acceptance criteria:**

- Store planned stops, notes, date/timezone, estimates and their provenance, warnings, completed history, and the input revision locally; add a data-preserving migration when needed.
- Allow manual order/place changes as explicit overrides; mark affected estimates stale until recalculated rather than presenting an altered order as a valid optimized schedule.
- Restore a saved trip offline after restart, preserving independent Recurring originals and user completion state.
- Expose pending/saved/failed states and reconcile optimistic edits with durable storage. A failed write must preserve the last saved trip, retain the user's recoverable draft, and show an actionable retry without reporting unsaved changes as saved. Retry must apply the latest intended revision without overwriting newer edits or completion history. Navigation requiring a saved itinerary waits for durable save success.

**Verification:** Repository/migration/widget cases for plan round-trip, interruption, stale inputs, completion recovery, and independent copies; Android offline restart. Exercise failed replacement of a nonempty baseline, visible failure with retained draft, successful retry/reopen and newer edits during a failed/in-flight save, preserving Today and Recurring originals.

**Likely areas:** Future trips domain/repository/schema, review state, and focused tests.

### M5-03: Expose validated regional travel matrices

Implement only the backend pieces needed to supply genuine profile-specific road estimates after the early feasibility gate.

**Dependencies:** M5-02. **Estimated scope:** M; split any independent change that exceeds one focused implementation session.

**Inputs:** Bounded confirmed coordinates, transport/vehicle parameters, graph identity, and the contract's request limits.

**Expected result:** Asymmetric road-time matrices and route geometry with source/version information and explicit unreachable or unavailable states.

**Acceptance criteria:**

- Use a local FastAPI modular monolith with a Valhalla adapter; preserve unreachable pairs and graph/profile/vehicle cache identity.
- Keep calculations transient and bounded; personal errands remain on the phone. Add PostGIS only if real server catalog/cache queries require it.
- Document emulator/device networking and asleep/disconnected-computer behavior. Do not use a community demo as an unlimited backend or silently switch to a paid service.

**Verification:** Adapter/contract cases for success, unreachable pairs, restrictions, timeout, malformed data, graph/profile changes, and Android request integration.

**Likely areas:** Future services/api routing/core, configuration examples, mobile adapter, and focused tests.

### M5-04: Recommend suitable stores and branch alternatives

Generate and explain bounded candidate places for flexible errands. Automatic destination recommendation is a core first-release feature; manual place selection is an optional override.

**Dependencies:** M5-02, M3-06. **Estimated scope:** M; split any independent change that exceeds one focused implementation session.

**Inputs:** Supported errand category/text, pilot region, trip context, catalog records/provenance, hours availability, and any user-specified branch.

**Expected result:** Relevant bounded place alternatives with qualification reasons, source/freshness information, and explicit uncertainty for the scheduler.

**Acceptance criteria:**

- Use the regional catalog to recommend real stores/landmarks for flexible errands, preserve a user's fixed branch, and never fabricate places or assume product inventory from the store category.
- Filter unsuitable/known-closed candidates, retain branch identity and access context, and handle no matches by asking for clarification or offering a pin instead of inventing a solution.
- Allow missing reliable hours in a provisional candidate/plan with a clear check-hours notice. Keep candidate ranking independent from map-label priority and clustering.

**Verification:** Synthetic cases for relevant versus irrelevant stores, multiple branches, fixed override, duplicates, closed/unknown hours, unsupported category, and no candidates; inspect pilot recommendations.

**Likely areas:** Future recommendation service/catalog adapter, candidate domain models, and tests.

### M5-05: Choose branches and produce validated schedules

Use actual road matrices and bounded alternatives to choose branches, stop order, and a schedule jointly. The user supplies constraints and reviews the result.

**Dependencies:** M5-03, M5-04. **Estimated scope:** M; split any independent change that exceeds one focused implementation session.

**Inputs:** Candidate groups or fixed places, road matrices, endpoints, editable visit estimates, times/dependencies, optional status, and validated vehicle parameters.

**Expected result:** An independently checked plan with selected branches, ordered stops, estimated timings/geometry, omissions, and provisional-data notices.

**Acceptance criteria:**

- Honor mandatory visits, fixed-place overrides, departure/appointment/final deadlines, visit duration/buffers, waiting, known hours, and dependencies. Prioritize hard feasibility, then optional completion and lower travel time.
- Keep unknown-hour plans provisional and label default-duration assumptions. Explain optional omissions; never silently remove required errands or substitute straight-line times for missing road connections.
- Bound runtime/candidates, distinguish timeouts from proven conflicts, and independently validate every returned schedule. Compare tiny branch/order scenarios with exhaustive enumeration.

**Verification:** Fixed-matrix cases for branch choice, waiting, arrival versus completion deadlines, duration edits, dependencies, optional omission, unknown hours, unreachable legs, and time limits.

**Likely areas:** Future planning solver, independent validator, orchestration, and focused domain tests.

### M5-06: Review automatic plans and replan remaining stops

Connect the automatic recommendation/scheduling result to the mobile review and saved-trip workflow without requiring the user to choose all destinations or order the trip.

**Dependencies:** M5-05, M4-01, M3-07. **Estimated scope:** M; split any independent change that exceeds one focused implementation session.

**Inputs:** The latest submitted errand revision, calculation status, recommended places, estimated itinerary, user corrections, and completed-stop history.

**Expected result:** A reviewable, saved automatic itinerary and revision-safe replanning of unfinished work.

**Acceptance criteria:**

- Show recommended branches and reasons, numbered order, road geometry, estimated timing, source/calculation age, provisional hours, and any omitted optional errands.
- Support branch/time/duration/order corrections as overrides, then recalculate affected estimates; retain completed history and ignore obsolete in-flight responses.
- Preserve saved results offline and show honest no-results/conflict/timeout/backend-unavailable states. Users may review or correct a plan without doing the core planning themselves.

**Verification:** Contract/widget/repository cases plus Android duration/branch correction, delayed response, failed calculation, offline restart, and remaining-trip replanning scenarios.

**Likely areas:** Future planning/trips controllers, review/results views, repositories, and tests.

### M4-02: Open Google Maps from an automatically planned trip

Provide explicit external navigation after the user reviews a computed plan; retain the plan and completion state before leaving Wayday.

**Dependencies:** M4-01, M5-06. **Estimated scope:** M; split any independent change that exceeds one focused implementation session.

**Inputs:** The reviewed selected stop or supported whole-trip sequence, validated coordinates, transport profile, and available navigation targets.

**Expected result:** Google Maps or a readable fallback opens, with the original Wayday itinerary retained.

**Acceptance criteria:**

- Make Navigate to next stop the primary action; offer whole-trip links only within the target product's supported waypoint/mode limits.
- Handle missing Maps, browser fallback, invalid links, offline launch failures, and unsupported vehicle capabilities without losing the itinerary or inventing supported restrictions.
- Returning never automatically confirms arrival/completion or imports changes made in Google Maps. Keep completion an explicit action in Wayday.

**Verification:** URL and waypoint/mode boundary cases plus Android Maps/browser/no-target handoff and return-to-app checks.

**Likely areas:** Future navigation adapter, automatic-plan review UI, Android configuration when required, and tests.

### M4-03: Verify the complete automatic-plan handoff workflow

Run the integrated Android workflow before field evaluation. A manual-order-only workflow does not satisfy the first usable release.

**Dependencies:** M4-02, M3-09. **Estimated scope:** M; split any independent change that exceeds one focused implementation session.

**Inputs:** User-created errands, pilot catalog, vehicle/time constraints, real matrix service, automatic planner, and saved-trip/navigation integration.

**Expected result:** Reproducible end-to-end evidence and an actionable list of remaining failures.

**Acceptance criteria:**

- Exercise empty startup, editing, Recurring copies, inferred/corrected categories, automatic store/branch choice, order/timing, review, save/restart, and Google Maps handoff.
- Cover unknown-hour provisional plans, manual corrections, backend outages, stale responses, no candidates, and offline saved-plan recovery without fabricated results.
- Record analyzer/tests/debug build and actual Android targets; mark unmet release criteria pending rather than calling a partial workflow complete.

**Verification:** Full mobile checks and targeted service integration cases; Android walkthrough including large text, permission denial, offline restart, and missing Maps.

**Likely areas:** Affected mobile/backend integration checks, mobile README, and progress evidence.

### M5-07: Evaluate the automatic-planning first release

Evaluate the complete errand-planning role with representative pilot users and public destinations before calling the first usable release complete.

**Dependencies:** M4-03. **Estimated scope:** M; split any independent change that exceeds one focused implementation session.

**Inputs:** The integrated app, validated pilot coverage, real road engine, automatic branch/schedule result, and a declared comparison baseline.

**Expected result:** Measured release acceptance evidence, user feedback, known limitations, and a supported-region/profile statement.

**Acceptance criteria:**

- Users supply errands and necessary constraints; Wayday recommends destinations, chooses branches/order, estimates timings, supports corrections, saves progress, and opens external navigation.
- Measure mandatory completion, timing feasibility, optional omissions, travel-time error, branch suitability, and improvement against a stated baseline; include provisional-hour and vehicle-limit comprehension.
- Record physical Android evidence, resource/update costs, and unresolved limitations honestly. A map-only or manual-only checkpoint is not the first usable release; reminders/deployment/iOS remain separate.

**Verification:** Affected mobile/backend checks, independent schedule inspection, physical Android pilot journeys when available, and documented acceptance review.

**Likely areas:** Product acceptance evidence, docs/wayday/PROGRESS.md, existing run guides, and pilot findings.

## Cross-cutting compatibility and failure rules

| Concern | Required behavior |
| --- | --- |
| Existing rows may contain user edits | Preserve saved rows; remove future seeding/reset actions and let the user deliberately clear data |
| Legacy places contain labels without coordinates | Keep labels unresolved until a real place is confirmed; never migrate them to invented coordinates |
| OSM/Overture sources miss or duplicate businesses | Retain provenance, validate the pilot, deduplicate deliberately, preserve branch identity, and offer clarification/manual overrides |
| Tile schema omits searchable details | Use the separate indexed catalog for planning/search; changing a map style cannot create missing records |
| Missing duration or business hours | Use labeled editable estimates and provisional-hour notices; never claim assumed values are verified facts |
| No relevant stores or no road connection | Return an actionable missing-data/unreachable outcome; never create places, zero-time legs, or fake routes |
| Calculation times out or backend is unavailable | Preserve the last saved plan with its age, keep edits, and distinguish timeout from proven infeasibility |
| A response arrives after an edit or stop completion | Apply results only to the matching input revision; preserve newer edits and completed history |
| Package update is interrupted or incompatible | Keep the last valid package and all personal data; never advertise incomplete offline coverage |
| Manual branch/order/time correction changes a plan | Treat it as an override and recalculate affected estimates before showing timing feasibility as current |
| Heavy vehicle data is incomplete or unsupported | Ask for the needed vehicle details or show the unsupported capability explicitly; no access/clearance guarantee |
| External navigation fails or the user returns | Retain the itinerary, provide a readable destination fallback, and require explicit completion in Wayday |

## Bounded decisions to finish during prerequisite tasks

M3-01 records the exact region, measurable place coverage, source provenance, and whether Overture improves the pilot. M3-02/M3-03 record supported zooms, pinned renderer/native versions, measured package/storage requirements, and a lawful distribution/update method.

M5-01 records actual road-engine and pickup/heavy-vehicle capabilities and parameters on pilot data. M5-02 finalizes the versioned editable-duration/buffer table, single-day/overnight semantics, optional prerequisites, candidate/solve bounds, wire contracts, and synthetic acceptance examples before dependent code starts. These are named prerequisite deliverables, not permission to invent facts during implementation.

Reminders, deployment funding/capacity, iOS hardware/distribution, and nationwide expansion belong to later product decisions. Keep their absence from blocking the agreed initial Android pilot.

The former roadmap's readiness conditions remain applicable: verify native release configuration before accepting map integration, and publish measured coverage, storage, update, accessibility, and performance limitations. Later public deployment requires measured workloads, free-tier limits, recovery paths, access policy, TLS, backups, and an operating-cost decision. Reminder readiness requires physical-device permission, reboot, denial, background, and termination checks. Expand coverage only after source quality and distribution capacity are measured. These are later readiness conditions, not authorization to begin those phases.

## Documentation ownership

Use [the documentation index](../../README.md). README.md, AGENTS.md, and DESIGN.md live at the root; supporting project documents remain in docs/wayday/. The root README.md owns the project overview, documentation index, product requirements, and design-tool product metadata; DESIGN.md owns UI patterns, ARCHITECTURE.md owns responsibilities, STACK.md owns technology/license/cost evidence, DECISIONS.md records reasons and superseded choices, CONTRIBUTING.md owns development practices, and PROGRESS.md records verified work. This file owns milestone outcomes, the implementation plan, and task board. Do not recreate separate Product, Roadmap, or Development files. Commands and plain repository paths above are relative to the repository root.
