# Wayday

<!-- impeccable:product-schema 1 -->

Wayday is a mobile errand planner for Philippine cities. This is the project overview, documentation index, and product-requirements authority. Requirements below distinguish current behavior from planned and later capabilities.

## Documentation

All current Wayday project documents live in `docs/wayday/`. Only `AGENTS.md` and `DESIGN.md` remain as root Markdown files. Historical Asikaso sources, screenshots, and app-specific run instructions keep their existing locations. Commands and plain repository paths are relative to the repository root unless stated otherwise.

| Document | Purpose |
| --- | --- |
| [Product requirements](#product-requirements) | User needs, scope, behavior, and acceptance scenarios |
| [Planning](PLANNING.md) | Future work, execution order, dependencies, task specifications, and live status |
| [Progress](PROGRESS.md) | Completed work, contributor attribution, and verification evidence |
| [Architecture](ARCHITECTURE.md) | Responsibilities, interfaces, and offline boundaries |
| [Stack](STACK.md) | Technology research, dependency inventory, licensing, costs, and limits |
| [Decisions](DECISIONS.md) | Why choices were made, what superseded earlier choices, and unresolved assumptions |
| [Contributing](CONTRIBUTING.md) | Development practices, verification, and contribution guidance |
| [Design](../../DESIGN.md) | Mobile theme, shared components, and interaction rules |
| [Agent instructions](../../AGENTS.md) | Repository guidance for coding assistants |

Planning describes what comes next; Progress records what has been completed. Roadmap outcomes are consolidated in Planning. Development guidance is consolidated in Contributing. Do not recreate separate Product, Roadmap, or Development documents. Give design tools `docs/wayday/README.md` explicitly for product context; the product schema marker and platform/stack context live here.

## Application folders

| Folder | Intended application |
| --- | --- |
| [apps/mobile](../../apps/mobile) | Flutter frontend organized by feature, with views, view models, and repositories |
| [services/api](../../services/api) | FastAPI backend organized as a modular monolith with domain services |

The mobile folder contains the Flutter application; see its [run instructions](../../apps/mobile/README.md). The API folder still contains only a `.gitkeep` marker. The architecture document distinguishes the current shell from the broader planned application.

## Product requirements

Updated: 2026-10-27 (Asia/Manila). These requirements preserve the agreed product scope. The owner authorized Stage 1 cleanup and selection-control implementation; task status and verification belong in Planning and Progress. Reminder and later-platform acceptance cases apply to their later milestones, not the first usable release.

### Platform

android

### Stack

Flutter/Dart. See the authoritative [stack inventory](STACK.md). Visual tokens and interaction patterns live in [Design](../../DESIGN.md).

### Purpose and status

Wayday will help people complete several errands in one trip by choosing suitable places, ordering stops, and checking timing constraints. Initial users are people running errands in Philippine cities, with Pasig/Ortigas as the proposed pilot area.

The current implementation is an Android Flutter app with a single light Cornflower theme, Today, and Recurring. The app stores Today and Recurring data in a local Drift/SQLite database; new installations start with empty lists and unset endpoints, and existing saved rows are preserved. Persistence across force-stop and relaunch was verified on the API 37 x86_64 emulator on 2026-10-27. Notes copy independently into Today. List insertion and disclosure have short transitions that honor reduced motion; themed in-app feedback expires automatically under ordinary navigation. Map selection is an illustrative placeholder with manual labels; time entry uses hour/minute fields. Timing and repeat frequency use labeled radio rows, weekdays use a shared confirmation sheet, and monthly day uses validated numeric input. The full application capabilities below remain planned; there is no backend, automatic recurrence scheduler, or real route calculation yet. The browser preview starts empty and keeps changes in memory for the session.

Build and verify Android first. iOS remains a later target; iOS tooling and device access do not block Android development.

### Next implementation target — planned

The owner requested the step-by-step plan on 2026-10-27. See [the implementation plan](PLANNING.md#task-specifications) for task dependencies and acceptance criteria; the paragraphs below describe product outcomes rather than implementation status.

Use MapLibre with Protomaps regional map files, a custom Wayday style, and an indexed OSM-based place catalog. Start with measured Pasig/Ortigas coverage. Evaluate Overture only as a validated, attributed supplement. Users can search by name/category, inspect a branch and its available address, or choose a manual pin. Save confirmed coordinates, place identity, and provenance rather than treating a typed label as a located destination.

The owner clarified the first usable release: users supply errands and necessary constraints, and Wayday recommends suitable stores, selects branches, chooses stop order, and calculates an estimated schedule using real road travel data. Users review or correct the result; they are not required to choose every store or build the itinerary themselves. Manual ordering and place selection remain optional overrides and internal development checkpoints. Validate road and POI feasibility early. Save the reviewed trip locally, then explicitly open Google Maps for the next stop. Completion is a manual user action; whole-trip handoff is secondary and respects target limits.

Keep the light Cornflower application theme and reuse the implemented selection controls in [Design](../../DESIGN.md). Planning and Progress record their draft, accessibility, and Android checks. Map styles may vary independently when map integration is implemented. Repeat settings remain descriptive metadata.

### Current product direction

| Capability | Planned first-version boundary |
| --- | --- |
| Errand input | Ordinary text or bullet lines with limited, editable rule-based suggestions in English, Filipino, and Taglish |
| Place selection | Automatic recommendations and branch choice from a regional catalog; specific/saved places and manual pins are optional overrides |
| Day planning | Start/end points, departure, final deadline, stop duration, priority, timing rules, and dependencies |
| Travel | Walking, biking, motorcycle (motor), sedan (low clearance), or truck (high clearance); one profile per trip; no public commute |
| Plan result | Map and stop timeline, selected branches, estimated times, slack, and errands that do not fit |
| Trip progress | Mark stops complete, change a branch, report a delay, and request replanning |
| Routines | Named templates containing groups of errands, copied into a day |
| Reminders | Local time notifications and background location reminders subject to platform permissions and delivery limits |
| Offline use | Local tasks, templates, saved places, saved itinerary, progress, and previously downloaded map coverage |

Public commute is excluded from current scope, including jeepney, bus, and rail journey planning. AI interpretation, live traffic, and in-app turn-by-turn navigation remain deferred. Accounts, cross-device synchronization, analytics, and continuous location history are not first-version requirements. Full offline discovery and fresh route optimization are also deferred.

The initial plan may hand a leg to an installed navigation app. This is a user convenience, not a source of travel-time or place data; Wayday must still show the saved stop address and coordinates when no navigation app is available.

Visit duration uses clearly labeled, editable category-based estimates when the user has not supplied a duration. Finalize the versioned estimate/buffer table in the input-contract task before scheduler implementation; defaults are assumptions, not measured service times. Preserve explicit user values. A store with missing reliable hours may appear in a provisional plan with a check-hours notice, while known closures still constrain scheduling.

### Transportation profiles and feasibility

The five profiles above are the owner's clarified product scope. Sedan and truck support supersede the earlier decision to defer those categories; biking is also included. Clearance-aware routing is a requirement to investigate, not an implemented or verified capability.

The owner clarified that the high-clearance category includes pickup/light trucks and heavy delivery vehicles. Keep the five top-level choices, distinguish vehicle subtype and needed restrictions in the planning input, and request necessary dimensions/weight for heavy-vehicle costing. Keep ground clearance (space below the vehicle) separate from overall height (relevant to overhead clearance). Low/high clearance labels do not establish numeric dimensions, road passability, or vehicle access rights. Validate available surface, access, and restriction data in the pilot area. Do not promise ground-clearance safety from an ordinary car/truck route.

### Input and correction

Rule-based suggestions can recognize explicit phrases such as “before 4pm,” “sunduin,” “palengke,” and “kung may time.” A rule can suggest a category, timing constraint, or priority. It does not establish general language understanding.

Preserve the original text and distinguish explicit user values from suggestions and defaults. Unknown places, ambiguous times, and unclear references need correction. For example, “lunch with her after” must not acquire a guessed dependency or person. Structured editing remains available even when parsing fails. Editing an errand title must not silently erase previously confirmed rules.

Proposed categories include groceries/wet markets, haircuts, coffee/food, pharmacies, banks, offices, and other errands. Category coverage and Filipino/Taglish vocabulary require local validation; the prototype's category list is not a complete specification.

### Timing and priority

- **Anytime:** no user-specified time boundary, but known business hours still matter.
- **At a set time:** service starts at the specified time; early arrival may require waiting.
- **Arrive by:** arrival must occur by the deadline; completion can be later.
- **Finish before:** the visit, including its configured stop buffer, must finish by the deadline.
- **Must do:** never silently omit the errand to produce a successful-looking itinerary.
- **If there is time:** may be omitted with an explanation when the itinerary cannot accommodate it.
- **After another errand:** retain the dependency and reject circular ordering.

Business availability must cover the intended visit. Missing or stale hours are unknown, not proof that a business is open. A manual correction must retain its provenance. Final deadline and appointment feasibility take precedence over reducing travel time.

“On the way home” remains an interaction to refine. Do not silently turn it into a requirement that a particular errand is always the single final stop.

### Offline promise

Tasks and progress remain usable after connectivity loss or app restart. A saved trip includes its ordered stops, coordinates, route geometry, schedule, and calculation time. Map coverage must have completed downloading before it is advertised as available offline.

Search within an installed regional catalog can work offline. Updating public map/catalog packages requires a deliberate refresh path; this is separate from personal-data synchronization. Automatic road-based planning/replanning may require the later local backend. If it is unavailable, show saved results with their age and retain edits locally. Do not replace a road route with a straight line and label it as a calculated journey. Existing reminders can operate locally, subject to OS behavior.

### Design reference

The interaction reference is [Asikaso V2](../Asikaso-Prototype/V2-NOTES.md): From/Errands/To, compact numbered rows, focused editing, recurring groups, and a future map with a timeline. The owner's refined MVP direction uses a single light Canvas/Cornflower theme with no palette or dark-mode controls. Today and Recurring share compact rows and a focused editor; every quick-added errand starts as Anytime. See the [current design system](../../DESIGN.md).

The [original abstract](../ASIKASO_ABSTRACT.md) emphasizes public commuting. That ambition is excluded from current scope. Preserve the original rather than rewriting project history.

### Acceptance scenarios for later development

1. Enter an English, Filipino, or Taglish errand; review suggestions and correct unknown fields without losing the note.
2. Choose a branch and obtain a schedule using road travel estimates, visit durations, waiting, and known hours.
3. Demonstrate that arrive-by and finish-before produce different feasibility results for the same arrival and visit duration.
4. Report an impossible mandatory appointment or final deadline without silently removing mandatory work.
5. Explain omitted optional errands. Distinguish missing data and solver timeout from proven conflicts.
6. Change a branch or report a delay; preserve completed stops and recalculate only the remaining itinerary.
7. Copy a template into Today, preserve dependencies, avoid duplicate addition, and keep template edits independent from today's copies.
8. Restart offline; recover tasks, progress, itinerary, and available map coverage.
9. Exercise location/notification denial, approximate location, background delay, reboot, and disabled location services with clear fallback behavior.
10. Select each of the five transportation profiles and verify that the appropriate routing assumptions reach planning and replanning. Changing a profile must invalidate incompatible travel estimates. Include bicycle access and vehicle-restriction cases; mark unsupported clearance checks as unverified instead of reporting them as satisfied.

Capstone evaluation should compare route duration/distance against a defined baseline order, task completion, estimated versus observed times, and user feedback. No accuracy or efficiency percentage is claimed before measurement.

## Existing reference material

- [Original Asikaso abstract](../ASIKASO_ABSTRACT.md)
- [Prototype context](../Asikaso-Prototype/CONTEXT.md) and [V2 notes](../Asikaso-Prototype/V2-NOTES.md)
- [Original HTML prototype](../Asikaso-Prototype/asikaso.html) and [V2 HTML prototype](../Asikaso-Prototype/V2.html)
- [Selected screenshots](../Screenshot) and [V2 screenshots](../Asikaso-Prototype/docs/screenshots/v2)

The abstract describes broader public-commute ambitions. Public commute is excluded from current Wayday scope. Historical material is preserved for comparison. Vehicle clearance and road restrictions still need feasibility validation before implementation.

## Try the existing prototype

Open `docs/Asikaso-Prototype/V2.html` directly in a browser. Use `#empty`, `#example`, or `#plan` to explore example screens. The prototype resets its in-memory state on reload.

With Node.js available, run the existing prototype checks from the repository root:

```powershell
node docs/Asikaso-Prototype/docs/v2-planner-checks.cjs
```

Run the mobile application and its checks using [the mobile guide](../../apps/mobile/README.md). There are no backend run commands yet.

## Project skills

Repository skills live under `.agents/skills/`:

| Skill | Responsibility |
| --- | --- |
| [wayday-task-tracker](../../.agents/skills/wayday-task-tracker/SKILL.md) | Task status, assignee tracking, and activity logging with Git identity |
| [wayday-ui](../../.agents/skills/wayday-ui/SKILL.md) | Screen design, interactions, visual components, and accessibility |
| [wayday-mobile](../../.agents/skills/wayday-mobile/SKILL.md) | Flutter state, offline behavior, native integration, and reminders |
| [wayday-backend](../../.agents/skills/wayday-backend/SKILL.md) | Domain services, provider adapters, and backend orchestration |
| [wayday-api](../../.agents/skills/wayday-api/SKILL.md) | Client-server contracts, validation, error semantics, and OpenAPI |
| [wayday-database](../../.agents/skills/wayday-database/SKILL.md) | Local/server storage, spatial queries, imports, and migrations |
| [wayday-planning](../../.agents/skills/wayday-planning/SKILL.md) | Place selection, timing constraints, routing, and solver verification |

Invoke a skill by name, for example `$wayday-ui`. Select only the skills relevant to the requested change; combine them for work crossing responsibilities.

Skills guide authorized work; they do not start application development or install dependencies.

## Licensing

This foundation does not assign a license to the team's original work. Third-party software and data retain their own licenses. See the stack inventory before adding or redistributing dependencies, map data, fonts, or assets.
