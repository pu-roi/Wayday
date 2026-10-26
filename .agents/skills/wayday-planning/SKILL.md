---
name: wayday-planning
description: Plan, implement, or review Wayday errand interpretation rules, place candidates, route matrices, itinerary constraints, branch selection, and replanning. Use for planning semantics, not purely visual mobile changes.
---

# Wayday planning

Read the repository's `AGENTS.md` and current user request before acting. Foundation work does not authorize developing the backend or installing routing services.

## Establish the contract

Read [Product requirements](../../../docs/wayday/README.md#product-requirements) and the pipeline in [Architecture](../../../docs/wayday/ARCHITECTURE.md). Consult [Stack](../../../docs/wayday/STACK.md) for data sources and endpoint policies, and [Decisions](../../../docs/wayday/DECISIONS.md) for scope changes. [Planning](../../../docs/wayday/PLANNING.md#task-specifications) owns implementation order and acceptance criteria, including the early M5-01 routing/vehicle gate and M5-02 input/result contract.

The first usable release must recommend stores, select branches, order stops, and estimate schedules from user errands and constraints. Manual place/order choices are optional overrides or intermediate checkpoints, not a substitute for that release requirement.

Separate limited text suggestions, real place discovery, road travel estimation, and itinerary optimization. AI is deferred. Never invent a business, opening interval, coordinate, dependency, or travel estimate to fill missing data. Preserve original text and explicitly confirmed constraints.

## Preserve scheduling meaning

- Distinguish arrival deadlines from completion deadlines. Include visit duration, configured buffer, and required waiting in feasibility checks.
- Use labeled, editable category-based visit estimates only when the user has not supplied a duration. Preserve explicit values and finalize the versioned estimate/buffer policy in the input-contract task.
- Enforce exactly one branch for mandatory errands and at most one for optional errands. Never trade mandatory completion for a shorter route.
- Respect branch overrides, known business intervals, dependency order, and the final destination deadline. Missing reliable hours may produce a provisional plan with a check-hours notice; never claim the store is confirmed open. Preserve the provenance of corrections.
- Preserve asymmetric matrix values and unreachable legs. Do not substitute straight-line distances for road times without explicitly changing the estimate contract.
- Carry the selected walking, biking, motorcycle, sedan, or truck profile through matrix requests, cache identity, and replanning. Public commute is excluded. Distinguish pickup/light and heavy delivery subtypes within the high-clearance category, obtaining the vehicle parameters required by validated engine/data support. Keep ground clearance separate from overall height, weight, and access restrictions; never invent missing restriction data.
- Reject cycles and invalid references. Define the treatment of optional prerequisite errands consistently before modeling them.
- Replan unfinished work from the current location/time; retain completed history and newer user edits.
- Distinguish invalid input, missing data, no route, proven conflict, timeout, and service outage. Do not claim global optimality from a time-limited feasible result.

Use a FastAPI modular monolith with domain services and provider adapters when runtime work is authorized. Keep CPU-bound solving off the async event loop and bound its runtime. Do not add a public community endpoint as an unlimited backend or introduce cloud synchronization as a side effect of planning work.

## Verify observable constraints

For solver changes, use fixed matrices and independently validate resulting schedules. Compare tiny cases with exhaustive enumeration. Include branch alternatives, waiting, known hours, mandatory conflicts, optional omission, arrival/completion differences, unreachable pairs, and late replanning. Test adapter failures with fixtures rather than repeatedly calling public services.

The existing prototype check is `node docs/Asikaso-Prototype/docs/v2-planner-checks.cjs` from the repository root. It is a regression check for simulated examples, not evidence of real routing quality. During documentation-only work, record future scenarios without creating runtime scaffolds.
