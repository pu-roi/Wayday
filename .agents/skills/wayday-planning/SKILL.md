---
name: wayday-planning
description: Plan, implement, or review Wayday errand interpretation rules, place candidates, route matrices, itinerary constraints, branch selection, and replanning. Use for planning semantics, not purely visual mobile changes.
---

# Wayday planning

Read the repository's `AGENTS.md` and current user request before acting. Work within the owner's authorized scope; a planning review does not authorize deployments, account changes or new backend services.

## Establish the contract

Read [Product requirements](../../../README.md#product-requirements), the focused [Plan my day plan](../../../docs/wayday/PLANNING.md), and [Architecture](../../../docs/wayday/ARCHITECTURE.md). Consult [Stack](../../../docs/wayday/STACK.md) for provider policies and [Decisions](../../../docs/wayday/DECISIONS.md) for changes. D44–D57 supersede older laptop-dependent, AI-deferred and introductory-screen assumptions. Current task order comes from the owner; do not recreate the removed roadmap or task board.

The versioned [planning contract](../../../docs/wayday/evidence/planning-contract-v1.md) and [routing feasibility study](../../../docs/wayday/evidence/routing-pilot-2026-10-27.md) remain historical specification/evidence where newer decisions differ. A 4×4 routing experiment does not qualify larger instances, real-world route accuracy or legal access. [Progress](../../../docs/wayday/PROGRESS.md) distinguishes implementation, fixture checks, device installation and live qualification.

The first usable release must recommend stores, select branches, order stops, and estimate schedules from user errands and constraints. Manual place/order choices are optional overrides or intermediate checkpoints, not a substitute for that release requirement.

## Current execution boundary

The Android presentation must run with the phone and internet, without a connected or reachable laptop. Use the existing Flutter controllers/repositories, bounded Dart worker-isolate scheduler and native provider bridges. The separate FastAPI service is not a presentation dependency; do not connect or deploy it as a side effect of mobile planning work.

Gemini interprets English, Filipino and Taglish titles/notes. Separate interpretation proposals, real place discovery, road estimates and scheduling. Preserve the user's original text and explicit structured fields; require explicit selection before applying model-derived rules or additional errands. Never manufacture business names, stock, opening hours, coordinates, dependencies or road times.

The current Gemini path is a private debug pilot with a Keystore-protected credential. D55 supersedes the former daily/monthly/finite-attempt limits: the owner removed app-imposed Gemini usage caps. Keep the key out of Flutter defines, Android manifests, logs and tracked files. Release/public integration remains a separate protection gate. Reuse matching interpretations, coalesce identical in-flight work and require explicit retry after failed/interrupted/corrupt processing. Check saved understanding must never dispatch a generation. Do not treat Cloud credit as a guaranteed spending cap or change provider quotas/billing as a side effect.

## Interpretation reuse and review

- Enter loading directly from Plan my day. Check matching saved understanding before dispatching a request; do not restore the removed introduction.
- Preserve the eight-entry native initial-interpretation journal, the separate 32-entry clarification journal, canonical request identity and in-flight coalescing. Keep the frozen legacy interpretation builder as a compatible completed-result lookup before generating typed interpretations. A schema change must not automatically retry legacy pending, failed or corrupt entries. Text/constraint/prompt/schema changes affect identity; routing-only changes do not require another interpretation. Revalidate decoded output against current task IDs and source revisions.
- Commit pending before dispatch and completion before delivery. After app death, pending/failed/corrupt outcomes require an explicitly labelled paid retry. Do not erase uncertainty or spend again merely because the user reopens the screen.
- Reconcile location-only questions against deterministic place handling, including cached answers. A usable selected point stays selected; unattached business/activity errands proceed to recommendations. A missing private meeting point uses the existing search/map-pin picker. Expired explicit provider references require confirmation rather than an unrelated branch substitution. Preserve mixed, timing, ordering and unrecognized clarification questions.
- Use the shared domain policy for visible questions and forward validation. New initial interpretations carry typed question scope and essential/optional metadata. Older cached questions remain untyped; use conservative location-wording compatibility without background classification requests. Resolve their meaning when the user submits an answer.
- Use the same effective projection for visible review order and forward validation. Reconcile selected After rules immediately, even if date/location input is invalid; retain the baseline for reversal. Compare effective proposals against the original review draft. Show only applicable Current/Suggested differences; Use suggestion and Keep current remain reversible after returning from discovery. Protect confirmed fields, keep extra errands opt-in, and retain independent task IDs when sharing a visit.
- Clear stale local validation feedback after saved date/time or preparation changes. Cancellation retains unchanged input and feedback. Next validates current values again; do not silently change the date or remove past-departure enforcement.

## Clarification answers and explicit flexibility — D57

- Question taps open the focused answer sheet; keep Edit errand separate. Store drafts without applying them. Free-form English, Filipino and Taglish goes to the contextual ClarificationResolver; known structured flexibility, picker actions and deferral use local controls. Disable duplicate submission while processing.
- Treat uncertain optional preferences as meaningful answers. Unknown grocery items mean broad suitable-place recommendations and choosing items on arrival, never an invented shopping list or inventory claim. Retain known items, explicit place preferences and fixed destinations. Optional preferences must not block planning or repeat after a flexibility choice.
- Track question identity, scope, raw answer, submitted status, validated result and displayed summary. Never restore the whole-errand clarified flag. An unrelated edit cannot answer a question; scope-compatible resolved preferences may survive unrelated clock/duration changes.
- Save submission before dispatch and result before closing. Show an editable summary after successful storage. Closing during processing preserves the work; reopening performs saved-only recovery and closes the sheet when the stored result arrives. Reopening an already applied answer stays editable. Errors retain text; explicit generation retry and free local save retry remain separate.
- Validate resolver output against current IDs, relevant confirmed facts and the dependency graph. Timing/order proposals require visible approval before affecting the projection. Preserve existing dependencies and reject cycles. Invalidate affected automatic candidates and the calculated schedule after relevant answer changes while keeping explicit place overrides.
- Unknown essential meeting points or existing pickup destinations still need actual confirmation. Offer the existing search/map-pin or time control, or Plan the other errands. Preview the dependent closure before exclusion. Deferred tasks stay in Today and remain required/optional as entered, with reasons visible in review and the plan. Re-inclusion is explicit, prerequisites must be included first, and a plan needs an active errand.
- Keep Drift v5 clarification sessions bound to source context and deferrals additionally bound to plan date. Merge independent draft/submission revisions so late completion cannot replace newer work. Persist confirmed review places through existing PlaceIntent/Google-reference serialization with source/text guards. Restore them after cache-first understanding; never extend Google coordinate retention.
- Accepted itinerary payload v2 retains clarification summaries/results and deferral reasons and reads v1. Validate assigned tasks, optional omissions and explicit deferrals as disjoint groups on save and read. Preserve completed progress, task IDs and shared-stop semantics. Use [D57 evidence](../../../docs/wayday/evidence/clarification-flow-2026-10-30.md) to distinguish implemented behavior from live-model and physical-device qualification.

## Preserve scheduling meaning

- Distinguish arrival deadlines from completion deadlines. Include visit duration, configured buffer, and required waiting in feasibility checks.
- Preserve the current visit duration and its confirmation/estimate status. Answering a clarification must not change the existing 15-minute estimate or ask for it again. Category-based estimates remain assumptions, not measured service times.
- Enforce exactly one branch for each active mandatory errand and at most one for each active optional errand. Explicitly deferred tasks form a separate group; never silently omit mandatory work or change its priority to shorten a route.
- Respect branch overrides, known business intervals, dependency order, and the final destination deadline. Missing reliable hours may produce a provisional plan with a check-hours notice; never claim the store is confirmed open. Preserve the provenance of corrections.
- Preserve asymmetric matrix values and unreachable legs. Do not substitute straight-line distances for road times without explicitly changing the estimate contract.
- Carry the selected profile through road requests, route-estimate identity and replanning. Preserve five top-level choices; public commute is excluded. Bicycle routing/guidance remains unavailable until separately qualified, with no motorcycle substitution. Truck is restricted to an explicitly confirmed compatible light pickup using labelled ordinary-driving estimates; heavy/restricted vehicles remain unavailable. Ground clearance, height, weight and legal access are separate requirements.
- Reject cycles and invalid references. Define the treatment of optional prerequisite errands consistently before modeling them.
- Replan unfinished work from the current location/time; retain completed history and newer user edits.
- Distinguish invalid input, missing data, no route, proven conflict, timeout, and service outage. Do not claim global optimality from a time-limited feasible result.

Use genuine candidate records and preserve standard visible Google UI Kit cards/order/attribution. Keep Other sources explicit. Respect the implemented candidate, matrix and worker limits; current discovery does not establish nationwide coverage, automatic corridor search or stock verification. Display Google Routes content on a Google map and retain embedded guidance inside Wayday for qualified modes. MapLibre remains available for the separate location/manual/offline experiences.

Keep personal inputs, accepted itinerary and progress local. Preparation task edits are drafts until acceptance. Explicitly saved review date/departure/deadline and manual source-errand clock differences are retained in a source-bound singleton. Restore trip context before understanding and manual clocks afterward, preserving unchanged canonical inputs. Changed sources and replanning/history bypass the snapshot; restored clocks do not resolve unrelated questions. Do not change Today, discard errors silently, or adjust appointments automatically. Model proposals and navigation arrival must not silently complete tasks. A future backend remains separately scoped; if requested, preserve the FastAPI modular-monolith boundaries rather than introducing microservices or cloud synchronization.

## Verify observable constraints

Run the mobile checks from [Contributing](../../../docs/wayday/CONTRIBUTING.md) and the [mobile guide](../../../apps/mobile/README.md). Use focused interpretation/cache, clarification/location, review, scheduler and flow tests for the affected boundary. Include uncertain Taglish answers, specific needs, unresolved essentials, unchanged estimates, rule approval, draft/restart recovery, duplicate submissions, storage failure, legacy compatibility, dependency-aware deferral/re-inclusion and accepted-v1/v2 validation. Check narrow/large-text sheets, keyboard insets, accessible feedback and reduced motion when interactions change. Check dependency reconciliation, confirmed-field protection, stale revisions, shared-stop task identity and local acceptance independently of the UI.

For solver changes, use fixed asymmetric matrices and independently validate resulting schedules. Compare tiny cases with exhaustive enumeration. Include branch alternatives, waiting, known hours, mandatory conflicts, optional omission, arrival/completion differences, unreachable pairs and late replanning. Treat full-size performance and live route quality as separate qualifications.

Use fixtures for provider failures, cached/interrupted answers and UI regression checks; do not consume paid requests for routine tests. Native journal fixtures are debug `.maptest` only. Do not seed the personal app's cache, clear its data, uninstall it or reprovision its credential during updates. Report remaining known test failures and actual device/live limitations without claiming complete readiness from a build or synthetic render.

The existing prototype check is `node docs/Asikaso-Prototype/docs/v2-planner-checks.cjs` from the repository root. It is a regression check for simulated examples, not evidence of real routing quality. During documentation-only work, record future scenarios without creating runtime scaffolds.

D53 adds structural source guards before interpretation and shared zero-road timing/window preflight before discovery and calculation. Preserve arrival/start/completion differences, mandatory prerequisite closure and optional omission; recheck graph integrity and elapsed departure before roads. Provider feasibility remains separate.

D54 blocks the native harness when the personal package is installed; use a disposable emulator without it. A missing understanding after installation recovery requires explicit paid retry. Never seed the personal journal or dispatch automatically after installation recovery. D55 removes the historical remaining-allocation gate.

D55 removes the former Gemini attempt caps in both Flutter and Android; legacy counter values do not gate requests. Keep Routes/search/navigation accounting independent.


## Route-aware recommendations — D58

D58 explicitly replaces the visible-UI-Kit-only recommendation boundary. Use the dedicated native Places SDK adapter for bounded whole-trip discovery and transient business metadata; keep standard UI Kit presentation in manual search. Preserve unified Google identity, coordinate leases, source-bound v6 drafts and provider attribution. Do not persist provider names/addresses as user-owned labels. Seed corridor discovery through fixed points, supplement at most two relevant anchors, shortlist no more than three candidates per errand/twelve assignments overall, and compare branches jointly with the existing scheduler. Preserve actual pickup locations and fixed addresses; address records can hydrate without becoming automatic business recommendations. Reuse recent matrices only in RAM for matching route context/subsets, revalidate selected legs and keep Gemini independent of routing-only changes. Follow D58 evidence for Android/live qualification and existing D54 harness protection.
