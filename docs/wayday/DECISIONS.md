# Foundation decision log

Recorded: 2026-10-15 (Asia/Manila).

**Confirmed** means explicit owner direction. **Selected recommendation** means the technical direction captured by the agreed foundation plan; it is not implemented. **Default assumption** is a planning choice that needs validation before it becomes a release promise.

## D01 — Foundation work and limited UI authorization

**Status:** Foundation restriction partially superseded by the owner's UI implementation request on 2026-10-16.

Create documentation, repository configuration, and agent skills. Application development is deferred. Do not create mobile/backend skeletons, install SDKs, or deploy services under this phase. A later request can authorize the next stage without repeating approval for work already requested.

The owner subsequently authorized creating the frontend/backend root folders. Reserve `apps/mobile/` and `services/api/` with `.gitkeep` markers only; runnable project scaffolding and internal source trees remain deferred.

On 2026-10-16 the owner authorized building the Android Flutter app shell, theme options, and Today module. That request permits mobile scaffolding and the tooling needed to build and verify it. Use example errands on first launch, as confirmed by the owner. Basic editing and navigation can work in memory; backend scaffolding, real routing, place services, persistence, reminders, deployment, and iOS are outside this milestone. A Flutter web target is a convenience for reviewing the same widgets, not a new product platform commitment.

## D02 — Wayday naming and historical Asikaso material

**Status:** Confirmed.

Use Wayday for the current project. Preserve the Asikaso abstract, prototype filenames, authorship, and screenshots. Existing references are evidence and design inputs; the owner has not finalized features or design.

## D03 — Cost preference permits free tiers and trials

**Status:** Confirmed; supersedes the original no-freemium condition.

Target zero spending. Free tiers, freemium offerings, and free trials are acceptable. Document quotas, expiry, billing prerequisites, exhaustion behavior, and an exit path before adoption. Prefer a baseline that survives trial expiry. No paid resource or billing activation is authorized by foundation work.

## D04 — Mobile target and framework

**Status:** Android first, iOS later, confirmed by the owner on 2026-10-16; Flutter is the selected recommendation and owner's preference.

Use Flutter/Dart, with Android as the first implementation and verification target. Defer iOS implementation, device verification, and distribution planning to a later phase; access to a Mac or iPhone is not an Android development prerequisite. React Native remains viable if team experience changes the tradeoff. Neither choice removes native geofence integration or macOS requirements for eventual iOS builds. Access to a Mac and distribution arrangements are not established.

## D05 — AI deferred; limited rules remain possible

**Status:** Confirmed.

Defer AI-based interpretation. Use limited, editable rules for explicit English, Filipino, and Taglish phrases. Distinguish suggestions from user-confirmed constraints and retain structured input. Local models can exist without paid keys, but that possibility is not a requirement to add them. OR-Tools optimization is an algorithm library, not a paid AI service.

## D06 — Transportation scope

**Status:** Confirmed owner clarification, 2026-10-15; supersedes the earlier sedan/truck deferral and three-mode assumption.

Plan five transportation profiles: walking, biking, motorcycle (motor), sedan (low clearance), and truck (high clearance). Public commute is excluded. One profile per trip remains the planning default.

The profiles are product requirements; their routing implementation is still subject to feasibility work. Distinguish ground clearance from overall height, confirm the truck class and any numeric dimensions, and validate local road/surface/access data before advertising clearance-aware routing. Do not assume “high clearance” means a heavy goods vehicle or permission to traverse restricted roads. The abstract and prototype retain their historical scope descriptions.

## D07 — Offline scope and reminders

**Status:** Confirmed.

Support saved trips and tasks offline rather than full fresh regional planning. Keep templates, saved places, progress, downloaded map coverage, and local reminders on the phone. Background location reminders are desired with acknowledged OS limits. Fresh discovery and full replanning need the backend; permission denial and service loss require visible fallback.

## D08 — Frontend and backend structure

**Status:** Selected recommendation.

Use Flutter features with MVVM/repositories and a FastAPI modular monolith containing domain services. This keeps related code together without managing a separate deployed service for every feature. Use Riverpod, Drift/SQLite, PostgreSQL/PostGIS, Valhalla, and OR-Tools as described in the stack inventory.

Revisit after feasibility measurements or a concrete team constraint. Domain services are not a commitment to microservices. The owner-requested application roots are reserved; create further internal directories when their implementation is authorized and needed.

## D09 — Local backend first, cloud later

**Status:** Confirmed direction; specific cloud provider remains undecided.

There is no dedicated server. Start the future backend on the existing computer during development/demos. Phones need network access to it for fresh backend operations. Evaluate cloud deployment later; Supabase Cloud is an allowed candidate for PostgreSQL/PostGIS under D03. Python and Valhalla hosting remain separate decisions.

## D10 — Maps, roads, and planning are separate

