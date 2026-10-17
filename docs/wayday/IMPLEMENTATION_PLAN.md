# Wayday: from prototype to working trip planner

Approved by the owner on 2026-10-17. This specification is not a claim that all milestones are complete. Current delivery status lives in [PLANNING.md](../../PLANNING.md), verified results in [PROGRESS.md](../../PROGRESS.md), and sequencing in [ROADMAP.md](ROADMAP.md). Work on `rudy-branch` unless the owner requests otherwise.

## Goal and architecture

Build a working personal Android planner for a small Pasig/Ortigas pilot, followed by itinerary sharing and live trip updates. Preserve the compact Cornflower interface. Use [V2](../Asikaso-Prototype/V2.html) as the interaction reference: From → Errands → To → map and timeline → Start trip → Done/Running late. Replace its simulated routes with real geography.

| Responsibility | Technology | Purpose |
| --- | --- | --- |
| Android application | Flutter, Riverpod, GoRouter | Editing and trip dashboard |
| Personal storage | Drift over SQLite | Errands, notes, templates, places, itineraries and progress |
| Backend | FastAPI modular monolith | Places, planning, replanning and later sharing |
| Server database | PostgreSQL with PostGIS | Regional catalog and explicitly published trip data |
| Map | MapLibre with OpenFreeMap | Basemap, pins, route lines and location |
| Road calculations | Valhalla | Travel-time matrices, geometry and directions |
| Scheduling | OR-Tools | Branch choice and visits around constraints |
| Recipient alerts | Firebase Cloud Messaging | Confirmed shared-trip events |

Use local and server databases. Personal task management stays local and account-free. The server owns the regional catalog and, later, only information explicitly published through sharing. Calculation requests are not cloud backups. Keep FastAPI as one application with domain modules. PostgreSQL does not replace Valhalla's graph; Supabase does not run Python or Valhalla.

