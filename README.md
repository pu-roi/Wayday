# Wayday

Wayday is a proposed mobile errand planner for Philippine cities. It will help users choose suitable places, order several stops, and see whether their errands fit the time available.

**Status: M1 complete; M2 maps, manual itinerary review and pilot place search implemented; physical-location and coverage gates remain.** The Flutter app provides durable personal errands, notes, saved places, recurring lists and independent copies, numeric time entry, and one light Cornflower theme. Real MapLibre/OpenFreeMap display now supports manual pins and a V2-inspired editable review after Plan my day. A local FastAPI service now searches a bounded OSM catalog by name, landmark and address. M2-03 PostGIS runtime verification is complete; physical-location checks, place-quality coverage, recommendations and road planning remain pending. See [the database handoff](docs/wayday/M2_DATABASE_HANDOFF.md) for contributor setup. See [Progress](PROGRESS.md) for checks and limits and [the map/review handoff](docs/wayday/MAP_REVIEW_HANDOFF.md) for contributor boundaries. The preserved Asikaso HTML files use simulated places, parsing, maps and travel times.

Start with [Running Wayday](docs/wayday/RUNNING_WAYDAY.md): app-only development needs no Docker; real search can use file mode or the full PostGIS setup.

## Current direction

- Build for Android first with Flutter; iOS implementation and verification come later.
- Use local FastAPI/PostgreSQL/PostGIS place search; add Valhalla and OR-Tools in M3.
- Plan for walking, biking, motorcycle (motor), sedan (low clearance), and truck (high clearance), using one profile per trip. Public commute is excluded.
- Use editable, rule-based suggestions for English, Filipino, and Taglish errand input. AI is deferred.
- Keep tasks, templates, trip progress, and saved itineraries on the phone for offline use.
- Target zero spending. Free tiers and trials are acceptable, with their limits and expiry documented.

These are the current product decisions; the status above distinguishes implemented capabilities from later work. Product details and design remain open to refinement.

## Application folders

| Folder | Intended application |
| --- | --- |
| [apps/mobile](apps/mobile) | Flutter frontend organized by feature, with views, view models, and repositories |
| [services/api](services/api) | FastAPI backend organized as a modular monolith with domain services |

The mobile folder contains the Flutter application; see its [run instructions](apps/mobile/README.md). The API folder contains the local place service; see [its setup guide](services/api/README.md). The architecture document distinguishes the current shell from the broader planned application.

## Documentation

| Document | Purpose |
| --- | --- |
| [Planning](PLANNING.md) | Project task board, milestones, assignees, and task status |
| [Approved implementation plan](docs/wayday/IMPLEMENTATION_PLAN.md) | Personal planning, maps, local/cloud storage, sharing, notifications and completion gates |
| [Progress](PROGRESS.md) | Activity log, contributor attribution, and milestone progress |
| [Product](docs/wayday/PRODUCT.md) | Current scope, user flows, and acceptance criteria |
| [Design](DESIGN.md) | Implemented mobile theme, components, and interaction rules |
| [Stack](docs/wayday/STACK.md) | Technology comparisons, dependency inventory, costs, and sources |
| [Architecture](docs/wayday/ARCHITECTURE.md) | Responsibilities, future layout, interfaces, and offline boundaries |
| [Development](docs/wayday/DEVELOPMENT.md) | What works today and prerequisites for a later development phase |
| [Roadmap](docs/wayday/ROADMAP.md) | Staged work and validation gates |
| [Decisions](docs/wayday/DECISIONS.md) | Decisions, assumptions, and reasons to revisit them |
| [Contributing](CONTRIBUTING.md) | Contribution and verification guidance |
| [Agent instructions](AGENTS.md) | Repository guidance for coding assistants |

## Existing reference material

- [Original Asikaso abstract](docs/ASIKASO_ABSTRACT.md)
- [Prototype context](docs/Asikaso-Prototype/CONTEXT.md) and [V2 notes](docs/Asikaso-Prototype/V2-NOTES.md)
- [Original HTML prototype](docs/Asikaso-Prototype/asikaso.html) and [V2 HTML prototype](docs/Asikaso-Prototype/V2.html)
- [Selected screenshots](docs/Screenshot) and [V2 screenshots](docs/Asikaso-Prototype/docs/screenshots/v2)

The abstract describes broader public-commute ambitions. Public commute is excluded from current Wayday scope. Historical material is preserved for comparison. Vehicle clearance and road restrictions still need feasibility validation before implementation.

## Try the existing prototype

Open `docs/Asikaso-Prototype/V2.html` directly in a browser. Use `#empty`, `#example`, or `#plan` to explore example screens. The prototype resets its in-memory state on reload.

With Node.js available, run the existing prototype checks from the repository root:

```powershell
node docs/Asikaso-Prototype/docs/v2-planner-checks.cjs
```

Run the mobile application and its checks using [the mobile guide](apps/mobile/README.md). Run local place search with `.\tool\prepare-places.ps1`, `.\tool\prepare-places-db.ps1` and `.\tool\start-places.ps1` from the repository root, with Docker Desktop running. See [the handoff](docs/wayday/M2_DATABASE_HANDOFF.md) for verification and contributor boundaries.

## Project skills

Repository skills live under `.agents/skills/`:

| Skill | Responsibility |
| --- | --- |
| [wayday-task-tracker](.agents/skills/wayday-task-tracker/SKILL.md) | Task status, assignee tracking, and activity logging with Git identity |
| [wayday-ui](.agents/skills/wayday-ui/SKILL.md) | Screen design, interactions, visual components, and accessibility |
| [wayday-mobile](.agents/skills/wayday-mobile/SKILL.md) | Flutter state, offline behavior, native integration, and reminders |
| [wayday-backend](.agents/skills/wayday-backend/SKILL.md) | Domain services, provider adapters, and backend orchestration |
| [wayday-api](.agents/skills/wayday-api/SKILL.md) | Client-server contracts, validation, error semantics, and OpenAPI |
| [wayday-database](.agents/skills/wayday-database/SKILL.md) | Local/server storage, spatial queries, imports, and migrations |
| [wayday-planning](.agents/skills/wayday-planning/SKILL.md) | Place selection, timing constraints, routing, and solver verification |

Invoke a skill by name, for example `$wayday-ui`. Select only the skills relevant to the requested change; combine them for work crossing responsibilities.

Skills guide authorized work; they do not start application development or install dependencies.

## Licensing

This foundation does not assign a license to the team's original work. Third-party software and data retain their own licenses. See the stack inventory before adding or redistributing dependencies, map data, fonts, or assets.
