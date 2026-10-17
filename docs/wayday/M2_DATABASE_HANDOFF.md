# M2-03 database and contributor handoff

Verified on 2026-10-17 on `rudy-branch`. M2-03 is complete. M2-02 physical-location/permission checks and M2-04 place-quality checks remain open; this does not complete M2 or enable route planning.

Update 2026-10-18: [Running Wayday](RUNNING_WAYDAY.md) now distinguishes app-only, Docker-free file search and full PostGIS modes. The follow-up footprint/residential import has 13,033 places; 18 API tests (seven PostGIS cases) pass. The table below records the original M2-03 baseline, not a claim that later counts remain unchanged. SQL migration 002 is additive. From/To are now session-only, Recurring starts collapsed and mapped pins can resolve their names; interpretation remains untouched.

## Why this layer exists

The map can render without PostgreSQL, and explicit file mode remains useful for lightweight development. PostGIS is the agreed regional catalog store for repeatable imports, durable source-linked corrections and geographic queries. It does not replace the phone's SQLite workspace, interpret errands, calculate roads or choose a schedule. Personal errands, notes and trip progress remain on the phone.

## Start on this laptop

Open Docker Desktop and wait for its Linux engine. In PowerShell at the repository root:

```powershell
.\tool\prepare-places-db.ps1
.\tool\start-places.ps1
.\tool\verify-places-db.ps1
```

On a fresh checkout, run `.\tool\prepare-places.ps1` first to create the Python environment and download/import the bounded OSM extract. Preparation is repeatable. The database script starts only this Compose project's service and imports into its persistent volume. No global Docker cleanup or volume deletion is required.

The database password is stored in ignored `data/local/places-db.credential.xml` using Windows DPAPI for the current Windows user. Each developer configures their own local password on their own machine; do not copy this credential file into Git or the mobile application. No GitHub or Docker account token is used by Wayday. The scripts set database credentials through the process environment, never as command-line arguments or request logs.

API: `http://127.0.0.1:8780`; database: `127.0.0.1:55432`, database/user `wayday`. The API health endpoint must report `ready` and `postgis`. Emulators use `http://10.0.2.2:8780` without a mobile code change. Physical USB testing uses ADB reverse and the API URL override in [the mobile guide](../../apps/mobile/README.md). Neither listener is public.

Stop the API with `.\tool\stop-places.ps1`; stop the database with `docker compose -f services/api/compose.yaml stop places-db`. The volume preserves the catalog. The laptop must remain awake for fresh search. For explicitly selected file mode, stop the API and run `.\tool\start-places.ps1 -Mode file`; it never activates automatically. Mode mismatches are rejected rather than silently reusing the wrong server.

For a data refresh: stop the API, run `.\tool\prepare-places.ps1 -Refresh`, run `.\tool\prepare-places-db.ps1`, then start the API again. Restarting reloads catalog source metadata. An import transaction updates the complete snapshot, removes absent source IDs and retains separate corrections; a failed transaction retains the previous catalog.

## Verified evidence

| Check | Observed result |
| --- | --- |
| Runtime | Docker Engine 29.7.2; PostgreSQL 17.5; PostGIS 3.5.2; pg_trgm 1.6 |
| Source | OSM France snapshot dated 2026-10-17T01:12:44Z; same bounded input documented in [Feasibility](FEASIBILITY.md) |
| Initial import | 12,245 records and 12,245 distinct source IDs; approximately 7.1 seconds |
| Repeat import | Same record count and stable source IDs |
| Automated checks | All 16 API tests pass, including six isolated PostGIS integration cases |
| Corrections | Synthetic source-linked aliases survive update, removal and repeat import; no real-world correction is fabricated |
| Rollback | A deliberately rejected row rolls back prior writes and import metadata in the same transaction |
| Proximity | 100-metre test excludes an approximately 111-metre point; correct longitude/latitude order; GiST `places_position` used on actual pilot data |
| Spatial sample | Approximately 12.5 ms execution for a 100-metre pilot query, including initial geographic calculation overhead |
| Text plan | Correction-aware text query used a sequential scan; PLP sample execution approximately 5.1 ms. Do not claim that the trigram index serves every query |
| HTTP sample | Six public search terms, three requests each: per-term medians approximately 19–44 ms; maximum 99.9 ms, including startup effects |
| Persistence/outage | All 12,245 records survive container stop/start; API returns 503 during outage and recovers in PostGIS mode without file fallback |
| Android | Pixel 6 API 36 returns the real PLP autocomplete result through the database; Back preserves the current day |
| Resource sample | Database approximately 42 MB on disk and 126 MiB RAM within its 512 MiB cap; roughly 7.9 GB host disk free after setup |

Measurements are observations on this laptop, not capacity guarantees. No graph, road route, branch recommendation or field-coverage certification is implied. Integration tests leave no `wayday_verify_*` databases after successful completion. If tests are forcibly interrupted, inspect ownership before removing any leftover test database. Never clear the `wayday` catalog to run tests.

Two runtime issues were fixed: snapshot removals now use actual source-ID membership even when extract checksums remain unchanged, and readiness source dates refer to the active catalog rather than newer historical import metadata. Import engines are disposed after both success and failure.

## Interpretation contributor boundary

This batch changes backend catalog persistence, test infrastructure, local scripts and documentation only. It does not modify Flutter source, interpretation rules, reviewed-suggestion acceptance, original-text preservation, timing semantics or notes. SHA-256 comparison confirmed `errand_interpreter.dart` and its tests are unchanged. Place-name aliases such as PLP are catalog lookup aids, not an interpretation of an activity such as “bili gamot.”

The existing `GET /v1/places` and `/v1/places/nearby` wire contracts remain unchanged. See [the API guide](../../services/api/README.md). Any future interpretation integration should provide explicit structured place intent through the existing review boundary; it must not silently overwrite confirmed user values. Flexible branch recommendations and road scheduling remain M3 work.

## Remaining work

- M2-02: native permission denial, approximate/disabled location, physical GPS and device behavior.
- M2-04: representative local place/branch checks, missing records, hours honesty, actual correction evidence and coverage reporting. The existing correction table supports aliases; broader catalog corrections need their own implementation.
- M3: Valhalla graph and profile validation, then independently checked OR-Tools schedules.
- Public hosting, accounts, notifications, live sharing and deployment remain later milestones. This is a local development service with no uptime guarantee.

See [Planning](../../PLANNING.md), [Progress](../../PROGRESS.md) and [the implementation plan](IMPLEMENTATION_PLAN.md).
