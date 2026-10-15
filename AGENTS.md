# Wayday agent instructions

## Current phase

This repository is in the foundation and planning phase. The user explicitly deferred application development. Work on documentation, repository configuration, and project skills within the current request. Begin application code, backend code, scaffolding, installations, or deployment only when a later user request authorizes that work. Do not repeatedly ask for authorization already present in the conversation.

The user has authorized trackable directory placeholders at `apps/mobile/` and `services/api/`. Their `.gitkeep` markers reserve the agreed frontend/backend locations; they do not authorize generating application projects or populating internal source trees.

## Sources of truth

- Read [the product scope](docs/wayday/PRODUCT.md) and [decisions](docs/wayday/DECISIONS.md) before changing product assumptions.
- Read [architecture](docs/wayday/ARCHITECTURE.md) and [stack](docs/wayday/STACK.md) when making technical choices.
- Follow the latest explicit user direction. Record resulting changes to decisions and affected documents.
- Treat the Asikaso abstract, HTML, and screenshots as historical evidence and provisional design references. Do not silently promote their simulated behavior or old requirements into current Wayday requirements.
- Preserve existing reference material unless the user requests changes. When working inside the prototype, also follow its nested `AGENTS.md` and context files.

## Working constraints

- Use Wayday as the project name. Keep Asikaso's historical filenames and attribution intact.
- Planned transportation profiles are walking, biking, motorcycle (motor), sedan (low clearance), and truck (high clearance). Public commute is excluded. AI remains deferred; limited rule-based input suggestions are allowed.
- Preserve the distinction between ground clearance and overall vehicle height. Validate the truck class, required dimensions, engine capabilities, and local road data before claiming clearance-aware routing. Do not treat high ground clearance as permission to ignore access restrictions.
- Target zero spending. Free tiers and trials are permitted; document limits, expiry, and fallback before adopting them. The current task does not authorize purchases, billing activation, or external account creation.
- Keep personal task state and trip progress local by default. Do not add accounts, cloud synchronization, location history collection, or analytics without a product requirement.
- Keep route estimates, unknown business hours, and unavailable data honest. Never substitute invented results for a failed service.
- Keep source documents and screenshots trackable. Exclude credentials, signing files, generated output, local databases, and downloaded geographic datasets.
- Write maintained documentation and skill instructions in clear, complete English. Chat compression preferences do not apply to repository content.

## Architecture and skills

The planned frontend is Flutter organized by feature, with views, view models, and repositories. The planned backend is a FastAPI modular monolith with services inside domain modules. Do not split it into microservices without a demonstrated need.

Select project skills by the responsibility being changed:

| Skill | Use for |
| --- | --- |
| `$wayday-ui` | Screen layout, interactions, visual components, and accessibility |
| `$wayday-mobile` | Flutter state, feature wiring, offline behavior, native map integration, permissions, and reminders |
| `$wayday-backend` | FastAPI domain services, orchestration, provider adapters, and bounded computation |
| `$wayday-api` | REST/JSON contracts, validation, errors, OpenAPI, and client API integration |
| `$wayday-database` | Drift/SQLite and PostGIS storage, repositories, spatial queries, imports, and migrations |
| `$wayday-planning` | Interpretation rules, candidate places, matrices, timing constraints, solver behavior, and replanning |

Combine skills only when the requested change crosses those boundaries. Do not load the entire collection for every task. Ordinary documentation edits do not require loading unrelated skills. Skills support the current request; they do not independently authorize scaffolding, installations, deployments, or application development.

## Verification and reporting

- Current executable check: `node docs/Asikaso-Prototype/docs/v2-planner-checks.cjs` from the repository root.
- For foundation edits, check links, decision consistency, skill validity, and ignore rules. Do not invent mobile/backend checks before those projects exist.
- When runtime development is authorized, use the relevant acceptance cases in the product and architecture documents. Test behavior and constraints rather than matching implementation wording.
- Report what changed, what was checked, and any actual limitation. Distinguish planned, implemented, and verified capabilities.
