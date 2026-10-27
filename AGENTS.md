# Wayday agent instructions

## Current phase

The Android Flutter shell, Today, and Recurring are implemented. Local Drift/SQLite storage for Today and Recurring was implemented and verified on Android on 2026-10-27; the browser preview remains in memory. Use one light Cornflower theme without appearance controls, compact errand lists, focused editing, and numeric time entry. Repeat settings are metadata, not an automatic scheduler. Do not repeatedly ask for authorization already present in the conversation.

On 2026-10-27 the owner removed the implementation plan and task board. The owner estimated the hackathon was about two days away; exact dates, event duration, theme, required technology and judging criteria remain unconfirmed. Follow only the owner's latest explicit task instructions; do not restore the removed roadmap or infer a new task sequence. M3-01, M3-02, M5-01 and M5-02 remain completed evidence/specification. M3-03 has historical emulator evidence; the current picker and patched native controls remain unverified on Android. Preserve product constraints, including honest route/place data and the long-term requirements in README.md. Completed-work evidence remains in Progress and the evidence files.

The owner also authorized smoother list motion, optional free-form errand notes, and refined in-app feedback on 2026-10-16. Notes copy independently from Recurring into Today. Respect reduced motion, preserve continuous-entry focus, and make ordinary feedback expire automatically. In-app snackbars are not Android reminder notifications; reminder integration remains deferred.

The frontend lives at `apps/mobile/`. The backend root `services/api/` contains the imported bounded place service for review; the app uses the separate Photon-compatible online search adapter. Current UI work does not authorize new backend scaffolding or connecting the pilot service to nationwide search. The combined location picker, Profile saved-place management and Today map controls are implemented but still require integrated Android verification.

Android is the first implementation and verification target. iOS comes later and is not a prerequisite for starting Android work.

## Sources of truth

- Read [the product scope](README.md#product-requirements) and [decisions](docs/wayday/DECISIONS.md) before changing product assumptions.
- Read [architecture](docs/wayday/ARCHITECTURE.md) and [stack](docs/wayday/STACK.md) when making technical choices.
- Keep `README.md`, `AGENTS.md`, and `DESIGN.md` at the repository root. Keep supporting current project documents in `docs/wayday/`. [README](README.md) owns the document index, product requirements, and design-tool product metadata. The owner supplies current task scope and sequence directly; [Progress](docs/wayday/PROGRESS.md) records completed work. [Contributing](docs/wayday/CONTRIBUTING.md) owns development and verification guidance. Decisions, Architecture, and Stack retain their separate responsibilities. Do not create a new roadmap or task board unless the owner explicitly asks. Generic skill output paths do not override these locations; supply the README path explicitly to tools that need product context.
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

- Mobile checks: run `flutter analyze` and `flutter test` from `apps/mobile/`; see its README for local-tool support. The preserved prototype check is `node docs/Asikaso-Prototype/docs/v2-planner-checks.cjs` from the repository root.
- For foundation edits, check links, decision consistency, skill validity, and ignore rules. Do not invent mobile/backend checks before those projects exist.
- When runtime development is authorized, use the relevant acceptance cases in the product and architecture documents. Test behavior and constraints rather than matching implementation wording.
- Report what changed, what was checked, and any actual limitation. Distinguish planned, implemented, and verified capabilities.
