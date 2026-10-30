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

## Review recovery and ordering — D52

The owner requested deeper investigation after the stale-warning fix. Review now uses one effective proposal projection for immediate dependency order and forward validation. Explicitly saved date/departure/deadline settings persist in a separate source-bound singleton Drift v4 row; matching Today input restores them before cache-first understanding. Today and accepted progress stay separate, changed sources invalidate the row, and replanning/history bypasses it. Keep storage failures explicit. A genuinely past departure remains blocked with exact date/time and recovery actions; do not roll dates or shift appointments automatically. D52 supersedes the earlier claim that corrected review trip settings are always discarded on Close. This storage is separate from the native interpretation cache and does not require paid generation.

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

## Planning field verification — D53

D53 adds shared review/calculate preflight checks for structural input, trip windows and zero-road mandatory timing conflicts, with field-specific recovery. Keep arrival distinct from service start/completion, preserve shared-stop semantics, and allow independent optional omissions. Recheck elapsed departure before road requests. The v4 review singleton now also retains manually confirmed source-errand clock differences. Restore trip context before interpretation and those clocks afterward so unchanged original inputs keep their cache identity. Restored clocks do not answer unrelated questions. The review editor does not expose unhandled source removal. Never silently move an appointment or consume paid requests for regression tests.

## Native verification safety and recovery — D54

The Android test/install sequence exposed a personal-app reset despite .maptest and --no-uninstall. The exact trigger is unresolved. `test-map.ps1` now blocks when the primary-user personal package is installed; use a disposable emulator without that package. Do not bypass this protection or rerun the harness on the personal phone. Native installation checks must remain separate from source-data recovery and live itinerary qualification.

A native recovery marker protects missing understanding after installation recovery: status reports recovery and dispatch requires explicit paid retry. Do not seed the personal journal with fixtures or automatically spend to replace it. The current restored allowance remains seven, with two consumed attempts conservatively retained in native/Dart daily accounting. The owner declined further data recovery after the database had already been restored.

## Gemini reuse without app-imposed request caps — D55

The owner's latest direction removes the former Gemini daily/monthly limits and finite presentation allocation. This supersedes the Gemini usage-cap/reprovisioning guidance in D47 and D54, including the historical seven-attempt balance. Do not gate generation on those legacy counters, reset them, replenish an allowance or reprovision during ordinary updates. Existing private credentials remain usable. Google provider quotas/billing and the independent Routes/search/navigation controls remain separate.

Keep persistent exact-context reuse, in-flight coalescing, response/source validation and explicit retry after failed/interrupted/corrupt or recovered processing. Check saved understanding is read-only and must not generate on a cache miss. Keep payload/output bounds, no tools and the debug-only Keystore credential boundary. Use mocks for routine regression checks. The owner also requested consistent action geometry: filled/outlined controls now share theme metrics, while compact text/toolbar actions retain their role.

## Question-specific clarification and explicit deferral — D57

The owner authorized the focused clarification implementation. Questions open answer sheets; keep Edit errand separate. Gemini interprets free-form English, Filipino and Taglish. Typed optional preferences may use an explicit local flexibility choice. Unknown grocery items receive general suitable-place recommendations, never invented shopping lists or inventory claims. Preserve existing durations, including the unconfirmed 15-minute estimate. Drafts do not apply answers. Successful saving produces an editable summary; proposed timing/order rules require approval. Never restore the errand-wide clarified flag.

Drift v5 adds source-bound clarification sessions; deferrals are also plan-date bound. Persist submission before dispatch, merge independent question revisions, and recover pending work with saved-only lookup. Keep the separate 32-entry native clarification journal from evicting the eight initial interpretation snapshots. The frozen legacy request remains a compatible lookup path and cannot bypass pending/failed/corrupt retry guards through version changes. D55 still prohibits app-imposed Gemini usage caps.

Explicit Plan the other errands previews the dependent closure, keeps excluded tasks in Today, preserves required status and records reasons. Re-inclusion is explicit and a plan needs an active errand. Accepted itinerary v2 separates assignments, optional omissions and explicit deferrals, retains summaries/results and reads v1. Preserve provider-backed results and Google presentation/retention. Use mocked regression services and a clean disposable .maptest emulator; never the personal-phone harness or live paid requests. Record native/physical-phone qualification separately.


## Route-aware recommendations — D58

The owner authorized the route-aware recommendation plan on 2026-10-31. D58 supersedes the visible-UI-Kit-only recommendation restriction: a separate native Places SDK adapter supplies explicit business metadata for Wayday's recommendation rows. Preserve standard UI Kit presentation in the manual picker. Google SDK and UI Kit references share identity and expiring coordinate leases; never serialize provider names, addresses or coordinates as durable user-owned text. User errand labels remain separate from transient provider display names.

Build the whole-trip proposal automatically after review. Use a bounded route seed, corridor search and at most two relevant anchor searches per flexible need, then compare branches jointly with the existing scheduler. Preserve fixed points, actual pickup locations, explicit preferences, durations, shared-stop task identities, deferrals and unsupported-mode gates. Search manually and choose on a Google map are explicit alternatives; planning does not offer name-only completion. Current location replaces the start only after confirmation.

Drift v6 adds a source/context-bound recommendation-draft singleton. Keep selections, overrides, approved interpretation choices and navigation position separate from Today and accepted progress; source changes invalidate recovery. Provider metadata, matrices and geometry stay transient. Reuse matching road matrices for at most five minutes in the same foreground context; edits, expired leases, changed route context and backgrounding require revalidation. Do not regenerate Gemini for routing-only changes. Preserve independent Google search/Routes/navigation accounting and restricted keys. Test through mocks and the guarded disposable .maptest emulator, never the personal-phone harness or live paid requests. Record live provider and physical-phone qualification separately.