OpenFreeMap supplies tiles, not search or routing, and has no availability guarantee. Preserve attribution and handle outages. [Provider terms](https://openfreemap.org/)

## Errand interpretation

**Text → editable interpretation → real candidates → road travel times → feasible itinerary.**

“Buy groceries at any Puregold, finish before 5 PM, allow 30 minutes” means grocery shopping, flexible Puregold branches, a 30-minute visit and a completion deadline of 17:00. Compare branches against the whole day rather than choosing only the nearest one.

- Use bounded English, Filipino and Taglish rules, categories, brand aliases and saved-place names. AI remains deferred.
- Preserve original text and distinguish suggestions, defaults and user-confirmed values. Ambiguous hours must not silently become AM or PM. Title edits must not overwrite corrections.
- Quick entry starts Anytime; place, duration and constraints remain in the focused editor. Display an editable assumed duration when none was supplied; unknown duration is not zero.
- Keep free-form notes private and independent. Do not automatically turn shopping-list notes into errands.
- Place intent distinguishes specific coordinates, saved places, flexible category/brand searches and unresolved labels. A label alone is insufficient for routing.
- Account for departure, final destination/deadline, business hours, duration, waiting, dependencies and required/optional errands. Arrival and completion deadlines are distinct.
- Never silently omit required work. Explain conflicts and optional omissions. Unknown data, provider failure and timeout are not proven infeasibility. Feasible does not mean globally optimal.

## Milestones

| ID | Delivery | Completion gate |
| --- | --- | --- |
| M0 | Implementation board, verified baseline and updated scope decisions | Implemented, planned and verified capabilities are distinct |
| M1 | Drift, migrations, saved places, trip dates/time zones, structured intent and durable Today/Recurring | Restart/offline recovery and independent copies pass |
| M2 | MapLibre, pin selection, location permission, FastAPI search and regional OSM/PostGIS catalog | Actual coordinates and businesses work; unknown data remains visible |
| M3 | Regional Valhalla graph, OR-Tools, branch override and saved map/timeline | Actual roads and independently validated constraints; honest failures |
| M4 | Active itinerary, external leg navigation, explicit Done, confirmed events, replanning and local nudges | Physical Android journey, disconnection and permissions verified |
| M5 | Sharing-only authentication, expiring links, browser viewer and app links | App-free viewing and effective expiry/revocation |
| M6 | Opt-in live location, freshness, subscriptions and follower push | Background, stale location, reconnection and deduplication verified |
| M7 (optional) | Separate evaluation of embedded spoken navigation and rerouting | Owner decision before implementation, then representative physical journeys |

Begin M1 alongside a small M2 data/routing feasibility spike. Later milestones depend on these gates.

### Maps, places and routing

Import a bounded OSM extract. Retain source IDs, dates, categories, coordinates and original opening-hours text; support manual pins and sourced corrections. Public Nominatim is not an unrestricted autocomplete or business-enumeration backend. [Policy](https://operations.osmfoundation.org/policies/nominatim/)

Measure graph disk/RAM/build time and request latency before expansion. Validate walking, biking, motorcycle, sedan and pickup/light-truck behavior separately. Truck means pickup/light truck, not automatically heavy goods. Ground clearance differs from overhead vehicle height; do not claim clearance safety without engine and local-data validation.

Use a button in Wayday’s active itinerary to hand each leg to Google Maps/Waze, retaining readable coordinates/details and a fallback when neither is available. Wayday owns the itinerary, route overview, tasks and progress; the external app supplies turn-by-turn guidance. Embedded guidance is optional M7 evaluation, including platform integration, speech and background operation, rather than a release dependency. [MapLibre Navigation](https://github.com/maplibre/maplibre-navigation-android)

Extend planning coverage toward Laguna before claiming to optimize Enchanted Kingdom field trips.

## Active itinerary refinement approved 2026-10-18

For the present UI slice, replace the review action with Find your way as a placeholder only. It retains local draft-save behavior, missing-place handling and stale-review protection. No external navigation, trip state, location detection or sharing integration is implemented by this label change.

After M3 supplies a real, saved itinerary, M4 turns Find your way into the entry to an active trip screen showing the current activity, remaining stop list and next leg. Provide manual arrival, an explicit Done action for completing each errand, and per-leg Open in Google Maps / Open in Waze controls. Returning from another app must recover current progress without completing a task automatically. Persist the active itinerary and trip session independently of the session-only From/To fields in Today. Route/path and travel-mode differences between providers must remain honest; opening an external app does not prove it follows Wayday's exact path or validated vehicle restrictions.

The owner has not selected an automatic-arrival policy. Keep manual arrival available; evaluate opt-in GPS arrival suggestions later with permission/offline/accuracy checks and traveler confirmation. GPS alone must not mark an activity Done. M5 places itinerary-link sharing on this screen; M6 adds opt-in live location and follower alerts. Do not activate sharing implicitly when the user starts navigation. M7 remains optional research after this external-navigation concept is working.

## Sharing and live trip events

Publish selected itinerary data into a share session, not the entire personal database.

- Publishing and following for native alerts require sign-in. Browser viewers need only the link. Recipients are read-only; a driver can inspect stops/pickup times and open navigation.
- Preview exactly which stops, times, status and location are shared. Notes remain private by default.
- Use unguessable links, server authorization, expiry and immediate revocation. Default expiry is 24 hours, adjustable earlier. Anyone holding an active link can view its selected details.
- Store latest location rather than breadcrumb history. Remove published data within 24 hours after expiry/revocation. Exclude secrets/tokens from logs and prevent indexing/public caching.
- Build a small TypeScript/MapLibre GL JS viewer. Verified Android App Links open installed Wayday with browser fallback. [Android links](https://developer.android.com/training/app-links)

Location and activity are separate facts. Show timestamp and accuracy. GPS suggests arrival; the traveler/teacher confirms arrived, activity started, completed or departed before confirmed activity alerts. A teacher/bus phone represents group progress, not proof of each child's whereabouts.

Explicitly activate sharing, with Pause/Stop controls and an Android foreground-service notification. Pilot update targets: approximately 15 seconds moving and 60 seconds stationary; mark stale after 90 seconds without a fresh fix. These are targets, not guarantees. Queue confirmed events offline with original timestamps, coalesce location to the newest fix and never present an old fix as current.

## Personal nudges and follower alerts

Use local Android notifications for departure, visit-duration and saved-plan reminders. Use server-triggered FCM for confirmed shared-trip events, with durable events and deduplication. FCM is currently no-cost; recheck terms before adoption. [Pricing](https://firebase.google.com/pricing)

Examples: “Leave in 10 minutes to stay on schedule”; “Your planned visit has ended. Ready to leave?”; “The group has arrived at Enchanted Kingdom.” Provide Snooze, Running late and Done. Replanning cancels obsolete reminders. Nudges do not complete tasks automatically.

Evaluate exact-alarm access for requested timed reminders and provide a clearly labeled best-effort fallback. Ordinary background alarms can be delayed. Verify permissions, reboot, force-stop and battery restrictions on physical devices. [Android alarms](https://developer.android.com/develop/background-work/services/alarms)

## Interfaces, verification and operating limits

Proposed interfaces: `GET /v1/places`, `POST /v1/plans`, `POST /v1/plans/replan`; sharing publication/update/revocation, restricted snapshot reading, latest-location upload, confirmed events and subscriptions. These are proposals until implemented.

Use explicit place intent, itinerary snapshot, trip session/event, share session and reminder identities. Include dates/time zones, input revisions and stable event IDs. Reject stale responses and deduplicate retries.

Verify restart/offline editing/migrations, independent copies, ambiguous language and corrections; impossible constraints, unknown hours, unreachable/asymmetric roads, optional omissions and completed-stop replanning; tiny solver cases against exhaustive results; physical Android background/permission behavior; guest links, app fallback, note exclusion, revocation, expiry, stale data and reconnecting. Measure journey travel-time error, reminder delivery and battery use.

Run development services locally first. Before M5, require public HTTPS hosting feasibility covering availability, access controls, limits, backups and recovery. A laptop is for supervised testing while awake, not guaranteed hosting.

Supabase Free is a PostgreSQL/PostGIS/Auth candidate. Its currently listed 500 MB database limit and inactivity pausing require measurement and backups; keep the regional catalog local if necessary. It does not host Python or Valhalla. [Pricing](https://supabase.com/pricing)

Maintain zero spending. Record quotas, expiry, exhaustion and fallback; stop expansion if free infrastructure cannot support measured workloads. No purchases, billing activation or external account creation. Android first; iOS, AI, live traffic, automatic recurrence and full personal cloud synchronization remain later work.
