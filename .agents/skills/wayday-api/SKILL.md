---
name: wayday-api
description: Design, change, or review Wayday REST/JSON requests, responses, validation, error semantics, OpenAPI, and Flutter API integration. Use for client-server contracts rather than purely internal backend logic or database schemas.
---

# Wayday API contracts

Read the root `AGENTS.md`, [Architecture](../../../docs/wayday/ARCHITECTURE.md), and the relevant [Product](../../../docs/wayday/PRODUCT.md) behavior. The documented `/v1` endpoints are proposals until implemented; do not claim an existing wire contract or compatibility obligation that has not been established.

## Define the observable behavior

Inspect any existing Pydantic/OpenAPI definitions and client models before editing a contract. Identify the consumer, changed input/output, and supported behavior. Keep API transport models separate from database rows and provider payloads. Load `wayday-backend` for service changes and `wayday-mobile` for affected client state.

- Preserve original notes and user-confirmed constraints. Do not reparse a request and silently replace corrected fields.
- Represent date/time, timezone, duration, coordinates, stable errand IDs, dependencies, and the chosen transportation profile explicitly where the operation needs them. Do not confuse ground clearance with overall vehicle height or invent dimensions from profile labels.
- Keep arrival and completion deadlines distinct across client and server. Carry relevant profile/restriction information through planning and replanning.
- Validate bounded search areas, input size, coordinate ranges, duration/time rules, and reference consistency where relevant. Do not publish guessed limits as established product decisions; define justified limits with the implementation.
- Distinguish malformed input, missing place information, no road connection, infeasible constraints, solver timeout, and service outage. A timed-out search is not a successful empty itinerary or proof of impossibility.
- Return the estimate age, warnings, omissions, and source information needed by the UI to explain uncertainty. Do not wrap an incomplete plan in an unqualified success state.
- Let clients correlate a result with the input revision that requested it. Preserve stable local task identities during replan and avoid making plan calculations an implicit server-persistence operation.
- Keep credentials and provider secrets out of client payloads and error details. Do not introduce account/authentication flows or expose a local development API publicly as a side effect of a contract change.

## Check both sides of a change

When runtime code exists, update OpenAPI/models, client decoding, and relevant examples together. Check valid input, validation failures, unknown/missing fields under the chosen compatibility policy, dependency failure responses, and stale in-flight results as applicable. Use fixtures for external providers rather than live community endpoints.

Review explicit units, nullable/unknown values, and coordinate ordering at each adapter boundary. Confirm that offline client behavior remains useful when the API is unreachable. If a released client already exists, describe migration/compatibility impact; do not require a new API version for every internal refactor.