**Status:** Selected recommendation.

Use MapLibre/OpenFreeMap for map display, regional OSM-derived places in PostGIS, Valhalla for road routes/matrices, and OR-Tools for branch/stop scheduling. Defer live traffic. Keep public demo/community endpoint policies separate from software licenses and avoid assuming unlimited shared service capacity.

## D11 — Pilot region and personal data

**Status:** Default assumptions.

Start feasibility in Pasig/Ortigas, based on the supplied prototype and examples. Keep personal tasks/progress local; do not add accounts or cross-device synchronization initially. Keep service calculations transient and avoid sensitive request logging. Expand scope only when there is a product need and operating capacity.

## D12 — Preserve provisional UI direction

**Status:** Selected reference, not finalized design.

Use V2's compact list, focused editor, recurring groups, and map/timeline as the current reference. Preserve the From/Errands/To concept. The new product request still permits ordinary notes/bullet input; exact composition flow and “on the way home” semantics remain to refine before implementation. Do not copy prototype fake coordinates, time heuristics, or in-memory persistence into a production claim.

## D13 — Repository licensing remains undecided

**Status:** Default boundary pending ownership decision.

Do not choose a license for the team's original work automatically. Record third-party licenses separately, including map data and any future fonts/assets. Creating this foundation does not grant redistribution rights to all supplied material.

## D14 — Today UI and palette options

**Status:** Initial owner-requested reference direction, 2026-10-16; appearance options superseded by D15.

Adapt V2's From/Errands/To structure into a clean Android Flutter screen with a compact numbered list. The supplied image informs spacing, quiet surfaces, and primary-action hierarchy; its booking/payment functionality is outside Wayday's requirements. Offer Canvas, Blue, and Ink appearance choices using the supplied Canvas `#FBFBF8`, Mist `#DBE3E9`, Cornflower `#6AA6DA`, and black references. Interpret the supplied five-digit black value as `#000000`. Use a darker derived blue when text contrast requires it. Preserve historical prototype files and screenshots.

## D15 — Refined MVP interface and Recurring

**Status:** Confirmed owner refinement, 2026-10-16.

Use one light Cornflower/Canvas theme; remove dark/light mode selectors and alternate palette choices from the MVP. Keep the interface clean and refined. Replace the default clock dial with numeric hour/minute entry, AM/PM, and quick choices. Keep quick add simple and default to Anytime, with customization on a separate focused screen. Group Leave, Home by, and Travel within the route surface.

Provide map buttons for From, To, and errand locations. They open an explicitly illustrative placeholder with manual place names; no geocoding, search, live map, or routing capability is implied.

Implement Recurring using the same compact numbered errand structure as Today. Support named reusable lists, direct item editing, draft group editing, create/delete/undo, descriptive repeat settings, and manual Add to Today. Copies retain timing and priority, receive independent IDs, and preserve source item IDs to prevent duplicate addition. Today edits must not rewrite a source group. Automatic recurrence and durable storage remain deferred.

## D16 — Errand notes, motion, and transient feedback

**Status:** Confirmed owner refinement, 2026-10-16.

Keep optional free-form, multiline notes inside the focused errand editor, shared by Recurring and Today. A compact note icon indicates that details exist without expanding the main list. Notes copy into Today with the other errand fields; subsequent edits remain independent. Notes are plain text and stay in memory for this prototype; interactive shopping checklists and durable storage are not implemented.

Animate row insertion/removal and list disclosure with short, interruptible transitions. Preserve the quick-add field and keyboard focus during consecutive entries, and keep the composer visible as rows grow. Today, Recurring group headers, and repeat details use coordinated expansion; honor the platform's Remove animations preference.

Use a shared, themed floating Material snackbar for in-app feedback. Ordinary messages expire after four seconds; messages with Undo expire after six seconds and replace stale feedback rather than queueing it. Preserve actionable messages when the platform requests accessible navigation. These messages are separate from the deferred Android reminder/notification integration.

## D17 — Functional planner implementation and sequencing

**Status:** Confirmed owner approval, 2026-10-17; supersedes earlier UI-only deferrals.

Implement [the approved plan](IMPLEMENTATION_PLAN.md) in milestones M0–M7, beginning with durable local errands and a small regional data/routing feasibility spike. Start with a private Pasig/Ortigas pilot. Use a map/dashboard before embedded turn-by-turn guidance; hand off navigation legs initially. Truck means pickup/light truck, subject to access and dimensional validation rather than automatic heavy-goods costing. AI, live traffic, automatic recurrence, iOS and full cloud synchronization remain deferred.

## D18 — Sharing boundaries

**Status:** Confirmed owner direction, 2026-10-17; narrowly extends the previous account/cloud deferral.

