# Wayday

Wayday is a proposed mobile errand planner for Philippine cities. It will help users choose suitable places, order several stops, and see whether their errands fit the time available.

**Status: foundation and planning only.** The Flutter application and backend have not been scaffolded. The existing Asikaso HTML files are design prototypes with simulated places, parsing, maps, and travel times.

## Current direction

- Target Android and iOS with Flutter.
- Plan a local FastAPI backend with PostgreSQL/PostGIS, Valhalla, and OR-Tools.
- Plan for walking, biking, motorcycle (motor), sedan (low clearance), and truck (high clearance), using one profile per trip. Public commute is excluded.
- Use editable, rule-based suggestions for English, Filipino, and Taglish errand input. AI is deferred.
- Keep tasks, templates, trip progress, and saved itineraries on the phone for offline use.
- Target zero spending. Free tiers and trials are acceptable, with their limits and expiry documented.

These are the current foundation decisions, not implemented capabilities. Product details and design remain open to refinement.

## Documentation

| Document | Purpose |
| --- | --- |
| [Product](docs/wayday/PRODUCT.md) | Current scope, user flows, and acceptance criteria |
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

There are no mobile or backend run commands yet. See the development guide before setting up future tooling.

## Project skills

Repository skills live under `.agents/skills/`:

- `wayday-mobile`: mobile architecture, offline behavior, and location reminder work.
- `wayday-planning`: place selection, timing constraints, route planning, and solver verification.

Skills guide authorized work; they do not start application development or install dependencies.

## Licensing

This foundation does not assign a license to the team's original work. Third-party software and data retain their own licenses. See the stack inventory before adding or redistributing dependencies, map data, fonts, or assets.
