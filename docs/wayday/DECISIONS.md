# Foundation decision log

Recorded: 2026-10-15 (Asia/Manila).

**Confirmed** means explicit owner direction. **Selected recommendation** means the technical direction captured by the agreed foundation plan; it is not implemented. **Default assumption** is a planning choice that needs validation before it becomes a release promise.

## D01 — Foundation work and limited UI authorization

**Status:** Foundation restriction partially superseded by the owner's UI implementation request on 2026-10-16.

Create documentation, repository configuration, and agent skills. Application development is deferred. Do not create mobile/backend skeletons, install SDKs, or deploy services under this phase. A later request can authorize the next stage without repeating approval for work already requested.

The owner subsequently authorized creating the frontend/backend root folders. Reserve `apps/mobile/` and `services/api/` with `.gitkeep` markers only; runnable project scaffolding and internal source trees remain deferred.

On 2026-10-16 the owner authorized building the Android Flutter app shell, theme options, and Today module. That request permits mobile scaffolding and the tooling needed to build and verify it. Use example errands on first launch, as confirmed by the owner. Basic editing and navigation can work in memory; backend scaffolding, real routing, place services, persistence, reminders, deployment, and iOS are outside this milestone. A Flutter web target is a convenience for reviewing the same widgets, not a new product platform commitment.

On 2026-10-26 the owner authorized continuing runtime development after the shell was complete. D17 records the next local-persistence slice; it does not authorize backend, routing, place services, reminders, deployment, or iOS work.

On 2026-10-27 the owner requested a documentation audit and implementation plan for real user data, consistent controls, Philippine maps/places, saved trips, and Google Maps handoff. D18–D22 record the revised direction. This request starts documentation/planning, not runtime implementation.

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

Support saved trips and tasks offline rather than full fresh regional planning. Keep templates, saved places, progress, downloaded map coverage, and local reminders on the phone. Background location reminders are desired with acknowledged OS limits. The original direction placed fresh discovery and full replanning behind the backend. D19 revises initial regional discovery to permit an installed local catalog; later automatic road-based replanning remains conditional on backend/routing feasibility. Permission denial and service loss require visible fallback.

## D08 — Frontend and backend structure

**Status:** Selected recommendation.

Use Flutter features with MVVM/repositories and a FastAPI modular monolith containing domain services. This keeps related code together without managing a separate deployed service for every feature. Use Riverpod, Drift/SQLite, PostgreSQL/PostGIS, Valhalla, and OR-Tools as described in the stack inventory.

Revisit after feasibility measurements or a concrete team constraint. Domain services are not a commitment to microservices. The owner-requested application roots are reserved; create further internal directories when their implementation is authorized and needed.

## D09 — Local backend first, cloud later

**Status:** Confirmed direction; specific cloud provider remains undecided.

There is no dedicated server. Start the future backend on the existing computer during development/demos. Phones need network access to it for fresh backend operations. Evaluate cloud deployment later; Supabase Cloud is an allowed candidate for PostgreSQL/PostGIS under D03. Python and Valhalla hosting remain separate decisions.

## D10 — Maps, roads, and planning are separate

**Status:** Historical recommendation; map/provider and initial catalog choices superseded by D19. Later routing/solver candidates remain subject to feasibility.

The original recommendation was MapLibre/OpenFreeMap for map display, regional OSM-derived places in PostGIS, Valhalla for road routes/matrices, and OR-Tools for branch/stop scheduling. Defer live traffic. Keep public demo/community endpoint policies separate from software licenses and avoid assuming unlimited shared service capacity.

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

Implement Recurring using the same compact numbered errand structure as Today. Support named reusable lists, direct item editing, draft group editing, create/delete/undo, descriptive repeat settings, and manual Add to Today. Copies retain timing and priority, receive independent IDs, and preserve source item IDs to prevent duplicate addition. Today edits must not rewrite a source group. D17 supersedes this decision's earlier deferral of durable storage; automatic recurrence remains deferred.

## D16 — Errand notes, motion, and transient feedback

**Status:** Confirmed owner refinement, 2026-10-16.

Keep optional free-form, multiline notes inside the focused errand editor, shared by Recurring and Today. A compact note icon indicates that details exist without expanding the main list. Notes copy into Today with the other errand fields; subsequent edits remain independent. Notes are plain text; interactive shopping checklists remain unimplemented. D17 supersedes the in-memory-only storage boundary for notes and other Today/Recurring fields.

Animate row insertion/removal and list disclosure with short, interruptible transitions. Preserve the quick-add field and keyboard focus during consecutive entries, and keep the composer visible as rows grow. Today, Recurring group headers, and repeat details use coordinated expansion; honor the platform's Remove animations preference.

Use a shared, themed floating Material snackbar for in-app feedback. Ordinary messages expire after four seconds; messages with Undo expire after six seconds and replace stale feedback rather than queueing it. Preserve actionable messages when the platform requests accessible navigation. These messages are separate from the deferred Android reminder/notification integration.

## D17 — Local persistence for Today and Recurring

