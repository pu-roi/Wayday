# Contributing to Wayday

## Current phase

Wayday has an Android shell, Today, Recurring, and verified local SQLite persistence. Stage 1 adds empty startup and consistent selection controls while preserving stored data; maps remain placeholders. The owner authorized M2-01 through M2-04 on 2026-10-27. Planning and Progress record acceptance and the actual Android targets. See [Product](../../README.md#product-requirements) for current and target behavior and the [mobile README](../../apps/mobile/README.md) for runnable commands.

Use [Planning](PLANNING.md) as the single file for the implementation plan, task specifications, dependencies, live status, and assignment. Use [the documentation index](../../README.md) to find each authority. The root README owns the project overview, documentation index, product requirements, and design-tool metadata. Supporting project documents live in `docs/wayday/`; `AGENTS.md` and `DESIGN.md` also remain at the root. Keep milestone sequencing in Planning and completion evidence in Progress. Link to those authorities instead of duplicating their contents.

Read the [product scope](../../README.md#product-requirements), [decisions](DECISIONS.md), and [agent instructions](../../AGENTS.md) before proposing changes.

## Making a change

1. Keep the change within the requested scope. Preserve the original abstract, prototypes, and screenshots unless their modification is requested.
2. Update the decision log when an agreed technical or product choice changes. Mark assumptions as assumptions.
3. Keep documentation links relative to their source file so they work in other checkouts.
4. For a new dependency or service, record its purpose, license, costs, limits, expiry, and replacement path in the stack inventory. Recheck official sources when adopting a specific version.
5. Keep secrets, personal coordinates, signing credentials, generated builds, and large downloaded datasets out of commits.

Use descriptive branch names. Coding assistants default to the `codex/` prefix when creating a branch. Do not create a branch or commit merely to edit the foundation unless the task calls for it.

## Verification

For documentation changes, verify local links, source claims, terminology, and consistency. Check that ignore patterns do not hide source references or screenshots.

The current prototype check, run from the repository root, is:

```powershell
node docs/Asikaso-Prototype/docs/v2-planner-checks.cjs
```

It verifies simulated prototype behavior. It does not prove real routing quality, language accuracy, or reminder delivery.

New project skills should pass the installed skill-creator's `quick_validate.py` validator. That validator is an authoring tool, not a required application dependency. Review skill triggers and references as well as syntax.

When application code exists, add meaningful tests for timing, persistence, service failures, and platform behavior. Additional development practices and checks are listed below.

## Review notes

Describe the problem, resulting behavior or documentation change, and checks performed. Identify any unresolved decision. Do not describe recommended or simulated features as implemented.

## Licensing

Do not assign an open-source license to the team's original work without an explicit ownership decision. Retain required notices for third-party code, fonts, and data. OSM data licensing is separate from application code licensing.

## Development practices

The [mobile README](../../apps/mobile/README.md) owns exact Flutter commands and local-tool instructions. The [implementation plan](PLANNING.md#task-specifications) owns task-specific checks. The following practices were consolidated from the former Development document. The preserved prototype check above runs when prototype inputs or behavior change; read its nested instructions before editing.


### Mobile verification

Use the mobile README's analyze, test, run, and debug-build commands from apps/mobile/. Run affected behavioral cases during a slice and full mobile checks at milestone checkpoints.

Preserve quick-add focus, save/cancel, notes and copy independence, timing, numeric validation, undo, reduced motion, feedback dismissal, persistence, and duplicate prevention. Tests that need examples must supply explicit synthetic fixtures; production repositories start empty.

Exercise Android force-stop/relaunch and offline cold starts where relevant. Widget tests and emulator screenshots do not establish TalkBack, physical-device frame rates, GPS quality, or background delivery. Record the actual target. Renderer captures use WAYDAY_CAPTURE=1 and the ignored .impeccable/review/ directory as described in the mobile README. Keep private locations and notes out of artifacts.

### Documentation ownership and checks

- Follow [the documentation index](../../README.md). README.md, AGENTS.md, and DESIGN.md remain at the root; supporting documents live in docs/wayday/. Link to full requirements, task statuses, or setup commands instead of copying them.
- Resolve local Markdown links against each source file and check referenced anchors where useful.
- Check product, decisions, architecture, stack, and plan for conflicting selected/implemented/verified claims.
- Preserve the design-tool product schema marker in [the README](../../README.md) and historical Asikaso sources/screenshots. Supply README.md explicitly to tools that need product context; do not recreate a separate product file.
- Keep source, notices, synthetic fixtures, and references trackable. Check ignore behavior for secrets, map packages, generated outputs, and local databases.
- For changed skill instructions, inspect references and use the installed skill-creator's scripts/quick_validate.py when available.
- Documentation-only edits use link, consistency, and ignore checks; they do not require rebuilding unchanged Flutter or prototype code.

### Regional maps and data

The selected map direction and research sources live in [Stack](STACK.md). Measure coverage and resources before promising nationwide support. Keep extracts, generated PMTiles, catalogs, and route graphs in ignored data/downloads/, data/generated/, data/local/, or a chosen external directory.

Each package needs source URL, acquisition time, source snapshot, region bounds, processing/schema version, license notices, checksums, and resource requirements. Test failures with disposable data. Replace public packages atomically, retaining the last valid version and all personal state.

Offline rendering needs tiles, style, fonts/glyphs, and sprites; verify a real Android cold start with networking disabled. A remote PMTiles archive is still a network dependency. Select storage/download budgets from measurements; no current size or speed guarantee exists.

Stage 1 implementation does not authorize purchases, billing activation, external accounts, public hosting, or global installations. Existing hardware has finite disk, memory, and network capacity.

The Stage 2 place audit is reproduced from the repository root with `py tools/geodata/pilot_audit.py fetch`, `py tools/geodata/pilot_audit.py candidates`, then `py tools/geodata/pilot_audit.py report`. Run `py -m unittest discover -s tools/geodata -p 'test_*.py'` for offline matching/provenance regressions. The frozen sample and reviewed findings live under `docs/wayday/evidence/pilot-place-audit-*`; raw downloads, successful-query manifests and failed attempts stay in ignored `data/downloads/pilot-audit/`. A new live fetch may reflect newer OSM data, so keep historical snapshot/hash evidence distinct from a refreshed result. Source failures are unresolved measurements, never empty coverage.

Prepare the regional renderer package with `py tools/maps/build_package.py --pmtiles .tools/pmtiles/pmtiles.exe --copy-to-app` from the repository root. Obtain the pinned official `pmtiles` 1.31.2 tool locally; do not commit the executable. The recipe uses the bounded 20261026 source archive, pinned glyph/sprite resources and authored style. It stages and checks the complete package before publishing to ignored `data/generated/maps/pilot/` and optionally `apps/mobile/assets/maps/pilot/`. Repeat runs use verified cached downloads. Run `py -m unittest discover -s tools/maps -p 'test_*.py'` for offline failure cases. Empty tracked asset directories allow a source checkout to build an honest missing-package state before preparation; generated geographic resources do not belong in Git. The dated upstream archive may expire, so retain the verified local source cache for exact reproduction; choosing a newer source requires a deliberate recorded package revision.

### Backend after the routing gate

The proposed service remains a local FastAPI modular monolith with bounded routing/planning adapters. [Architecture](ARCHITECTURE.md) defines responsibilities; no /v1 contract is implemented or frozen.

Before M5 scaffolding, validate a regional Valhalla graph and profiles on existing hardware. Pin compatible Python/OR-Tools versions, define the contract, and add safe example configuration only for real components. Keep credentials out of the app and sensitive bodies out of logs.

Document emulator and physical-device networking separately. Localhost on the phone is the phone. Restrict development HTTP exceptions to debug builds; an asleep/disconnected computer is an unavailable backend.

When components exist, use their actual lint/domain/adapter/contract/migration checks, fixed matrices, tiny exhaustive comparisons, and independent schedule validation. Use fixtures instead of repeatedly querying demo endpoints.

### Later platform and cloud checks

iOS is separate and does not block Android. Background reminders require physical-device cases for denial, approximate location, reboot, delayed delivery, and termination. Verify map-cache completeness and eviction.

Cloud readiness requires measured catalog/graph size, memory, latency, bandwidth, recovery, and quota exhaustion behavior. Supabase is a possible PostGIS host, not a host for all Python/routing dependencies. Deployment remains later work.
