# Wayday agent instructions

## Current phase

The Android Flutter shell, Today, and Recurring are implemented. Local Drift/SQLite storage for Today and Recurring was implemented and verified on Android on 2026-10-27; the browser preview remains in memory. Use one light Cornflower theme without appearance controls, compact errand lists, focused editing, and numeric time entry. Repeat settings are metadata, not an automatic scheduler. Do not repeatedly ask for authorization already present in the conversation.

On 2026-10-27 the owner removed the implementation plan and task board. The owner estimated the hackathon was about two days away; exact dates, event duration, theme, required technology and judging criteria remain unconfirmed. Follow only the owner's latest explicit task instructions; do not restore the removed roadmap or infer a new task sequence. M3-01, M3-02, M5-01 and M5-02 remain completed evidence/specification. M3-03 has historical emulator evidence; the current picker and patched native controls remain unverified on Android. Preserve product constraints, including honest route/place data and the long-term requirements in README.md. Completed-work evidence remains in Progress and the evidence files.

The owner also authorized smoother list motion, optional free-form errand notes, and refined in-app feedback on 2026-10-16. Notes copy independently from Recurring into Today. Respect reduced motion, preserve continuous-entry focus, and make ordinary feedback expire automatically. In-app snackbars are not Android reminder notifications; reminder integration remains deferred.

The frontend lives at `apps/mobile/`. The backend root `services/api/` contains the imported bounded place service for review; the app uses the separate Photon-compatible online search adapter. Current UI work does not authorize new backend scaffolding or connecting the pilot service to nationwide search. The combined location picker, Profile saved-place management and Today map controls are implemented but still require integrated Android verification.

On 2026-10-28 the owner authorized a direct-client multi-provider search presentation pilot with Geoapify, LocationIQ, and Photon, conservative per-installation request limits, caching, category search, and preserved provider attribution. Public download, hosted gateway deployment, and billing activation remain separate later work. See D38 and the mobile README for policy and configuration.

Android is the first implementation and verification target. iOS comes later and is not a prerequisite for starting Android work.

On 2026-10-29 the owner selected Google Places UI Kit, traffic-aware Routes API inputs and embedded Navigation SDK as the next integration direction. D42 records local credential/build configuration and bounded Routes qualification; Google app screens and the planner are not implemented by that preparation. The owner created the Cloud project and credentials manually. Do not expose keys, remove restrictions to work around failures, render Google Routes content on MapLibre, treat trial credit as a spending cap, or claim all five vehicle profiles are supported without qualification. Public deployment, billing activation by tools, background tracking and a full backend remain outside this credential task.

On 2026-10-29 the owner authorized Google-first search, explicit Other sources, a pinned Philippine NSI dictionary and expiring Google coordinate references. D43 records the implementation. The bounded isolated Google sample passes after the test identity was authorized. SDK callbacks omit country/address/name content; use the pinned local Philippine land mask for eligibility and retain conservative coastal/small-island fallback. Do not infer complete data coverage or all-device UX from a sample/build. Routing/navigation and public release remain separate work.

On 2026-10-30 the owner clarified that the presentation must work with the phone and internet, without a connected or reachable laptop. Planning must not depend on the local FastAPI/Valhalla setup. D44 records the clarified requirements and the proposed bounded on-device scheduler; this supersedes earlier laptop-dependent planning assumptions, including those in project skills. Missing specific meeting points must open the existing search/map-pin confirmation flow. Recommendations may be accepted or changed, and suitable errands may share a stop without merging their task identities. The subsequent D45 owner decision selects Gemini for sentence-level English, Filipino and Taglish interpretation and authorizes local storage of the supplied credential. This supersedes AI-deferral and vocabulary-only baseline guidance in earlier project documents and skills. Gemini integration and model selection remain pending; keep the stored key out of Flutter build defines and the Android manifest. Runtime implementation and its qualification remain pending.

## Sources of truth

On 2026-10-30 the owner explicitly requested a focused `docs/wayday/PLANNING.md` update before implementation. That document now owns the current Plan my day feature sequence and acceptance checks; it does not restore the former project-wide roadmap or task board. The owner expects a phone-only presentation within two to three days, with no exact date/time supplied. Preserve five top-level travel choices, but use actual bicycle-specific routes with the shared motorcycle-style interface, qualify bicycle routing and guidance separately, and restrict the initial Truck behavior to a clearly labelled ordinary-driving estimate for an explicitly identified compatible light pickup. Heavy/restricted delivery vehicles remain unavailable. The earlier whole-truck capability remains a long-term requirement, not a verified presentation feature. This turn authorizes documentation; implementation follows separately.

