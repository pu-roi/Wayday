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

## Revisit before implementation or release

- Mac/iPhone access and publishing approach before the later iOS phase, rather than before Android development.
- Real place/hour coverage and corrections for the pilot area.
- Motorcycle route restrictions and accuracy of static travel estimates.
- Bicycle access, the intended truck class, vehicle parameters, and actual engine/data support for ground-clearance requirements.
- Valhalla import/runtime resource use on existing hardware.
- Exact input vocabulary, ambiguity handling, recurrence edges, and ordering semantics.
- Compatible pinned package versions and native/transitive licenses.
- Cloud API/routing compute, database size, quotas, backups, and access controls.

Update this log and affected documents when an assumption changes. Historical references remain unchanged unless their modification is requested.
