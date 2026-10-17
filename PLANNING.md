# Wayday implementation board

Approved direction: [Implementation plan](docs/wayday/IMPLEMENTATION_PLAN.md). Gates: [Roadmap](docs/wayday/ROADMAP.md). Verification and contributor history: [Progress](PROGRESS.md).

Last reconciled: 2026-10-18. Android first; rudy-branch. DONE requires the relevant checks. A milestone with outstanding physical-device or infrastructure gates is not complete.

## Current stage

M0 and M1 are complete with automated checks and an Android emulator offline cold-start check. M2 now provides real MapLibre/OpenFreeMap display, a search-first place chooser backed by a bounded local OSM catalog, full-screen manual pin selection and an editable itinerary review. Android phones are locked to upright portrait. M2-03 is complete: the local FastAPI service defaults to verified PostgreSQL/PostGIS search, with repeat imports, rollback, correction retention, spatial queries and outage/restart recovery checked. File mode remains an explicit development option. Field coverage and real-world correction checks remain open under M2-04. See [the database handoff](docs/wayday/M2_DATABASE_HANDOFF.md). Foreground location cancellation and a simulated GPS fix were verified on the emulator; physical GPS and native permission-denial checks remain open under M2-02. M2 through M7 are not complete. Road planning, native reminders and sharing are not operational.

The 2026-10-18 refinement makes From/To session-only, starts Recurring collapsed, resolves mapped pin names and imports named residential areas (13,033 records). See [contributor run modes](docs/wayday/RUNNING_WAYDAY.md) and [coverage findings](docs/wayday/PLACE_COVERAGE_AUDIT.md). Interpretation remains untouched.

## Baseline

The existing Flutter app implements Today, Recurring, independent copies, notes, numeric time entry, Cornflower theme, reduced-motion transitions and transient feedback. Before this batch it used memory only; maps and planning were placeholders. Prototype checks do not verify real routing.

## Tasks

| Task ID | Component | Task Description | Status | Assignee | Completed Date |
| --- | --- | --- | --- | --- | --- |
| M0-01 | Documentation | Publish approved plan, board and scope decisions | [x] DONE | inveteratus01 (@pu-roi) | 2026-10-17 |
| M0-02 | Verification | Reconcile existing UI baseline with executable checks | [x] DONE | inveteratus01 (@pu-roi) | 2026-10-17 |
| M1-01 | Database | Drift schema, seeding, serialized writes, recovery and restart tests | [x] DONE | inveteratus01 (@pu-roi) | 2026-10-17 |
| M1-02 | Mobile | Durable Today/Recurring, stable IDs and independent copies | [x] DONE | inveteratus01 (@pu-roi) | 2026-10-17 |
| M1-03 | Mobile | Structured places, saved places, duration and trip date/time zone | [x] DONE | inveteratus01 (@pu-roi) | 2026-10-17 |
| M1-04 | Planning | Editable rule suggestions and ambiguity/correction corpus | [x] DONE | inveteratus01 (@pu-roi) | 2026-10-17 |
| M1-05 | Android | Verify persistence after process restart and offline use on Android | [x] DONE | inveteratus01 (@pu-roi) | 2026-10-17 |
| UI-01 | UI | Remove demo loading, simplify Today and refine Settings | [x] DONE | inveteratus01 (@pu-roi) | 2026-10-17 |
| UI-02 | UI | Animate module navigation and add Jace Bellen sample Profile | [x] DONE | inveteratus01 (@pu-roi) | 2026-10-17 |
| UI-03 | Verification | Android visual review, reduced motion and accessible layout checks | [x] DONE | inveteratus01 (@pu-roi) | 2026-10-17 |
| M2-01 | Feasibility | Measure local data/routing prerequisites and document pilot setup | [x] DONE | inveteratus01 (@pu-roi) | 2026-10-17 |
| M2-02 | Maps | MapLibre, attribution, manual pins and foreground location | [-] IN_PROGRESS | inveteratus01 (@pu-roi) |  |
| M2-03 | Backend | FastAPI search, PostGIS schema and regional OSM import | [x] DONE | inveteratus01 (@pu-roi) | 2026-10-17 |
| M2-04 | Data | Verify pilot places, hours and correction behavior | [-] IN_PROGRESS | inveteratus01 (@pu-roi) |  |
| M2-05 | Mobile | Manual map-backed itinerary review, reorder, priority and place changes | [x] DONE | inveteratus01 (@pu-roi) | 2026-10-17 |
| M2-06 | Places UI | Search-first chooser, full-screen center pin, portrait lock and responsive location cancellation | [x] DONE | inveteratus01 (@pu-roi) | 2026-10-17 |
| M2-07 | Mobile/Data | Session-only endpoints, collapsed Recurring, named map pins and residential search | [x] DONE | inveteratus01 (@pu-roi) | 2026-10-18 |
| M2-08 | UI/Docs | Find your way placeholder and external-navigation trip-flow roadmap | [x] DONE | inveteratus01 (@pu-roi) | 2026-10-18 |
| M3-01 | Routing | Regional Valhalla graph and five-profile validation | [ ] TODO | | |
| M3-02 | Planning | OR-Tools branches, constraints and independent schedule validation | [ ] TODO | | |
| M3-03 | Mobile | Real map/timeline, branch override and saved itinerary | [ ] TODO | | |
| M4-01 | Trips | Active itinerary, manual arrival/Done, progress and remaining-trip replanning | [ ] TODO | | |
| M4-02 | Reminders | Local nudges, snooze and stale-reminder cancellation | [ ] TODO | | |
| M4-03 | Android | Physical journey, background, permissions and battery evaluation | [ ] TODO | | |
| M4-04 | Navigation | Per-leg Google Maps/Waze handoff and return-to-itinerary recovery | [ ] TODO | | |
| M5-01 | Hosting | Public HTTPS, zero-spend limits, access control, backups and recovery | [ ] TODO | | |
| M5-02 | Sharing | Sharing-only sign-in, publication preview, links and revocation | [ ] TODO | | |
| M5-03 | Web | Browser viewer, navigation handoff and Android App Links | [ ] TODO | | |
| M6-01 | Tracking | Explicit live sharing, freshness and offline event outbox | [ ] TODO | | |
| M6-02 | Notifications | Follower subscriptions and deduplicated FCM alerts | [ ] TODO | | |
| M6-03 | Android | Physical background tracking and group-progress evaluation | [ ] TODO | | |
| M7-01 | Navigation | Optional embedded-guidance evaluation after external navigation works | [ ] TODO | | |
| M7-02 | Navigation | Conditional embedded guidance journey validation after a separate go-ahead | [ ] TODO | | |

## Contributor workflow

Use .agents/skills/wayday-task-tracker/scripts/track_task.py start <ID> when starting and done <ID> --notes "Checks and limitations" after verification. The tracker resolves Git identity and updates PROGRESS.md. Read the approved plan, product, architecture and task prerequisites before changing behavior. Do not infer completion from code presence.