**Status:** Confirmed owner authorization, 2026-10-26; implemented and verified 2026-10-27.

Persist Today settings and errands, plus Recurring groups and their items, in an on-device Drift/SQLite database. Seed the example day and example groups only when the database has no saved Today settings; do not repopulate intentionally emptied lists on later launches. Preserve item order, timing, notes, repeat metadata, source group/item IDs, and independent Today copies. Keep the browser preview in memory. Do not add cloud synchronization, accounts, a backend, or automatic recurrence as part of this slice. Flutter analyzer and tests pass; ARM64 and x86_64 debug APKs build successfully. Today and Recurring data survived force-stop and relaunch on an API 37 x86_64 emulator on 2026-10-27.

## D18 — User-created startup data

**Status:** Implemented and verified in Stage 1, 2026-10-27; see M2-01 and M2-04 in Progress.

Remove production sample errands/lists, example-reset actions, and fabricated endpoint defaults. Start new Android databases and browser previews empty; examples may remain as explicit test fixtures. Preserve existing stored rows because their origin and user edits cannot be safely inferred from sample IDs or titles. D18 supersedes D17's future first-launch example seeding without changing its persistence implementation or verification history.

## D19 — Open mapping and regional place search

**Status:** Selected direction for the requested implementation plan, 2026-10-27; packages and coverage not yet verified in Wayday.

Use MapLibre for rendering, Protomaps regional PMTiles and local style assets for the basemap, a custom Wayday map design, and a separate searchable OSM POI catalog. Overture may supplement records only after measured pilot coverage, provenance, deduplication, and license checks. Begin with Pasig/Ortigas; no nationwide completeness claim is established.

OSM data does not require the default openstreetmap.org appearance. The owner rejected OpenFreeMap as the preferred design/provider direction; do not reinstate it or adopt MapTiler Cloud as the default without a new reason and recorded decision. Free/open software does not guarantee free hosting, distribution, or updates. Favor existing hardware and bounded local packages, with no account, billing, purchase, or public deployment implied.

Public Overpass is for bounded exploration rather than the consumer app backend. Public Nominatim prohibits autocomplete and systematic POI enumeration. Regional package refresh is public-data maintenance, not account/cloud synchronization of personal errands.

## D20 — Consistent selection controls

**Status:** Implemented and verified on the API 37 x86_64 Android emulator, 2026-10-27; physical-device and TalkBack checks remain unverified.

Use visible radio rows for short timing/repeat sets, a shared selection sheet for weekdays, and validated numeric input for monthly day 1–31. Keep occasional commands in an overflow menu. Share labels, selected states, touch targets, focus/cancellation rules, and the existing Material 3 theme. Stage 1 replaces the legacy timing/repeat/day dropdowns with these shared controls, preserving draft Save/Back behavior and metadata-only recurrence. The application remains light Cornflower; selectable map styles apply only to the map.

## D21 — Reviewable trips and external navigation

**Status:** Owner direction recorded 2026-10-27; implementation pending.

Wayday owns errand selection, trip review, saved stops, and local progress. The user explicitly launches Google Maps with confirmed locations. Next-stop navigation is primary; whole-trip URLs are optional within platform/mode/waypoint limits. Provide a browser or readable-destination fallback. Returning to Wayday does not automatically complete a stop.

The later owner clarification in D23 requires automatic recommendations, branch choice, ordering, and estimated scheduling for the first usable release. Manual ordering may be an internal development checkpoint or explicit override; it is not the release goal. Do not invent road geometry, travel times, or feasibility; real road estimates and independent schedule validation remain prerequisites. Maps links are navigation handoff, not a route-data service or a guarantee of truck/clearance suitability.

## D22 — Document ownership and implementation sequencing

**Status:** Documentation decision for the owner's audit request, 2026-10-27; document locations superseded by D27.

Keep root files as entry points, team records, design guidance, or contributor instructions. docs/wayday/ holds full product/technical specifications and the chronological decision log. Root PRODUCT.md retains the design-tool schema marker and links to the full product document. Preserve historical Asikaso content and existing document paths.

The original layout separated task status from detailed task specifications. D26 consolidates both in PLANNING.md; ROADMAP.md holds milestone outcomes and PROGRESS.md holds completion evidence. Avoid duplicate live checklists and copied setup commands; apps/mobile/README.md owns runnable mobile instructions.

Sequence cleanup, early regional data/routing feasibility, map/place integration, automatic branch/order/schedule calculation, saved-plan/navigation integration, and release evaluation. Automatic planning is required for the first usable release, subject to truthful feasibility/support results. This plan does not authorize installing services, scaffolding the API, or implementing runtime features in the documentation turn.

## D23 — Automatic planning defines the first usable release

**Status:** Explicit owner clarification, 2026-10-27; implementation pending.

Clean production hardcoded samples and placeholders first. Users supply errands and necessary constraints; Wayday recommends suitable stores, selects branches, chooses the stop order, and calculates estimated timing. Users review and correct results rather than constructing the full plan. Manual place/order selection is an override or internal engineering checkpoint, not the first-release definition. Pull routing feasibility forward so a failed engine/data assumption is found early.

