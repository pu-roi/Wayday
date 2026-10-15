# Development and verification guide

## What exists today

The repository contains planning documents, configuration, project skills, and the existing Asikaso HTML prototypes. The frontend root `apps/mobile/` and backend root `services/api/` each contain only a `.gitkeep` marker. There is no Flutter project, Python package, API, database migration, container configuration, or deployment pipeline.

The user has deferred application development. The prerequisites and future checks below describe a later phase; this guide is not an instruction to install or scaffold them now.

## Existing prototype

Open `docs/Asikaso-Prototype/V2.html` in a browser. It uses in-memory sample data and resets on refresh. An internet-loaded font may be unavailable offline; that does not make the simulated map a real offline map.

With Node.js installed, run from the repository root:

```powershell
node docs/Asikaso-Prototype/docs/v2-planner-checks.cjs
```

The check covers application syntax, the original 5:30 PM example result, optional dropping, example categories, arrival/completion deadlines, a larger-plan constraint, and template rule preservation. Its travel times and places are simulated. Do not use its expected 5:30 PM arrival as a real routing benchmark.

For a local browser preview, the existing helper can be used if Python is available:

```powershell
Set-Location docs/Asikaso-Prototype
python preview_v2.py
```

Then open `http://127.0.0.1:8766/V2.html`. Stop the helper with Ctrl+C. Read its source and nested prototype instructions before modifying it.

## Foundation checks

- Resolve relative Markdown file links against each document's directory.
- Review product scope against the decision log, especially AI, travel modes, offline behavior, and cost policy.
- Check that original reference files retain their contents.
- Use `git check-ignore --no-index` on representative source, generated, data, and secret paths. The original documents and screenshots must remain trackable.
- Validate project skills with the installed skill-creator's `scripts/quick_validate.py`. Also inspect their trigger descriptions and document references. The current collection covers UI, mobile integration, backend services, API contracts, databases, and itinerary planning.
- Run the existing prototype check when verifying the initial foundation or when changing its inputs.

There is no required Markdown formatter, global Python setup, or CI subscription for this phase. The skill validator is an authoring-time check, not an application dependency.

## Prerequisites for later implementation

| Area | Planned prerequisites | Important boundary |
| --- | --- | --- |
| Android | Stable Flutter/Dart SDK, Android SDK/toolchain, emulator or physical device | Select compatible JDK and SDK versions with the chosen Flutter/map package versions |
| iOS | Access to macOS, Xcode, compatible Flutter tooling, and an iPhone for reminder validation | Windows cannot compile the iOS app locally; personal-device provisioning and store distribution differ |
| API | Supported Python release, isolated environment, FastAPI/Pydantic, OR-Tools | Choose a Python release with compatible OR-Tools wheels; do not assume the newest release is supported |
| Data | PostgreSQL/PostGIS, regional OSM extract, storage for import and route graph | Data processing can need substantially more disk/RAM than the final extract |
| Routing | Valhalla on Linux/WSL2 or another supported setup | Start with a bounded region, not a planet graph |
| Local infrastructure | Native tools or Linux containers through a suitable runtime | Select and document the runtime later; no Docker Desktop subscription or installation is required by this foundation |

See the [stack inventory](STACK.md) for upstream documentation and costs. Record exact versions and platform minimums only when scaffolding; commit the resulting application lockfiles. Prefer a physical Android device if running an emulator and data services together strains the development computer.

## Future local configuration

When applications exist, provide safe example configuration alongside the component that uses it. Do not create pretend runnable environment files now.

- The mobile API base URL is public configuration, not a secret. Never bundle database passwords or server credentials into the app.
- The backend owns the database connection string and Valhalla endpoint. Keep real credentials in ignored local configuration.
- Store raw extracts, generated graphs, and local databases outside source directories, using the ignored local-data paths or an external directory.
- Keep small, synthetic, shareable test fixtures in tracked test directories. Adjust targeted ignore exceptions when intentional fixtures are introduced.
- Saved test data must not contain real home addresses, personal notes, or location traces.

For local phones, document how to reach the computer over the chosen network. Configure firewall access narrowly. Keep development cleartext exceptions out of release builds. Future public deployment requires authentication/access policy, TLS, and measured resource requirements.

## Future checks once components exist

| Component | Intended checks |
| --- | --- |
| Flutter | `flutter analyze`, format verification, unit/widget tests, offline persistence integration tests |
| Backend | Ruff checks, pytest domain/adapter tests, API contract checks, database migration checks |
| Planner | Fixed-matrix scenarios, tiny exhaustive comparisons, independent itinerary validation, bounded runtime |
| Platforms | Physical-device permissions, geofences, local notifications, restart, airplane mode, downloaded-map completeness |

These commands are not currently runnable for Wayday because the corresponding projects do not exist. Add exact working-directory instructions and executable commands when those projects are created.

## Future cloud readiness

Measure catalog/database size, route graph RAM/disk, API/solver latency, and egress before selecting hosting. Evaluate Supabase for PostgreSQL/PostGIS separately from hosting the Python API and Valhalla. Document free-tier exhaustion and trial expiry behavior. A cloud decision also needs backup/restore and migration verification; it must not remove the phone's offline task capability.