Personal planning stays local and account-free. Publishing and following for native alerts require sign-in. Browser viewing uses a read-only expiring link without installation/login. Publish only previewed fields; notes stay private by default. Default expiry is 24 hours, adjustable earlier; revoke immediately and remove published data within 24 hours after expiry/revocation. Store latest location rather than breadcrumb history. Teacher/bus-phone sharing represents group progress, not each child's presence. GPS suggests arrival; the traveler/teacher confirms activity before confirmed recipient alerts. Explicit sharing controls, freshness, offline event deduplication and Android foreground verification are required.

## D19 — Personal persistence and interpretation defaults

**Status:** Implementation defaults for M1, 2026-10-17.

Store the active day draft, Recurring and saved places in a versioned, transactional Drift/SQLite workspace. This first storage release has one active dated draft, not a multi-day calendar. Keep its chosen date on restart; do not silently discard yesterday's work. The pilot uses Asia/Manila explicitly. Fifteen minutes is an editable assumed visit duration, not an observed fact. Save original text, confirmed fields, structured unresolved/specific/saved/search intent and input revision. Rule suggestions are reviewed explicitly in the editor; quick entry stays Anytime. Save failures stay visible and retryable. Never reseed malformed or unsupported saved data. Native Android automatic backup is disabled to preserve the local-only default. Browser storage belongs to its origin and is independent of Android storage.

## D20 — Pre-map interface refinement and sample identity

**Status:** Confirmed owner refinement, 2026-10-17.

Remove example-day loading from Today and Settings. A new workspace begins with an empty day; existing saved data is preserved. Use a compact, left-aligned inline prompt instead of a large empty-state headline. Expose Clear with Undo as a labeled action when errands exist.

Keep Today, Recurring, Profile and Settings as labeled shell destinations. Module changes, including Add from a recurring list, use the shared short fade and slight slide while navigation stays fixed; Remove animations makes the change immediate. Preserve the established Figtree and light Cornflower system.

Profile is a read-only local sample named Jace Bellen, selected by the owner. Unset email, phone and home area are explicit; no invented contact details, edit affordances, authentication or operational sharing are implied. Real identity and sharing remain tied to the later sharing milestones. Settings describes local storage, time zone and current limitations.
## D21 — Manual map and pre-trip review before interpretation integration

**Status:** Confirmed owner scope, 2026-10-17; supersedes the earlier illustrative-map boundary.

Implement a real MapLibre/OpenFreeMap map with manual pins, coordinate entry, saved-place selection and opt-in one-time foreground location. Keep interpretation unchanged and independently owned by another contributor. Do not introduce a public search endpoint or simulated business alternatives. Retain provider attribution and an honest map-failure fallback.

Plan my day opens a V2-inspired vertical draft review: fixed endpoints, reorderable errands, required/optional priority and focused place changes. Provide move controls as an alternative to dragging. Preserve original text, notes, timing and dependencies. Confirmation saves the reviewed day with a revision guard; Back discards it. Unresolved places may be saved as a draft. Never imply optimized order, checked hours, arrival times or live trip execution. The full M2 catalog and M3 scheduling gates remain outstanding; see [the integration handoff](MAP_REVIEW_HANDOFF.md).

## D22 — Search-first places and explicit local pilot read model

**Status:** Confirmed owner refinement and implementation choice, 2026-10-17; supersedes D21's manual-only chooser boundary.

Use a familiar search list for place names, landmarks and addresses, followed by a dedicated full-screen map with a fixed center pin. Results supply their own names. Remove custom-name and coordinate-entry forms; coordinates may be read-only. A manual selection is a Dropped pin, with nearby landmarks as context rather than a fabricated address or entrance. Preserve saved places, including distinct branches with the same displayed name. Keep interpretation unchanged.

Implement a local FastAPI places module and import bounded OSM source data. PostgreSQL/PostGIS remains the target catalog store. An explicitly configured, bounded file snapshot read model supports local development while the existing Docker engine is unavailable. It is not an automatic failover and does not add another personal database. Retain the PostGIS schema/adapter as a separate runtime gate; do not claim full M2 completion from the file-mode implementation. No public community search endpoint, account, billing or deployment is introduced. See [the local service guide](../../services/api/README.md).

Bound the complete location wait, provide Cancel, ignore stale search/location results and allow manual selection during failures. Use Android TextureView map composition for Flutter overlays. Emulator renderer issues remain distinct from physical GPS accuracy and do not justify a permanent production renderer opt-out.

## D23 — Portrait-only Android application

**Status:** Confirmed owner direction, 2026-10-17.

Lock Wayday to upright portrait on the supported Android phone, including startup. Landscape is not an application feature; do not develop a separate landscape layout. Keep larger-text, keyboard and scrolling checks in portrait. Verify that device rotation does not rotate the app. The native activity requests portrait and Flutter applies portraitUp before starting the UI. Android 16 can override orientation restrictions on large displays at least 600 dp wide; that platform exception is outside the current phone target and is not a verified tablet release. Browser previews remain development surfaces rather than a promise of landscape mobile support.

