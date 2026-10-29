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

At the time of this decision, keep task IDs, prerequisites, acceptance criteria, and verification gates together in the implementation plan. Independent tasks may overlap once their prerequisites are complete; a stage label does not add an otherwise unnecessary dependency. Agree on shared interfaces before parallel work and serialize shared schema/migration changes. Fewer stage boundaries alone do not guarantee shorter implementation time. The automatic-planning release goal and Android-first scope still apply. D34 later records the owner's removal of that plan.

## D30 — Root README as the project entry point

**Status:** Explicit owner request, 2026-10-27.

Move the complete README from docs/wayday/ to the repository root so GitHub and contributors can find the project overview immediately. Keep its documentation index, product requirements, design-tool schema marker, and platform/stack metadata in that single file. Update outgoing links, incoming references, project skills, and repository rules for the new location. Do not leave a second README or redirect at the old location.

README.md, AGENTS.md, and DESIGN.md are the root Markdown documents. Keep supporting project documents in docs/wayday/. This changes D28's README location while preserving its other document ownership and consolidation decisions. Historical decision and progress entries retain their original context.

## D31 — Measured pilot coverage and source limits

**Status:** M3-01 audit findings recorded, 2026-10-27; map and routing feasibility remain separate gates.

Keep the bounded Pasig/Ortigas rectangular pilot `[121.045, 14.548, 121.116, 14.617]` for map/road evaluation. The independently selected 35-destination sample produced 16 plausible site/branch matches, three ambiguous matches and 16 not found in the bounded OSM extraction/manual review. The sample is deliberately clustered and includes adjacent-city Ortigas malls; it does not establish citywide or category-wide completeness. Only one matched site carries OSM hours, and no entrance coordinates were independently surveyed. Retain branch, service-capability, floor, hours and entrance uncertainty rather than turning these matches into verified recommendations.