## D24 — Editable visit estimates and provisional missing hours

**Status:** Explicit owner choices, 2026-10-27; implementation pending.

Supply clearly labeled, editable category-based duration estimates where the user has not specified a duration. Finalize the versioned default/buffer table before scheduler implementation and preserve explicit user values. Estimates are not observed service-time facts.

Allow a suitable store with no reliable opening-hours record in a provisional plan with a clear check-hours notice. Never claim it is confirmed open. Respect known closures and retain the source of any user correction.

## D25 — High-clearance vehicle variants

**Status:** Owner clarification, 2026-10-27; engine/data support unverified.

The high-clearance category includes pickups/light trucks and heavy delivery vehicles. Keep the five top-level transportation choices and distinguish subtype and needed vehicle parameters within the category. Request required dimensions/weight/access details before heavy-vehicle costing. Ground clearance is independent of vehicle height and does not establish legal access, load restrictions, or road suitability.

## D26 — One planning document

**Status:** Owner feedback and documentation correction, 2026-10-27.

Use the existing PLANNING.md for both live task status and detailed implementation specifications, dependencies, inputs/results, acceptance criteria, and checks. Consolidate the previously separated task specifications and update all references; no extra planning file is needed. D27 relocates this same document to docs/PLANNING.md. Keep the roadmap high-level and full product/technical authorities in docs/wayday/. Generic skill output conventions defer to the owner's existing-document preference.

## D27 — Project documentation under docs

**Status:** Explicit owner request, 2026-10-27; locations and consolidation superseded by D28.

Keep only AGENTS.md and DESIGN.md as root Markdown files. Move the existing README.md, CONTRIBUTING.md, PLANNING.md, and PROGRESS.md into docs/, preserving task specifications and completion history. docs/README.md is the documentation index. Keep the full product/technical authorities under docs/wayday/ and historical references in their existing locations.

Remove the redundant root PRODUCT.md pointer after consolidating its product schema marker and platform/stack context into docs/wayday/PRODUCT.md. Supply this canonical path explicitly to design tools; discovery that depends on a root PRODUCT.md is no longer provided. Repair relative links and task-tracker paths. This supersedes D22's root-file layout and relocates D26's single planning document without introducing another plan. Retain useful references, decision history, and application run guides; remove further documents only after checking their unique content and callers.

## D28 — One Wayday documentation folder with fewer files

**Status:** Owner feedback and documentation consolidation, 2026-10-27; the README location is superseded by D30.

Keep all current Wayday project documents in docs/wayday/: README, PLANNING, PROGRESS, CONTRIBUTING, ARCHITECTURE, STACK, and DECISIONS. Keep AGENTS.md and DESIGN.md at the root, app-specific run instructions with the app, and historical Asikaso references in their existing locations. This replaces D27's split between docs/ and docs/wayday/.

Consolidate PRODUCT.md into the README product-requirements section, retaining its scope, acceptance scenarios, and design-tool schema/platform/stack metadata. Remove ROADMAP.md because milestone sequencing and checkpoints already belong in Planning; Progress continues to record completed work rather than future sequencing. Consolidate DEVELOPMENT.md into Contributing, preserving verification boundaries, regional-data practices, backend prerequisites, and later platform/cloud checks. Update links and task-tracker paths without creating redirect files.

Keep this decision log because it records rationale and superseded choices, including the owner's changes to earlier requirements. It is not another task board or progress log. This consolidation changes document ownership only; application capabilities remain at the existing implemented/planned status.

## D29 — Five combined execution stages

**Status:** Owner-selected five-stage plan, 2026-10-27; Stage 1 is implemented and verified, and Stages 2–5 remain planned.

Group the existing implementation tasks into five stages: input cleanup, feasibility and contracts, maps/places/saved-trip foundations, automatic planning, and navigation/release evaluation. Pull regional package and Android map-rendering feasibility into the second stage, combine trip persistence with its local-data foundations, and group navigation with integrated verification and pilot acceptance.

Keep all existing task IDs, prerequisites, acceptance criteria, and verification gates in [Planning](PLANNING.md#execution-order-and-checkpoints). Independent tasks may overlap once their prerequisites are complete; a stage label does not add an otherwise unnecessary dependency. Agree on shared interfaces before parallel work and serialize shared schema/migration changes. Fewer stage boundaries alone do not guarantee shorter implementation time. The automatic-planning release goal and Android-first scope still apply.

## D30 — Root README as the project entry point

**Status:** Explicit owner request, 2026-10-27.

Move the complete README from docs/wayday/ to the repository root so GitHub and contributors can find the project overview immediately. Keep its documentation index, product requirements, design-tool schema marker, and platform/stack metadata in that single file. Update outgoing links, incoming references, project skills, and repository rules for the new location. Do not leave a second README or redirect at the old location.

README.md, AGENTS.md, and DESIGN.md are the root Markdown documents. Keep supporting project documents in docs/wayday/. This changes D28's README location while preserving its other document ownership and consolidation decisions. Historical decision and progress entries retain their original context.

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