## D24 — Verified local PostGIS runtime and contributor handoff

**Status:** Owner-authorized M2-03 completion, 2026-10-17; updates D22's temporary runtime limitation.

Use local PostgreSQL/PostGIS as the default catalog mode now that Docker is operational and the runtime checks passed. Keep file mode explicit (`start-places.ps1 -Mode file`), never automatic failover. Scripts must reject a server already running in another mode. Persist local credentials through Windows-user DPAPI under ignored `data/local`; do not include passwords or connection URLs in tracked files, mobile code or logs. Each contributor creates their own local credential and catalog.

Repeat imports, same-extract snapshot removals, correction retention, transaction rollback, metric query plans and outage/restart recovery passed against actual PostGIS. Use isolated synthetic databases for destructive verification rather than clearing the pilot catalog. Source-date readiness describes the active catalog. Keep search corrections source-linked and separate from imported data; the current correction table supports aliases only.

This batch leaves interpretation implementation, related Flutter behavior and tests unchanged. M2-04 field coverage and M2-02 physical-location checks remain open. No route graph, scheduling, hosting, account, billing or public deployment is implied. See [the handoff](M2_DATABASE_HANDOFF.md).

## D25 — Session endpoints, collapsed lists and mapped pin identity

**Status:** Confirmed owner direction, 2026-10-18; revises draft-endpoint persistence in M1 and D22's generic moved-pin label.

From and To belong to the running application session, clear on cold launch or Flutter hot restart, and are excluded from future personal snapshots. Legacy persisted endpoints are removed during hydration after all workspace sections validate. Preserve errands, their places, notes, saved places, templates, date and other trip settings. Background/resume and module navigation do not reset the session. Recurring groups start collapsed; disclosure state is a view concern, not template metadata.

Retain imported OSM MultiPolygon footprints for mapped-area identity. Name a manual pin from a unique containing place, or otherwise a unique mapped point within 10 metres; prefer mapped areas over nearby points, exclude broad city/place boundaries, and require explicit choice for ambiguity or merely nearby landmarks. Keep the chosen coordinates and explicit coordinate-kind metadata. Unknown/offline matches remain usable as Dropped pin. No match verifies an entrance or current opening hours. Migration 002 is additive and optional footprints preserve compatibility with older point-only snapshots.

Include named residential areas and place/neighbourhood records in the bounded importer. Grand Monaco La Impreza was already in the source extract but excluded by the prior category filter; importing its actual source record fixes the reported omission without guessed data. M2-04 still requires real coverage and correction checks. The lookup and UI changes do not modify errand interpretation. Contributors can run app/local tests without Docker, use explicit file-mode search without Docker, or run the full local PostGIS stack. See [the run guide](RUNNING_WAYDAY.md).

## D26 — Active itinerary with external leg navigation

**Status:** Owner direction, 2026-10-18. Current implementation scope is the review action label only; trip behavior below is planned.

Use Find your way as the review action placeholder for both fully pinned and incomplete drafts. Preserve the existing local commit, stale-revision guard, disabled states and honest draft/missing-place copy. It does not yet open an active trip or start tracking.

M3 provides real route/timeline data and a durable reviewed snapshot. M4 provides the active itinerary, manual arrival, explicit Done per errand, next-stop progression and per-leg Google Maps/Waze launch with return-to-trip recovery. Wayday keeps the overview and progress while external apps handle navigation. Opening/returning from navigation is not proof of arrival or completion, and external paths may differ from Wayday's estimates/restrictions. Restore active trips independently of session-only Today endpoints. The automatic-arrival policy remains open; any later GPS-based suggestion needs opt-in, confirmation and manual fallback.

Add sharing entry points in M5 for links and M6 for opt-in live sharing/confirmed-event alerts. Starting navigation never starts sharing. Embedded turn-by-turn guidance remains optional later evaluation, not a prerequisite for the selected external-navigation workflow. See [the updated roadmap](ROADMAP.md) and [implementation plan](IMPLEMENTATION_PLAN.md).

## Remaining release checks

- Mac/iPhone access and publishing approach before the later iOS phase, rather than before Android development.
- Real place/hour coverage and corrections for the pilot area.
- Motorcycle route restrictions and accuracy of static travel estimates.
- Bicycle access, the intended truck class, vehicle parameters, and actual engine/data support for ground-clearance requirements.
- Valhalla import/runtime resource use on existing hardware.
- Exact input vocabulary, ambiguity handling, recurrence edges, and ordering semantics.
- Compatible pinned package versions and native/transitive licenses.
- Cloud API/routing compute, database size, quotas, backups, and access controls.

Update this log and affected documents when an assumption changes. Historical references remain unchanged unless their modification is requested.
