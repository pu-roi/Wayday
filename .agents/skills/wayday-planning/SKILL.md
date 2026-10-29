---
name: wayday-planning
description: Plan, implement, or review Wayday errand interpretation rules, place candidates, route matrices, itinerary constraints, branch selection, and replanning. Use for planning semantics, not purely visual mobile changes.
---

# Wayday planning

Read the repository's `AGENTS.md` and current user request before acting. Work within the owner's authorized scope; a planning review does not authorize deployments, account changes or new backend services.

## Establish the contract

Read [Product requirements](../../../README.md#product-requirements), the focused [Plan my day plan](../../../docs/wayday/PLANNING.md), and [Architecture](../../../docs/wayday/ARCHITECTURE.md). Consult [Stack](../../../docs/wayday/STACK.md) for provider policies and [Decisions](../../../docs/wayday/DECISIONS.md) for changes. D44–D51 supersede older laptop-dependent, AI-deferred and introductory-screen assumptions. Current task order comes from the owner; do not recreate the removed roadmap or task board.

The versioned [planning contract](../../../docs/wayday/evidence/planning-contract-v1.md) and [routing feasibility study](../../../docs/wayday/evidence/routing-pilot-2026-10-27.md) remain historical specification/evidence where newer decisions differ. A 4×4 routing experiment does not qualify larger instances, real-world route accuracy or legal access. [Progress](../../../docs/wayday/PROGRESS.md) distinguishes implementation, fixture checks, device installation and live qualification.

The first usable release must recommend stores, select branches, order stops, and estimate schedules from user errands and constraints. Manual place/order choices are optional overrides or intermediate checkpoints, not a substitute for that release requirement.

## Current execution boundary

The Android presentation must run with the phone and internet, without a connected or reachable laptop. Use the existing Flutter controllers/repositories, bounded Dart worker-isolate scheduler and native provider bridges. The separate FastAPI service is not a presentation dependency; do not connect or deploy it as a side effect of mobile planning work.

Gemini interprets English, Filipino and Taglish titles/notes. Separate interpretation proposals, real place discovery, road estimates and scheduling. Preserve the user's original text and explicit structured fields; require explicit selection before applying model-derived rules or additional errands. Never manufacture business names, stock, opening hours, coordinates, dependencies or road times.

The current Gemini path is a private debug pilot with a Keystore-protected credential and finite provisioned allowance. Keep the key out of Flutter defines, Android manifests, logs and tracked files. Release/public integration remains a separate protection gate. Respect the authorized total and rolling request limits; do not refill, retry automatically or treat Cloud credits as an account-wide spending cap.

## Interpretation reuse and review

- Enter loading directly from Plan my day. Check matching saved understanding before dispatching a request; do not restore the removed introduction.
- Preserve the native bounded no-backup response journal, canonical request identity and in-flight coalescing. Text/constraint/prompt/schema changes affect identity; routing-only changes do not require another interpretation. Revalidate decoded output against current task IDs and source revisions.
- Commit pending before dispatch and completion before delivery. After app death, pending/failed/corrupt outcomes require an explicitly labelled paid retry. Do not erase uncertainty or spend again merely because the user reopens the screen.
- Reconcile location-only questions against deterministic place handling, including cached answers. A usable selected point stays selected; unattached business/activity errands proceed to recommendations. A missing private meeting point uses the existing search/map-pin picker. Expired explicit provider references require confirmation rather than an unrelated branch substitution. Preserve mixed, timing, ordering and unrecognized clarification questions.
- Use the shared domain policy for both visible questions and forward validation. The cached question schema is untyped; its conservative location-wording compatibility rule is not a general reasoning engine.
- Compare effective proposals against the original review draft. Show only applicable Current/Suggested differences; Use suggestion and Keep current remain reversible after returning from discovery. Protect confirmed fields, keep extra errands opt-in, and retain independent task IDs when sharing a visit.
- Clear stale local validation feedback after saved date/time or preparation changes. Cancellation retains unchanged input and feedback. Next validates current values again; do not silently change the date or remove past-departure enforcement.

## Preserve scheduling meaning

- Distinguish arrival deadlines from completion deadlines. Include visit duration, configured buffer, and required waiting in feasibility checks.
- Use labeled, editable category-based visit estimates only when the user has not supplied a duration. Preserve explicit values and finalize the versioned estimate/buffer policy in the input-contract task.
- Enforce exactly one branch for mandatory errands and at most one for optional errands. Never trade mandatory completion for a shorter route.
- Respect branch overrides, known business intervals, dependency order, and the final destination deadline. Missing reliable hours may produce a provisional plan with a check-hours notice; never claim the store is confirmed open. Preserve the provenance of corrections.
- Preserve asymmetric matrix values and unreachable legs. Do not substitute straight-line distances for road times without explicitly changing the estimate contract.
- Carry the selected profile through road requests, route-estimate identity and replanning. Preserve five top-level choices; public commute is excluded. Bicycle routing/guidance remains unavailable until separately qualified, with no motorcycle substitution. Truck is restricted to an explicitly confirmed compatible light pickup using labelled ordinary-driving estimates; heavy/restricted vehicles remain unavailable. Ground clearance, height, weight and legal access are separate requirements.
- Reject cycles and invalid references. Define the treatment of optional prerequisite errands consistently before modeling them.
- Replan unfinished work from the current location/time; retain completed history and newer user edits.
- Distinguish invalid input, missing data, no route, proven conflict, timeout, and service outage. Do not claim global optimality from a time-limited feasible result.

Use genuine candidate records and preserve standard visible Google UI Kit cards/order/attribution. Keep Other sources explicit. Respect the implemented candidate, matrix and worker limits; current discovery does not establish nationwide coverage, automatic corridor search or stock verification. Display Google Routes content on a Google map and retain embedded guidance inside Wayday for qualified modes. MapLibre remains available for the separate location/manual/offline experiences.

Keep personal inputs, accepted itinerary and progress local. Preparation edits are drafts until the existing acceptance path commits them. Model proposals and navigation arrival must not silently complete tasks. A future backend remains separately scoped; if requested, preserve the FastAPI modular-monolith boundaries rather than introducing microservices or cloud synchronization.

## Verify observable constraints

Run the mobile checks from [Contributing](../../../docs/wayday/CONTRIBUTING.md) and the [mobile guide](../../../apps/mobile/README.md). Use focused interpretation/cache, clarification/location, review, scheduler and flow tests for the affected boundary. Check dependency reconciliation, confirmed-field protection, stale revisions, shared-stop task identity and local acceptance independently of the UI.

For solver changes, use fixed asymmetric matrices and independently validate resulting schedules. Compare tiny cases with exhaustive enumeration. Include branch alternatives, waiting, known hours, mandatory conflicts, optional omission, arrival/completion differences, unreachable pairs and late replanning. Treat full-size performance and live route quality as separate qualifications.

Use fixtures for provider failures, cached/interrupted answers and UI regression checks; do not consume paid requests for routine tests. Native journal fixtures are debug `.maptest` only. Do not seed the personal app's cache, clear its data, uninstall it or reprovision its allowance during updates. Report remaining known test failures and actual device/live limitations without claiming complete readiness from a build or synthetic render.

The existing prototype check is `node docs/Asikaso-Prototype/docs/v2-planner-checks.cjs` from the repository root. It is a regression check for simulated examples, not evidence of real routing quality. During documentation-only work, record future scenarios without creating runtime scaffolds.
