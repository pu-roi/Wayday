# Wayday

<!-- impeccable:product-schema 1 -->

Wayday is a mobile errand planner for Philippine cities. This is the project overview, documentation index, and product-requirements authority. Requirements below distinguish current behavior from planned and later capabilities.

## Documentation

The root `README.md` owns the project overview, documentation index, product requirements, and design-tool metadata. Supporting project documents live in `docs/wayday/`; `AGENTS.md` and `DESIGN.md` also remain at the root. Historical Asikaso sources, screenshots, and app-specific run instructions keep their existing locations. Commands and plain repository paths are relative to the repository root unless stated otherwise.

| Document | Purpose |
| --- | --- |
| [Product requirements](#product-requirements) | User needs, scope, behavior, and acceptance scenarios |
| [Plan my day implementation plan](docs/wayday/PLANNING.md) | Owner-requested feature plan, interface flow, implementation sequence, technical gates, and acceptance checks |
| [Progress](docs/wayday/PROGRESS.md) | Completed work, contributor attribution, and verification evidence |
| [Architecture](docs/wayday/ARCHITECTURE.md) | Responsibilities, interfaces, and offline boundaries |
| [Stack](docs/wayday/STACK.md) | Technology research, dependency inventory, licensing, costs, and limits |
| [Decisions](docs/wayday/DECISIONS.md) | Why choices were made, what superseded earlier choices, and unresolved assumptions |
| [Contributing](docs/wayday/CONTRIBUTING.md) | Development practices, verification, and contribution guidance |
| [Design](DESIGN.md) | Mobile theme, shared components, and interaction rules |
| [Agent instructions](AGENTS.md) | Repository guidance for coding assistants |

Current work follows the owner's latest explicit instructions; Progress records completed work. On 2026-10-30 the owner explicitly requested the focused Plan my day implementation plan linked above, before runtime implementation. This does not restore the former project-wide roadmap or task board. Development guidance is consolidated in Contributing. Do not create another roadmap or task board unless the owner explicitly asks. Give design tools `README.md` explicitly for product context; the product schema marker and platform/stack context live here.

## Application folders

| Folder | Intended application |
| --- | --- |
| [apps/mobile](apps/mobile) | Flutter frontend organized by feature, with views, view models, and repositories |
| [services/api](services/api) | FastAPI backend organized as a modular monolith with domain services |

The mobile folder contains the Flutter application; see its [run instructions](apps/mobile/README.md). The API folder contains an imported, bounded FastAPI place service for review; it is not connected to the mobile app. The architecture document distinguishes implemented capabilities from the broader planned application.

## Product requirements

Updated: 2026-10-30 (Asia/Manila). These requirements preserve the long-term product scope. The owner supplies current tasks directly; this does not replace the product requirements below. Earlier persistence, regional data, routing feasibility and contract work have recorded evidence. The current combined picker, saved-place management and native map-control changes still require integrated Android verification. Progress and evidence files distinguish implemented work from verified behavior.

### Platform

android

### Stack

Flutter/Dart. See the authoritative [stack inventory](docs/wayday/STACK.md). Visual tokens and interaction patterns live in [Design](DESIGN.md).

### Purpose and status

Wayday will help people complete several errands in one trip by choosing suitable places, ordering stops, and checking timing constraints. Initial users are people running errands in Philippine cities, with Pasig/Ortigas as the proposed pilot area.

The current implementation is an Android Flutter app with a single light Cornflower theme, Today, Recurring, Profile and Settings. Personal tasks and saved places use local Drift/SQLite storage; new installations start empty and existing rows are preserved. Earlier Today/Recurring persistence across force-stop and relaunch was verified on an API 37 x86_64 emulator on 2026-10-27. Notes copy independently into Today, list transitions honor reduced motion and ordinary in-app feedback expires automatically. The shared location picker now combines a map, search while typing, saved places and one confirmation action. Profile supports saved-place editing and deletion; Today previews confirmed places without a calculated route. A separate offline Pasig/Ortigas preview and credits page remain in Settings. Current picker, legacy-data recovery and native map-control changes require integrated Android verification. Time and repeat editing retain focused controls; repeat metadata does not schedule automatic additions. A measured local Valhalla study and versioned planning contract remain feasibility/specification evidence. The imported FastAPI pilot place service is not connected to the app. The presentation search pilot combines Geoapify, LocationIQ, and Photon through a shared local scheduler; public distribution still requires centralized quota control. D47 now connects a private Android Plan my day pilot for interpretation review, bounded candidate comparison, scheduling, route review and accepted local progress. Live service and physical-phone qualifications are tracked separately; reminders remain deferred. The browser preview keeps changes in memory for the session.

Build and verify Android first. iOS remains a later target; iOS tooling and device access do not block Android development.

### Post-hackathon first-release target — planned

The paragraphs below describe enduring product outcomes, not the current hackathon task sequence. Current priorities come from the owner's latest instructions.

Use MapLibre with Protomaps regional map files and a custom Wayday style for the existing map/manual/offline experiences. Online place search is Philippines-wide through the direct-client presentation pilot; provider coverage still needs qualification. On 2026-10-29 the owner selected Google Places UI Kit as an additional search experience, Google Routes as traffic-aware planning input, and embedded Google Navigation SDK for trips. Google route-review views must use a Google map. Google-first search and an explicit Other sources group are implemented through native Places UI Kit under D43; the bounded isolated Android Google sample passes after the test identity was authorized. D47 adds a private Android planning flow, restricted Routes adapter and embedded Navigation integration; the evidence distinguishes tested fixtures/builds from outstanding live and physical-phone qualification. The prepared offline map package and measured place audit cover only Pasig/Ortigas. Evaluate Overture only as a validated, attributed supplement. Users can search by name/category, inspect a branch and its available address, or choose a manual pin. Save confirmed coordinates, place identity, and provenance rather than treating a typed label as a located destination; Google references retain user-owned labels and IDs durably, with coordinates isolated in a private cache expiring within thirty days. See D35, D42 and D43 in [Decisions](docs/wayday/DECISIONS.md).

The owner clarified the first usable release: users supply errands and necessary constraints, and Wayday recommends suitable stores, selects branches, chooses stop order, and calculates an estimated schedule using real road travel data. Users review or correct the result; they are not required to choose every store or build the itinerary themselves. Manual ordering and place selection remain optional overrides and internal development checkpoints. Validate road and POI feasibility early. Save the reviewed trip locally, then start embedded Google navigation to the selected stops under D42; an explicit external Google Maps handoff remains a possible fallback. Completion is a manual user action. A navigation reroute does not automatically reorder errands or establish schedule feasibility.

Keep the light Cornflower application theme and reuse the implemented selection controls in [Design](DESIGN.md). Planning and Progress record their draft, accessibility, and Android checks. Map styles may vary independently when map integration is implemented. Repeat settings remain descriptive metadata.

On 2026-10-30 the owner clarified that the presentation must operate with the phone and internet alone, without a laptop connection or laptop-hosted planning service. The proposed implementation calculates bounded branch/stop schedules on Android using online place and road-time inputs. This replaces the earlier local-backend dependency for this experience; it does not establish full offline discovery or fresh offline traffic-aware planning. See D44 in [Decisions](docs/wayday/DECISIONS.md) and the [mobile planning handoff](docs/wayday/evidence/planning-contract-v1.md#phone-only-planning-handoff-2026-10-30).

Users can accept Wayday's recommended branches or choose alternatives before accepting the itinerary. Read current errand titles, optional notes and explicit preferences when qualifying places. Grocery needs may be served by supermarkets, discount stores, convenience stores or wet markets; category membership is not proof of item inventory. Several compatible errands may share one physical visit while retaining separate IDs, durations, dependency rules and completion controls. A missing private meeting point requires explicit location confirmation through search or a positioned map pin. Saving dependency changes must reconcile the displayed and persisted list order with those rules, preserving unrelated order where possible. D47 implements the preparation/acceptance paths and dependency-order reconciliation; full candidate coverage, inventory suitability and live guidance remain qualification limits.

### Current product direction

| Capability | Planned first-version boundary |
| --- | --- |
| Errand input | Ordinary text or bullet lines with Gemini-assisted, editable interpretation of English, Filipino and Taglish sentences; private debug pilot with persistent interpretation reuse and explicit retries |
| Place selection | Automatic recommendations and branch choice using place data; specific/saved places and manual pins are optional overrides |
| Day planning | Start/end points, departure, final deadline, stop duration, priority, timing rules, and dependencies |
| Travel | Walking, biking, motorcycle (motor), sedan (low clearance), or truck (high clearance); one profile per trip; no public commute |
| Plan result | Map and stop timeline, selected branches, estimated times, slack, and errands that do not fit |
| Trip progress | Mark stops complete, change a branch, report a delay, and request replanning |
| Routines | Named templates containing groups of errands, copied into a day |
| Reminders | Local time notifications and background location reminders subject to platform permissions and delivery limits |
| Offline use | Local tasks, templates, saved places, saved itinerary, progress, and previously downloaded map coverage |

Public commute is excluded from current scope, including jeepney, bus, and rail journey planning. D45 selects Gemini-assisted interpretation of sentence-level English, Filipino and Taglish errands and notes. D47 implements a private debug connection with encrypted provisioning. D55 removes its historical app-imposed request allowances while preserving reuse and explicit retries. Live-traffic planning and embedded navigation adapters are implemented under D47 but are not yet fully qualified on the physical phone. Accounts, cross-device synchronization, analytics, and continuous location history are not first-version requirements. Full offline discovery and fresh offline route optimization are also deferred.

An explicit external-navigation fallback may hand a leg to an installed navigation app. This handoff is a user convenience, not a source of travel-time or place data; Wayday must still show permitted saved stop information when no navigation app is available. Embedded Google navigation is the selected primary direction under D42, with an implemented private pilot adapter and live qualification still required.

Visit duration uses clearly labeled, editable category-based estimates when the user has not supplied a duration. Finalize the versioned estimate/buffer table in the input-contract task before scheduler implementation; defaults are assumptions, not measured service times. Preserve explicit user values. A store with missing reliable hours may appear in a provisional plan with a check-hours notice, while known closures still constrain scheduling.

### Transportation profiles and feasibility

The five profiles above are the owner's clarified product scope. Sedan and truck support supersede the earlier decision to defer those categories; biking is also included. Clearance-aware routing is a requirement to investigate, not an implemented or verified capability.

The owner clarified that the high-clearance category includes pickup/light trucks and heavy delivery vehicles. Keep the five top-level choices, distinguish vehicle subtype and needed restrictions in the planning input, and request necessary dimensions/weight for heavy-vehicle costing. Keep ground clearance (space below the vehicle) separate from overall height (relevant to overhead clearance). Low/high clearance labels do not establish numeric dimensions, road passability, or vehicle access rights. Validate available surface, access, and restriction data in the pilot area. Do not promise ground-clearance safety from an ordinary car/truck route.

### Input and correction

Under D45, Gemini is the selected interpretation component for English, Filipino and Taglish sentences in errand titles and notes. It proposes categories, shopping needs, preferences and timing/dependency rules for review. Proposed extra errands from notes require confirmation before creation. Preserve the original text, require clarification for ambiguous references, and retain structured editing when the service is unavailable. Existing finite search aliases remain useful matching utilities, not the limit of intended sentence interpretation. D47 implements the private debug bridge and review flow; live model and physical-device qualification are recorded separately in the implementation evidence. D48 removes the introductory page and adds immediate loading with a bounded durable interpretation cache. Reopening unchanged errands reuses completed understanding; interrupted/failed outcomes require explicit paid retry.

Preserve the original text and distinguish explicit user values from suggestions and defaults. Unknown places, ambiguous times, and unclear references need correction. For example, “lunch with her after” must not acquire a guessed dependency or person. Structured editing remains available even when parsing fails. Editing an errand title must not silently erase previously confirmed rules.

Proposed categories include groceries/wet markets, haircuts, coffee/food, pharmacies, banks, offices, and other errands. Category coverage and Filipino/Taglish vocabulary require local validation; the prototype's category list is not a complete specification.

#
D57 implements question-specific answer sheets, contextual Gemini clarification, explicit flexible place needs, local drafts and dated deferrals. It preserves visit estimates, protects known fields and requires approval of proposed rules. Drift v5 and accepted itinerary JSON v2 retain answer progress and deferral reasons; v1 itineraries remain readable. Compatible legacy interpretation reuse, separate answer snapshots and D55’s removal of local usage caps remain in force. Qualification is recorded in [the D57 evidence](docs/wayday/evidence/clarification-flow-2026-10-30.md).

## Timing and priority

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

Tasks and progress remain usable after connectivity loss or app restart. The saved-trip requirement includes ordered stops, permitted coordinates, schedule metadata and calculation time, with route geometry where the source permits retention. Do not promise durable Google route-content storage from the coordinate-caching exception; validate the applicable retention rules before implementing that snapshot. User-owned labels, task rules and progress remain durable. Map coverage must have completed downloading before it is advertised as available offline.

Search within an installed regional catalog can work offline. Updating public map/catalog packages requires a deliberate refresh path; this is separate from personal-data synchronization. D44 requires the phone to perform bounded scheduling without a local backend. New place discovery and traffic-aware road estimates still require reachable online providers. If they are unavailable, retain local edits and show only permitted saved information with its age. Do not replace a road route with a straight line and label it as a calculated journey. Existing reminders can operate locally, subject to OS behavior.

### Design reference

The interaction reference is [Asikaso V2](docs/Asikaso-Prototype/V2-NOTES.md): From/Errands/To, compact numbered rows, focused editing, recurring groups, and a future map with a timeline. The owner's refined MVP direction uses a single light Canvas/Cornflower theme with no palette or dark-mode controls. Today and Recurring share compact rows and a focused editor; every quick-added errand starts as Anytime. See the [current design system](DESIGN.md).

The [original abstract](docs/ASIKASO_ABSTRACT.md) emphasizes public commuting. That ambition is excluded from current scope. Preserve the original rather than rewriting project history.

### Acceptance scenarios for later development

1. Enter an English, Filipino, or Taglish errand; review suggestions and correct unknown fields without losing the note.
2. Choose a branch and obtain a schedule using road travel estimates, visit durations, waiting, and known hours.
3. Demonstrate that arrive-by and finish-before produce different feasibility results for the same arrival and visit duration.
4. Report an impossible mandatory appointment or final deadline without silently removing mandatory work. Users may explicitly defer errands after reviewing affected dependents, keeping them in Today and retaining their required status.
5. Explain omitted optional errands. Distinguish missing data and solver timeout from proven conflicts.
6. Change a branch or report a delay; preserve completed stops and recalculate only the remaining itinerary.
7. Copy a template into Today, preserve dependencies, avoid duplicate addition, and keep template edits independent from today's copies.
8. Restart offline; recover tasks, progress, itinerary, and available map coverage.
9. Exercise location/notification denial, approximate location, background delay, reboot, and disabled location services with clear fallback behavior.
10. Select each of the five transportation profiles and verify that the appropriate routing assumptions reach planning and replanning. Changing a profile must invalidate incompatible travel estimates. Include bicycle access and vehicle-restriction cases; mark unsupported clearance checks as unverified instead of reporting them as satisfied.

Capstone evaluation should compare route duration/distance against a defined baseline order, task completion, estimated versus observed times, and user feedback. No accuracy or efficiency percentage is claimed before measurement.

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

Run the mobile application and its checks using [the mobile guide](apps/mobile/README.md). There are no backend run commands yet.

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


D58 adds automatic route-aware whole-trip recommendations, transient Places SDK business metadata, a shared Google map/list, explicit manual alternatives and source-bound Drift v6 draft recovery. It preserves the existing manual UI Kit picker, Google retention/attribution, local personal state and qualified-mode limits. See [implementation evidence](docs/wayday/evidence/route-recommendations-2026-10-31.md) for tests and outstanding live-provider and physical-phone checks.