Continue with OSM as the initial public source and explicitly defer Overture inclusion: no measured same-sample improvement, duplicate-resolution evidence or source-license review justifies importing it yet. Later catalog/search/recommendation tasks must preserve missing/ambiguous outcomes and manual confirmation. The sampled Galleria public-service counters and salons cannot be advertised as automatically covered from this extract. These limitations do not change the automatic-planning first-release requirement; they are inputs to its qualification and acceptance work. See the [coverage evidence](STACK.md#pilot-coverage-evidence-2026-10-27) and [reproducible audit summary](evidence/pilot-place-audit-summary.json).

## D32 — Qualified local road-routing feasibility

**Status:** M5-01 measured and reviewed, 2026-10-27.

Proceed with local Valhalla 3.9.1 for bounded static road estimates after successful graph, route, matrix and mapped weight-restriction checks. Use the buffered pilot graph and preserve asymmetric/unreachable values. The reproducible study uses a task-owned Docker volume because Windows bind-mounted random I/O stalled; the service binds only to localhost on port 18002. This is evaluation tooling, not a production FastAPI implementation or public deployment.

Keep pickup/light and heavy-delivery parameters distinct. The finite HGV access penalty is not an absolute prohibition. Motorcycle remains beta, dimensions/access data are incomplete, and no profile has ground-clearance, legal-access or observed travel-time certification. These limitations accompany later estimates instead of silently substituting a different profile or claiming safety. See [routing evidence](evidence/routing-pilot-2026-10-27.md).

## D33 — Versioned pilot planning contract

**Status:** M5-02 specified and reviewed, 2026-10-27; runtime implementation remains pending.

Adopt `wayday.planning.v1` as the initial contract specification for later planning/replanning. Keep editable day inputs separate from calculated snapshots and carry request IDs, input revisions, source/estimate provenance and completed history. Use explicit Asia/Manila dates and offset-aware local instants, seconds/meters and provider-independent confirmed places. The initial single-day policy rejects implicit overnight rollover. The versioned, editable duration/buffer table, optional-prerequisite meaning, outcome/HTTP distinctions and finite vocabulary clarification cases are defined in the [contract specification](evidence/planning-contract-v1.md).

The initial limits are 12 errands, three candidates per flexible errand, 38 matrix locations and a five-second solver budget within a 20-second calculation deadline. These are resource policies, not measured full-capacity response guarantees; later implementation must evaluate them. Unknown hours require a provisional result with a check-hours notice, and unavailable services retain local edits and the last saved result. JSON Schema, synthetic examples and cross-field tests specify behavior without creating a server, recommendation service or solver.

## D34 — Remove the active task board

**Status:** Completed by explicit owner direction, 2026-10-27.

Remove `docs/wayday/PLANNING.md` and do not recreate a roadmap or task board. The owner will supply work priorities and sequence directly. Preserve product requirements, decisions, progress history, and feasibility evidence so they remain available as context; they are not permission to restart the former roadmap.

## D35 — Online place search for the Philippines

**Status:** Owner direction; Photon-compatible adapter and picker integration implemented, provider qualification and integrated Android verification pending.

Place search should use an online service and cover the Philippines rather than only the Pasig/Ortigas pilot. Search results must be restricted to the Philippines, without assuming that a rectangular bounding box follows national borders. Keep a manual-selection fallback when search is unavailable and preserve personal data locally. This revises the earlier preference for an installed catalog as the initial search implementation; offline map resources and place search remain separate concerns.

Photon is an evaluation candidate: its API documents a country-code search filter, and a limited live Cebu query returned results marked `PH` on 2026-10-27. Its public instance is a demo with no availability guarantee and can throttle requests. Before adoption, verify the deployed instance's filtering, Philippine data coverage, attribution, limits and replacement path. A public demo is not a production availability commitment. No provider account, purchase, billing activation, or hosted deployment has been authorized by this decision.

## D36 — Saved-place management in Profile

**Status:** Owner-directed, 2026-10-28.

Expose locally saved places through Profile, with name and location editing and confirmed deletion. Changes affect future selections; existing errands and endpoints retain the place details selected earlier. Keep the existing local storage schema and do not introduce an account or synchronization.

## D37 — One-screen place selection

**Status:** Owner-directed, 2026-10-28; native Android verification remains required.

Open the map directly with search, saved places and a single Confirm location action. Search runs after a 600 ms typing pause with two or more characters, with one in-flight request and only the latest queued query. Choosing a result recenters the map without changing its provenance; manual movement creates a draft pin with outdated source/address details removed. Keep explicit name-only fallback, draft cancellation and optional user-requested location permission. Reuse the existing Photon-compatible adapter without a new backend or schema migration.

On 2026-10-28 the owner requested that moving the map leave the search field unchanged and that the temporary positioning label be removed to avoid resizing the map. Confirmation remains unavailable while the map is moving.

## D38 — Direct-client multi-provider search pilot

**Status:** Owner-authorized implementation, 2026-10-28. Supersedes the single-provider request policy in D35/D37 for this pilot.

Combine Geoapify and LocationIQ automatically after an 800 ms pause, with Photon after 1.5 seconds. Use one shared scheduler, memory caches, persisted local reservations/cooldowns, three-character automatic input, and two-character submitted input. Provider failures preserve other candidates. Category aliases use five-kilometer Geoapify Places/LocationIQ Nearby searches in a local map view; panning is never a network trigger. Preserve source metadata and attribution when saving confirmed places, without changing the SQLite schema.

The presentation pilot uses owner-provided free credentials through ignored local configuration. Per-installation safeguards cannot guarantee account-wide quotas, and credentials in an APK are extractable. Public APK distribution requires a separately authorized shared gateway. No hosting, billing activation, paid upgrade, public download, account system, or personal-data synchronization is included. The [mobile README](../../apps/mobile/README.md#search-pilot-configuration) owns runnable configuration and exact local controls; [Stack](STACK.md#multi-provider-search-pilot) records provider policies and fallback.

## D39 — Keyboard dismissal preserves place search

**Status:** Owner-directed, 2026-10-28.

Keyboard visibility and the location search session are independent. Android system Back with the IME open hides it without closing search or changing the query, results, or map draft. A Back event delivered after the IME is hidden also keeps search open. Keyboard inset changes never dismiss search. The app bar exposes Close search while searching; that button and the explicit Back to map action dismiss the session and retain the text field's query. Selecting a result keeps its existing explicit transition to map confirmation. Once search is closed, Back cancels the picker normally. Clear search remains a separate text-clearing action.

## D40 — Contextual location access and search relevance

**Status:** Owner-authorized implementation, 2026-10-28.

Request foreground location only through an explicit Use my location action when access is absent. Once access exists, obtain a fresh fix whenever search opens, without reopening the permission dialog unnecessarily. Share acquisition and recent in-memory fixes across all pickers; use a fix up to five minutes old while refreshing, with a fifteen-second acquisition timeout. Quiet checks honor revoked/temporary permissions. Backgrounding discards pending callbacks and searches; resume does not automatically restart provider requests. Approximate access remains usable, settings are opened only by user action, and no coordinates are persisted as search history.

Separate device location, map viewport, and the selected search origin. Default to Near me when available; Search this area explicitly selects the current local map center for named or category search. Panning never changes the typed text, selected origin, or network activity. Search location refreshes leave the draft and map stationary; the map's explicit location button retains its smooth zoom-18 flight.

Rank the complete merged provider pool before taking thirty results. Exact/canonical names and qualified brand matches precede word, address, and partial matches; distance breaks comparable matches. Seed local aliases for Megamall/SM Megamall and McDonald's punctuation variants without inventing missing records. Approximate distance comparisons use uncertainty buckets. Rows may reorder until interaction; pointer, scroll, or accessibility focus freezes their order and records, with later changes applied through Updated results. This replaces D38's unconditional append-only presentation while preserving its quota/cache/attribution policies. Distances are straight-line estimates among returned candidates, not routing or complete nearest-business coverage.

Keep Android target API 36 and existing dependencies for this slice. Review the session-based location-button integration before targeting API 37; the [published Play policy preview](https://support.google.com/googleplay/android-developer/answer/16909972) is effective January 27, 2027. No database migration, backend, continuous/background tracking, or release is included.

## D41 — Shared brand aliases for nearby matching and retrieval

**Status:** Correction following the owner's Near me bug report, 2026-10-29.

Use one bounded, explicit brand-term registry for ranking, provider query text and request/cache identity. Include Jollibee/Jolibee and McDonald's spelling/punctuation variants. Recognize a registered brand at a word boundary, retain explicit branch/locality qualifiers, and compare its returned branches by distance even when provider brand metadata is absent. A literal provider spelling error must not place distant branches ahead of nearby canonical matches. Keep exact/canonical landmark priorities and conservative branch deduplication.

Canonicalization affects provider requests and cache identity, not the user's displayed field or provider-derived result labels/provenance. Issue a single canonical request rather than querying each alias separately. Use LocationIQ's existing unbounded, distance-sorted viewbox for registered brand-only queries; qualified queries retain its default importance sorting. Do not introduce general fuzzy street/business correction, extra providers, additional request waves, or changes to quota/permission behavior. Preserve the existing interaction freeze and local Updated results action.

## D42 — Google service direction, local credentials and bounded qualification

**Status:** Owner-selected direction and credential/Routes qualification implemented on 2026-10-29; Google runtime feature integration remains pending.

The owner manually created a separate Wayday Google Cloud project under an existing billing account and selected three services: Places UI Kit for Google place discovery, Routes API for traffic-aware travel estimates before branch/stop scheduling, and Navigation SDK for embedded Google navigation after trip review. This revises D21's external-handoff-first direction and D32's Valhalla-only initial estimate direction. Preserve the existing Valhalla study as feasibility evidence and a possible independently attributed static-estimate alternative; do not describe its road estimates as live Google traffic. A Navigation SDK reroute changes the road path, not Wayday's errand constraints or stop order. Traffic predictions and later navigation can differ and never guarantee future arrival times.

Keep the existing MapLibre/manual/offline and Geoapify/LocationIQ/Photon experiences until the Google feature work is implemented and verified. Future Google Routes results must use a Google map when used with a map; do not overlay them on MapLibre or assume hiding the route line avoids the restriction. Google place search on a non-Google map uses actual Places UI Kit components, with their attribution, rather than a raw Places API provider merged into the custom list. Review source-content storage before adding Google places to durable saved records: the terms allow temporary coordinate caching up to 30 consecutive days; place IDs have a separate storage exception. No destructive migration or saved-data change is authorized by this credential task.

Two ignored local credentials have separate purposes. `GOOGLE_MAPS_ANDROID_API_KEY` is restricted to the native Places UI Kit/Navigation SDK and authorized Android identities. `GOOGLE_ROUTES_API_KEY` is a separate restricted REST qualification key. The local configuration tooling passes them without printing values; Android's manifest receives only the SDK key. Missing Google keys must not break current app startup/builds. These preparations do not install or initialize a Google SDK, and direct-client credentials are extractable from the APK. Google recommends a separate key and Android package/certificate headers when direct mobile REST access is necessary. Before adoption, verify that each endpoint rejects incorrect identifiers; on failure, stop rather than retry, unrestrict the key, or silently provision a server. These identifiers do not constitute cryptographic client attestation.

The explicit live runner reserves no background activity and makes at most three Compute Routes starts and one matrix element, using public landmark names, DRIVE and TRAFFIC_AWARE. It stops on its first failed check, never retries, and saves only sanitized technical status/counts. The first qualification passed: correct route and matrix requests returned usable HTTP 200 responses; separately incorrect package/certificate values returned HTTP 403 `API_KEY_ANDROID_APP_BLOCKED`. This does not verify an Android SDK, live traffic accuracy, final planning capacity, truck/motorcycle access, or all five required travel profiles. Automated tests use fake transports.

Target zero spending using published recurring allowances and bounded requests, not promotional credit as permanent capacity. The owner's screenshot showed a paid account with trial credit expiring December 16, 2026; remaining credit is shared and can be consumed by other projects. Billing alerts are monitoring, not request enforcement. Search daily limits were visible in the owner's Console screenshot; proposed Routes/Navigation daily limits require saved-Console confirmation. Matrix origin-destination pairs and navigation destinations consume units separately, and two navigation methods share the same monthly SKU allowance. No purchases, billing-account activation, project/account creation by tools, hosted gateway, background tracking, road-history collection, full planner or public release is included.

Sources: [Google API security](https://developers.google.com/maps/api-security-best-practices#secure-client-side-web-service-calls), [Routes billing](https://developers.google.com/maps/documentation/routes/usage-and-billing), [Navigation billing](https://developers.google.com/maps/documentation/navigation/android-sdk/pricing), [service-specific terms](https://cloud.google.com/maps-platform/terms/maps-service-terms), [Places policies](https://developers.google.com/maps/documentation/places/web-service/policies), [pricing](https://developers.google.com/maps/billing-and-pricing/pricing). Commands and actual verification belong to the [mobile README](../../apps/mobile/README.md#google-credential-configuration-and-routes-qualification) and [Progress](PROGRESS.md).

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


## D43 — Google-first search and temporary provider references

On the owner's follow-up, Where uses Other sources for new searches, independently of the session preference used by From and To. Show the selected non-Google provider label directly in the Where row, and remove the separate Google details card and its automatic binding. Preserve existing Google references, user labels, lease expiry and explicit refresh. Manual pin reverse lookup remains as described below.

The owner extended location display to errand editing. A confirmed unnamed manual errand pin uses the same bounded Geoapify reverse lookup as endpoints; the editor retains its coordinates and uses only a nearby street or locality. A user can supply a separate label when needed. The editor cancels or ignores obsolete lookups and retains the pin on failure. Saving waits for a pending manual lookup, bounded by eight seconds; naming the pin cancels it. The later follow-up above supersedes the separate native Google details display.

The owner also approved reverse-geocoding manually confirmed From and To pins. Geoapify is the single reverse provider; its requests share the existing installation-scoped search scheduler, quotas and accounting. Save the selected coordinates first, then display a nearby street or locality when returned. Do not infer a business or street number from a nearby result. Offline/failure keeps the dropped pin and allows a user-owned label. Existing pins are looked up only when reopened and confirmed, and user-selected names and Google reference restrictions remain intact.

On the owner's follow-up, remove provider-credit labels from the Today endpoint section and the errand editor's Where section; the owner points users to the existing Settings credits page. Geoapify guidance calls for a link near geocoding information, so Settings-only placement remains a provider-terms risk to resolve before public distribution. Today Clear resets errands, From, To and trip settings to their defaults while keeping the selected date. It is available when any of those fields differs from the empty defaults. Undo restores the complete prior plan; outstanding endpoint lookups are cancelled so they cannot repopulate a cleared or restored pin.

**Status:** Owner-authorized implementation, 2026-10-29. The isolated Android Google sample now passes after the owner added its package/certificate restriction. D43 revises D38/D41's default source and interpretation scope. Routing, navigation and release remain separate work.

Google is the initial source; Other sources explicitly selects Geoapify/LocationIQ/Photon. Remember source choice only during the app session and query only the chosen group. Standard Places UI Kit search/details from Places SDK 6.0.2 remain native cards through FlutterFragmentActivity and Android hybrid composition. Do not merge/reorder Google cards or replace them with raw Places API responses. Preserve saved places, manual/name-only selection, keyboard dismissal, contextual location, explicit area selection and draft/Confirm behavior.

Use a coordinate-free Philippine/global NSI subset pinned to 8.0.20260918 / fd4f3c84636838ac2f514a3f00e6a5eb415d59ae. Bundle the BSD-3-Clause notice and omission manifest. The generated subset contains 389 brands from eleven categories; unsupported geography, regex aliases and non-Philippine entries are omitted. Keep McDo/Jolibee overrides and the separate Megamall landmark rule. Local bounded edit distance corrects only a unique best match, with ambiguous suggestions and Search original text. Preserve displayed input, short terms, numbers and qualifiers. Supported bare nearby brands use Geoapify Places; qualified names and landmarks remain named searches. Convenience and sari-sari stores is an honest category label rather than independent store-type verification.

Google search and standard details share one application-scoped scheduler and persisted reservation ledger: one-second debounce, three-character automatic/two-character submitted input, 1.1-second spacing, twenty starts/minute and one hundred/rolling day. Reserve before component binding; accounting failure blocks dispatch. No persistent Google response cache, lifecycle-triggered binding, automatic failover or retry loop is allowed. Cancelled dispatched work stays counted without an outage cooldown. Selected records require a place ID, valid coordinates, original native retrieval time and verified Philippine eligibility. SDK 6.0.2 search/details callbacks expose IDs and coordinates but omit address/country fields. A pinned public-domain Natural Earth v5.1.2 Philippine land mask therefore verifies coordinate membership locally, independently of query/bias. Its 97 polygons/7,406 vertices are about 167 KB; points within 250 meters of the cartographic shoreline remain unconfirmed. Coastal reclamation and omitted islands may need manual/non-Google fallback. This mask is not a legal boundary or access guarantee. Resolve missing metadata once through standard details, then block confirmation if still invalid. Interaction freezes the visible native fragment; Updated results reveals a staged replacement without new requests.

Google durable records retain place IDs, static provenance/credit and a user-owned label initially based on the original query. Never serialize returned Google names/addresses or temporary coordinates into errand/Recurring/saved-place JSON. Coordinates live separately in private Android cacheDir, excluded from backup/transfer, with a thirty-day lease from acquisition. Shared leases enforce expiry before coordinate access. Startup, foreground return, cache access and a foreground timer purge expired entries. Copies do not reset expiry. Missing/evicted pins retain their labels and require explicit online refresh. Existing non-Google records keep their behavior; no SQL migration is needed.

The isolated Android sample verifies successful Google loads, usable selected coordinates, local Philippine eligibility, original user-label preservation and native disposal. A separate real IME/system-Back fixture verifies keyboard dismissal without closing search. The callback deliberately omits Google names/addresses, so correctness of card labels is reviewed visually rather than inferred from missing callback fields. A successful sample does not establish complete Philippine coverage, coastal eligibility, account-wide cost control or all Android keyboards. Keep restrictions in place; actual verification and limitations belong in Progress and the mobile README.


The owner's screenshot-based follow-up restores the original shared search structure while retaining Google as the initial source. Source actions are compact text with selected weight/underline, without filled blocks. Both groups share origin/location/area controls, the Places heading, correction and status copy, saved-place rows and full name-only/map fallback actions. Keyboard visibility no longer substitutes a Search options menu or hides the footer. Other sources retains the original custom rows/distances. Google retains standard native cards/order/attribution, with supported Figtree, regular-weight place-name, muted-address and flat-surface styling. Its controls/footer scroll within constrained regions while a 180-unit native viewport remains available on normal panels (45 percent on short panels). Native identity stays stable through layout changes; quotas, storage, selection and confirmation are unchanged. Actual verification belongs in Progress; the earlier [qualification record](evidence/google-search-qualification-2026-10-29.json) remains historical evidence for the Google integration.

The owner subsequently requested bottom placement for the Google Maps credit. Use the standard `PlaceSearchFragment.attributionPosition = AttributionPosition.BOTTOM` property so attribution remains inside the native results component, below its cards and above Wayday fallback actions. Do not remove, obscure or replace the SDK credit. This changes presentation only, without query scheduling, source selection or storage changes. [Google component configuration](https://developers.google.com/maps/documentation/places/android-sdk/place-search-ui-kit#customize_content).

The owner requested a simpler search interface: remove the Places heading and automatic-correction explanation and original-text action from the shared picker. Existing alias and correction behavior remains active, so users can no longer explicitly bypass a correction through that screen. Ambiguous suggestions, frozen-list update action, saved places and manual selection remain available. The Google search component is configured for names and addresses, not a map preview; its native attribution remains required.

The owner requested consistent result presentation across sources and removal of the dark region below Google results. Other sources now uses matching white rows, typography, padding and dividers with a neutral selection chevron; names, addresses, distance and attribution stay sourced from the selected provider. The Android Google UI Kit retains its standard cards and attribution. Its full-height CardView defaults to a dark background in Android dark mode while the results content is white and wraps its children; the card background now explicitly uses the light style.

The owner approved retaining source results until the open search interface closes. Switching sources restores independent presentation state without clearing rows, retrying failures or rebinding Google. Pending jobs pause when hidden; dispatched jobs may finish into their original current-context session without changing the draft. Keep one lazily created Google host alive and exclude it from input/accessibility while hidden. Explicit Refresh results uses existing quotas and deliberately bypasses the Other sources cache; normal response caching remains unchanged. Input/category/origin changes invalidate obsolete sessions. Backgrounding cancels pending work and invalidates callbacks, preserving completed rows without automatic network resumption. This is picker-scoped presentation retention, not a persistent Google response cache or account-wide quota mechanism.
