---
name: wayday-backend
description: Plan, implement, or review Wayday FastAPI domain services, orchestration, provider adapters, configuration, and background computation. Use for backend internals; HTTP contracts and schema migrations have separate skills.
---

# Wayday backend

Read the root `AGENTS.md` and [Architecture](../../../docs/wayday/ARCHITECTURE.md). Respect the current development phase; authoring this skill does not authorize creating an API project or starting services.

## Keep domain boundaries explicit

Use one FastAPI modular monolith organized around places, routing, and planning. Keep HTTP handlers thin, business orchestration in domain services, persistence in repositories, and Valhalla translation in an adapter. Avoid inventing separately deployed feature services, a queue, or Redis without a measured need.

Read [Product requirements](../../../README.md#product-requirements) for behavior and [Stack](../../../docs/wayday/STACK.md) before changing an external dependency. Consult the completed [routing feasibility evidence](../../../docs/wayday/evidence/routing-pilot-2026-10-27.md) and versioned [input/result contract](../../../docs/wayday/evidence/planning-contract-v1.md) where relevant; these do not authorize runtime work by themselves. [Contributing](../../../docs/wayday/CONTRIBUTING.md#backend-after-the-routing-gate) owns backend development and verification guidance. Load `wayday-api` when changing observable HTTP behavior, `wayday-database` for persistence changes, and `wayday-planning` for itinerary semantics. Do not load unrelated skills for a purely internal change.

## Preserve Wayday's operating model

- Keep personal errands and trip progress on the phone by default. A calculation request does not authorize storing user notes, location history, or cloud backups.
- Treat the place catalog, road routing, and optimization as distinct capabilities. Return missing data or dependency failure honestly; do not fabricate places, hours, or travel estimates.
- Carry the transportation profile and validated restrictions through routing calls and cache identity. Keep engine options behind the adapter so provider defaults cannot silently change the product's meaning.
- Bound provider requests, retries, and solver execution. Preserve cancellation and distinguish timeout from a proven infeasible schedule. Keep CPU-bound solver work off the async event loop.
- Keep request/session state isolated. Define transaction ownership at the service boundary; do not hold a database transaction open while waiting for road routing or a long solve without a demonstrated requirement.
- Keep endpoint configuration and credentials outside business logic. Log operational failures without full notes, home coordinates, credentials, or request bodies by default.
- Preserve local development when considering cloud hosting. Supabase database hosting does not also host the Python optimizer or Valhalla. Record service quotas and trial exit behavior before adding a dependency.

## Verify meaningful behavior

For authorized runtime changes, test orchestration using provider/repository fixtures: success, missing catalog data, unreachable roads, rate limits, timeout, cancellation, and partial dependency failure as relevant. Exercise bounded concurrency for shared resources when affected. Use actual project checks only after the project exists; do not claim API readiness from the prototype's simulated tests.

Report the changed responsibility, affected contract or configuration, checks performed, and remaining operating limits. Keep public deployment, provisioning, and application scaffolding within the user's requested scope.
