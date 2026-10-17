# Wayday roadmap and delivery status

Last updated: 2026-10-18. The owner approved [the implementation plan](IMPLEMENTATION_PLAN.md). This document describes sequencing; [PLANNING.md](../../PLANNING.md) owns task status and [PROGRESS.md](../../PROGRESS.md) records actual checks. A task is not complete solely because source exists.

## Current delivery

**M0 and M1 complete; M2 maps, manual review and local pilot place search are implemented, with M2-03 PostGIS runtime verification complete and physical-location/coverage gates still open.** M2 prerequisite findings are recorded in [FEASIBILITY.md](FEASIBILITY.md). Later milestone gates remain outstanding.

The Android Flutter shell, Today, Recurring, notes and list interactions already exist. M1 adds local Drift persistence, versioned storage, stable IDs, saved places, structured place intent, duration, date/time-zone metadata and reviewed rule suggestions. Verification results and platform limitations are recorded in the progress log. Real map display and manual pins connect to an editable vertical day review. Bounded local catalog search is implemented with real OSM data. PostGIS runtime verification is complete; field coverage checks, physical-location checks, branch recommendations, road routes, trip execution and native reminders remain pending. See [the database handoff](M2_DATABASE_HANDOFF.md). The owner confirmed map/manual review first, independently of another contributor’s interpretation work; see [the handoff](MAP_REVIEW_HANDOFF.md). This does not complete M2 or M3. The local FastAPI service is documented in [its guide](../../services/api/README.md); no public service is deployed.

## Milestones

| Stage | Delivery | Gate |
| --- | --- | --- |
| M0 | Contributor plan, task board, reconciled baseline and decisions | Documentation distinguishes implemented and verified work |
| M1 | Durable personal errands, Recurring, notes, saved places and structured input | Restart/offline tests, independent copies, safe failure and Android verification |
| M2 | Real MapLibre map and bounded regional OSM/PostGIS place search | Attribution, actual coordinates, coverage/hours honesty and local infrastructure readiness |
| M3 | Valhalla matrices/geometry and OR-Tools branch/time scheduling | Regional resource benchmark, five-profile validation, independently checked schedules |
| M4 | Active itinerary, per-leg external navigation, confirmed progress, replanning and local nudges | Physical Android journey, permission, background, battery and disconnection checks |
| M5 | Expiring itinerary links, sharing-only sign-in and browser viewer | Public HTTPS/zero-spend hosting gate, authorization, expiry/revocation and app-link fallback |
| M6 | Explicit live location and follower event alerts | Freshness, offline event outbox, FCM deduplication and physical background verification |
| M7 (optional) | Evaluate embedded guidance only after the external-navigation experience works | Separate decision before implementation; native/off-route and physical-route checks if pursued |

## Immediate sequence

M1 is complete. Finish M2-02 physical-location checks and M2-04 place-quality checks; M2-03 local database runtime is verified. Start with one local active dated draft, not a calendar/history product. Keep Asia/Manila explicit. Manual saved labels remain unresolved until a real coordinate is chosen. English/Filipino/Taglish suggestions require review and do not silently replace corrected fields.

For M2, measure a bounded Pasig/Ortigas catalog and routing graph on existing hardware. Import regional OSM extracts rather than using community endpoints as the application's catalog. Preserve provenance, unknown hours and manual corrections. Do not fill failed searches with simulated businesses.

For M3, validate walking, biking, motorcycle, sedan and pickup/light truck separately. Ground clearance is not overhead height or permission to ignore restrictions. Use Google Maps/Waze handoff as the planned navigation experience. Embedded guidance is optional later work, not a requirement for releasing the itinerary workflow. Extend coverage toward Laguna before promising field-trip optimization there.

## Planned Find your way journey

The current change is a label-only placeholder: Find your way still saves the reviewed draft with existing guards and does not start a trip. The stages below are planned work.

- **M3:** calculate and save an actual road-based map/timeline and reviewed itinerary snapshot.
- **M4:** Find your way opens an active itinerary with the current stop, remaining errands and next destination. A per-leg Open in Google Maps / Open in Waze action launches external guidance. Returning to Wayday restores the same progress; opening navigation does not mark arrival or completion. Preserve a readable address/coordinate fallback if no navigation app is available. An active trip resumes from its durable itinerary snapshot independently of session-only Today endpoints.
- **M4 arrival/completion:** manual I'm here remains available. Whether/how GPS detects arrival is still an open decision; any future detection is an opt-in suggestion with manual fallback. The user explicitly marks Done to finish an errand and advance to the next task. Leaving a navigation app or crossing a geofence never silently completes work.
- **M5:** add itinerary-link publishing/revocation and the share action to the trip screen.
- **M6:** add opt-in live location and confirmed-event follower alerts through the same share entry point.
- **M7 (optional):** evaluate embedded spoken guidance separately. The map overview stays inside Wayday while external apps provide the planned turn-by-turn experience.

## Sharing and operating gates

Personal planning remains local and account-free. Sharing publishes selected fields only; notes remain private by default. Owners/followers sign in for publication/native alerts, while guest links work in browsers. Defaults: 24-hour expiry, immediate revocation, latest location only, stale after 90 seconds, explicit Pause/Stop and confirmed activity events. Teacher/bus location represents group progress. See the implementation plan for retention, update targets and event rules.

Before public sharing, validate HTTPS, access controls, quotas, backups, recovery and compute capacity. Supabase is a possible database/Auth provider, not Python or Valhalla hosting. A sleeping laptop is an unavailable backend. Maintain zero spending; no billing, accounts or public deployment are part of the current local implementation batch.

## Deferred

Android first. iOS, AI, live traffic, automatic recurrence and full personal cloud synchronization remain later work. Fresh offline route optimization remains deferred. Public commute is excluded. Embedded navigation is optional M7 work and is not a dependency of the active itinerary or external navigation handoff.
