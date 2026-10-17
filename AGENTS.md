# Wayday agent instructions

## Current phase

On 2026-10-17 the owner approved [the implementation plan](docs/wayday/IMPLEMENTATION_PLAN.md), superseding the earlier UI-only deferrals below for the staged Android planner. Implement M1 durable local state alongside an M2 data/routing feasibility spike first; follow [PLANNING.md](PLANNING.md) and milestone gates. Real maps, local backend/data services, planning, reminders and later sharing are authorized within that sequence. Publishing/following shared trips requires sign-in; personal planning stays local and account-free. Sharing uses explicit opt-in, expiring links, latest location only and traveler-confirmed activity events. Truck means pickup/light truck. No purchase, billing activation, external account creation or public deployment is authorized. iOS, AI, live traffic, automatic recurrence and full personal cloud synchronization remain deferred.

The owner authorized the Android Flutter app shell and Today module, then added Recurring and UI refinements on 2026-10-16. Use one light Cornflower theme without appearance controls, compact errand lists, focused editing, numeric time entry, and clearly labeled map placeholders. Basic in-memory editing, reusable groups, manual copying to Today, and navigation are in scope. Repeat settings are metadata, not an automatic scheduler. Backend development, real planning, place services, durable persistence, notifications, deployment, and iOS remain deferred unless a later request authorizes them. Do not repeatedly ask for authorization already present in the conversation.

The owner also authorized smoother list motion, optional free-form errand notes, and refined in-app feedback on 2026-10-16. Notes copy independently from Recurring into Today. Respect reduced motion, preserve continuous-entry focus, and make ordinary feedback expire automatically. In-app snackbars are not Android reminder notifications; reminder integration remains deferred.

The frontend lives at `apps/mobile/`. During the original UI milestone, `services/api/` was reserved. The later approved implementation plan and M2 refinement now authorize its local FastAPI places service, bounded OSM import and PostGIS baseline/adapter; public deployment remains unauthorized.

Android is the first implementation and verification target. iOS comes later and is not a prerequisite for starting Android work.

The owner requested another UI pass on 2026-10-17 before M2: remove example-day loaders, start new workspaces empty without resetting existing data, use a compact left-aligned Today prompt, animate module navigation with reduced-motion support, and add a read-only sample Profile named Jace Bellen. Profile is not an account or a live-sharing identity. Keep the current Cornflower design system and four labeled destinations: Today, Recurring, Profile and Settings.

On 2026-10-18 the owner revised the personal draft defaults: From and To are session-only and clear on cold launch/Flutter hot restart, while errands and saved places remain durable. Recurring groups start collapsed. Manual pins should use a real mapped name when supported by a unique containing area or close mapped point; ambiguous or merely nearby results require explicit selection. Named residential areas belong in pilot search. Keep interpretation untouched. See [contributor run modes](docs/wayday/RUNNING_WAYDAY.md).

On 2026-10-18 the owner selected a future active-itinerary flow with explicit Done actions and per-leg Google Maps/Waze handoff. Manual arrival remains available; automatic arrival policy is undecided. Sharing belongs to M5/M6 and embedded guidance is optional later evaluation. The immediate change is only the review action label Find your way; keep its current draft-save behavior and interpretation untouched. See decision D26.

## Sources of truth

On 2026-10-17 the owner confirmed real maps plus manual itinerary review first, independently of another contributor's interpretation work. Keep existing interpretation untouched. See [the map/review handoff](docs/wayday/MAP_REVIEW_HANDOFF.md). Plan my day opens a draft vertical review with manual order, priority and place changes; confirmation persists the reviewed day, not a calculated route or active trip. M2 catalog search and M3 recommendations remain separate gates. The owner subsequently approved a search-first chooser with real name/landmark suggestions, a full-screen center-pin map and read-only coordinates; remove custom-name and coordinate-entry forms. M2-03 now has verified local PostGIS imports/search and defaults to database mode; file snapshot mode is opt-in only. Follow [the database handoff](docs/wayday/M2_DATABASE_HANDOFF.md). Physical-location and place-quality coverage checks remain open; M2 is not complete. Keep interpretation code, related mobile behavior and tests untouched in the database work. On 2026-10-17 the owner also required the entire Android phone app to stay upright in portrait, including maps and startup. Do not develop a separate landscape layout. See D22 and D23 in the decision log.

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

- Mobile checks: run `flutter analyze` and `flutter test` from `apps/mobile/`; see its README for local-tool support. The preserved prototype check is `node docs/Asikaso-Prototype/docs/v2-planner-checks.cjs` from the repository root.
- For foundation edits, check links, decision consistency, skill validity, and ignore rules. Do not invent mobile/backend checks before those projects exist.
- When runtime development is authorized, use the relevant acceptance cases in the product and architecture documents. Test behavior and constraints rather than matching implementation wording.
- Report what changed, what was checked, and any actual limitation. Distinguish planned, implemented, and verified capabilities.
