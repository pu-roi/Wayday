# Wayday roadmap

This roadmap describes sequencing. The owner has authorized the Android UI shell, Today, and in-memory Recurring module; later backend, planning, persistence, automatic recurrence, and platform milestones still require their own implementation scope.

## Stage 0: foundation — established

Deliver repository guidance, configuration, stack evaluation, product boundaries, architecture, cost/data inventory, setup guidance, and focused agent skills for UI, mobile integration, backend services, API contracts, databases, and itinerary planning. Preserve the abstract, both HTML prototypes, and screenshots.

Reserve the owner-requested frontend/backend roots at `apps/mobile/` and `services/api/` with `.gitkeep` markers. Internal application structure and runnable scaffolding remain future work.

Exit checks: documents agree on scope, local links resolve, skills validate, source references remain trackable, and prototype checks still pass. No app/backend scaffolding or installations are included.

## Stage 1: feasibility — future

Before building full workflows:

- Start feasibility on Android. Defer macOS/iPhone access and iOS verification to the later iOS phase; they do not block Android work.
- Assess regional OSM coverage for the owner's example errands, including wet markets, barbers, and coffee shops; inspect actual opening-hours coverage.
- Measure whether a small Valhalla graph and PostGIS catalog fit existing hardware. Validate walking, biking, motorcycle, sedan, and truck routing against sampled local journeys and restrictions.
- Establish the truck class, required vehicle parameters, and available road/surface data. Investigate the low/high ground-clearance requirement separately from overhead height restrictions; document unsupported checks before promising clearance-aware routing.
- Verify MapLibre offline downloads on Android under provider limits, including all style resources. Verify iOS cache behavior in the later iOS phase.
- Demonstrate background reminders on physical devices with denial, reboot, and termination cases.
- Define a small English/Filipino/Taglish rule corpus with expected output and ambiguous cases. Do not reintroduce AI as a hidden prerequisite.

Exit: record measured results, limitations, and any required changes to the chosen stack. Validate all five profiles or record a product decision for any unsupported capability. Do not promise global coverage, live traffic, clearance suitability, or motorcycle-route reliability from a successful demo alone.

## Stage 2: scaffold and local task management — UI shell implemented; persistence remains future work

An initial Android UI shell can be built before routing, place-data, offline-map, and reminder feasibility is complete, once application development is authorized. Recreate the provisional V2 interactions in Flutter: Today with From/Errands/To, a focused errand editor, recurring templates, settings, and a sample plan timeline. Use in-memory data and explicitly labeled sample plan results. Basic navigation, editing, and template copying can work without a backend. Use a map placeholder initially. This milestone validates the interface and Android behavior; it does not establish routing feasibility or persistent offline support.

Current authorized subset: app shell, single light Cornflower theme, Today, and in-memory Recurring lists. Template management and independent manual copies to Today are implemented. Place entry uses an illustrative map preview; time entry uses numeric fields. Planning shows its unavailable state. Durable storage, automatic recurrence, real map integration, and plan results remain future work.

Create the Flutter/FastAPI projects and local infrastructure only after development is authorized. Pin compatible versions and add working commands. Build local errands, templates, saved places, structured corrections, persistence, and basic platform permissions before integrating the full planner.

For a UI-only milestone, scaffold only the Flutter application and leave FastAPI and local data services for the work that needs them. Add durable local persistence after the initial in-memory editing flow is usable.

Exit: tasks and progress survive restart and connectivity loss; template copies stay independent; basic checks run locally.

## Stage 3: place discovery and itinerary planning — future

Import the regional place catalog, integrate Valhalla matrices, and implement OR-Tools scheduling behind the documented API boundaries. Add branch override, infeasibility reporting, and remaining-trip replanning. Store itineraries for offline reading.

Exit: mandatory timing/dependencies hold, optional omissions are explained, timeout/outage statuses remain honest, and tiny cases match exhaustive baselines. Route geometry and travel estimates use real regional data.

## Stage 4: reminders and field evaluation — future

Integrate native geofences, local time reminders, and downloaded map coverage with the saved trip. Refine the UI using the prototype as a reference and test with representative users.

Exit: physical-device background behavior is documented; offline fallback works; route efficiency, completion, travel-time error, and user feedback are measured against a stated baseline.

## Stage 5: deployment decision — future

Evaluate free-tier hosting using measured workloads. Supabase is a candidate for the database, not a complete deployment for Python planning and Valhalla. Establish access controls, TLS, rate limits, backups, quota handling, and trial exit paths before public exposure.

Exit: the complete deployment has a documented operating cost, limits, recovery path, and Android/iOS distribution plan. No permanent zero-cost hosting guarantee is assumed.

## Deferred research

AI interpretation, live traffic, full offline route computation, account synchronization, and in-app turn-by-turn navigation require separate product and feasibility decisions. Public commute, including jeepney/bus/rail journey planning, is excluded from current scope. Sedan/truck profiles and clearance feasibility belong to the active transportation scope above.