- Read [the product scope](README.md#product-requirements) and [decisions](docs/wayday/DECISIONS.md) before changing product assumptions.
- Read [architecture](docs/wayday/ARCHITECTURE.md) and [stack](docs/wayday/STACK.md) when making technical choices.
- Read the owner-requested [Plan my day implementation plan](docs/wayday/PLANNING.md) for this feature's agreed interface, sequence, remaining qualification gates and acceptance checks.
- Keep `README.md`, `AGENTS.md`, and `DESIGN.md` at the repository root. Keep supporting current project documents in `docs/wayday/`. [README](README.md) owns the document index, product requirements, and design-tool product metadata. The owner supplies current task scope and sequence directly; [Progress](docs/wayday/PROGRESS.md) records completed work. [Contributing](docs/wayday/CONTRIBUTING.md) owns development and verification guidance. Decisions, Architecture, and Stack retain their separate responsibilities. Do not create a new roadmap or task board unless the owner explicitly asks. Generic skill output paths do not override these locations; supply the README path explicitly to tools that need product context.
- Follow the latest explicit user direction. Record resulting changes to decisions and affected documents.
- Treat the Asikaso abstract, HTML, and screenshots as historical evidence and provisional design references. Do not silently promote their simulated behavior or old requirements into current Wayday requirements.
- Preserve existing reference material unless the user requests changes. When working inside the prototype, also follow its nested `AGENTS.md` and context files.

## Current implementation continuation — D47

The owner subsequently authorized runtime implementation and confirmed a paid Gemini project with roughly $4 remaining credit, then requested conservative request limits and instructed us to proceed. D47 and the focused implementation evidence supersede earlier implementation-pending descriptions above. The private debug pilot now includes a native Keystore Gemini bridge, review/candidate flow, worker-isolate scheduler, restricted Routes adapter, Google result map, additive v3 accepted-plan storage and embedded guidance. Record verification separately from implementation. Do not claim all-mode or physical-phone readiness from fixture/emulator checks.

The authorized presentation allocation is ten Gemini attempts total: one isolated qualification and nine phone attempts. Native and Dart paths cap three per rolling day, with a finite provisioned balance, bounded text/output, no tools, no automatic retries/refills, and reuse of unchanged interpretations. Reserve about $0.025 per attempt at the reviewed prices; per-installation counters do not cap account-wide Cloud charges. Default provisioning remains zero. Do not reprovision repeatedly or allocate the phone allowance on multiple devices. Release builds intentionally refuse the private client key path. The personal phone was disconnected during initial implementation; preserve its data during later installation and rehearsal.

## Direct planning entry and interpretation reuse — D48

The owner removed the introductory planning page and authorized a persistent interpretation cache. Start loading immediately; use matching saved understanding before dispatch. Keep a bounded native no-backup journal (eight snapshots) keyed by versioned model/prompt/schema/settings plus exact canonical interpretation inputs. Commit pending before dispatch and completion before Flutter callback. Revalidate model output, preserve source revision guards, do not re-spend for routing-only changes, and never automatically retry a pending/failed/corrupt outcome after app death. An explicit paid-retry action is required. Do not clear the cache or refill the paid allowance on ordinary rebuilds. Native fixture methods are debug `.maptest` only; do not seed the personal app's cache or run live paid requests for these regression checks.

## Working constraints

- Use Wayday as the project name. Keep Asikaso's historical filenames and attribution intact.
- Planned transportation profiles are walking, biking, motorcycle (motor), sedan (low clearance), and truck (high clearance). Public commute is excluded. D45 selects Gemini-assisted errand/note interpretation; preserve explicit user fields and review proposed interpretations before applying them. Real place data, road estimates and schedule validation remain separate.
- Preserve the distinction between ground clearance and overall vehicle height. Validate the truck class, required dimensions, engine capabilities, and local road data before claiming clearance-aware routing. Do not treat high ground clearance as permission to ignore access restrictions.
- Target zero spending. Free tiers and trials are permitted; document limits, expiry, and fallback before adopting them. The current task does not authorize purchases, billing activation, or external account creation.
- Keep personal task state and trip progress local by default. Do not add accounts, cloud synchronization, location history collection, or analytics without a product requirement.
- Keep route estimates, unknown business hours, and unavailable data honest. Never substitute invented results for a failed service.
- Keep source documents and screenshots trackable. Exclude credentials, signing files, generated output, local databases, and downloaded geographic datasets.
- Write maintained documentation and skill instructions in clear, complete English. Chat compression preferences do not apply to repository content.

## Architecture and skills

The planned frontend is Flutter organized by feature, with views, view models, and repositories. The planned backend is a FastAPI modular monolith with services inside domain modules. Do not split it into microservices without a demonstrated need.

Select project skills by the responsibility being changed:

| Skill | Use for |
| --- | --- |
| `$wayday-ui` | Screen layout, interactions, visual components, and accessibility |
| `$wayday-mobile` | Flutter state, feature wiring, offline behavior, native map integration, permissions, and reminders |
| `$wayday-backend` | FastAPI domain services, orchestration, provider adapters, and bounded computation |
| `$wayday-api` | REST/JSON contracts, validation, errors, OpenAPI, and client API integration |
| `$wayday-database` | Drift/SQLite and PostGIS storage, repositories, spatial queries, imports, and migrations |
| `$wayday-planning` | Interpretation rules, candidate places, matrices, timing constraints, solver behavior, and replanning |

Combine skills only when the requested change crosses those boundaries. Do not load the entire collection for every task. Ordinary documentation edits do not require loading unrelated skills. Skills support the current request; they do not independently authorize scaffolding, installations, deployments, or application development.

## Verification and reporting

- Mobile checks: run `flutter analyze` and `flutter test` from `apps/mobile/`; see its README for local-tool support. The preserved prototype check is `node docs/Asikaso-Prototype/docs/v2-planner-checks.cjs` from the repository root.
- For foundation edits, check links, decision consistency, skill validity, and ignore rules. Do not invent mobile/backend checks before those projects exist.
- When runtime development is authorized, use the relevant acceptance cases in the product and architecture documents. Test behavior and constraints rather than matching implementation wording.
- Report what changed, what was checked, and any actual limitation. Distinguish planned, implemented, and verified capabilities.
