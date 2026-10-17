# Wayday local place service

M2 provides real name/landmark/address suggestions without interpreting errands. Personal notes and task lists are never sent to this API. No planning, routing, authentication or sharing endpoints exist yet.

See [Running Wayday](../../docs/wayday/RUNNING_WAYDAY.md) for contributor modes. UI/interpretation work needs no Docker or API; file-mode place search needs Python but no Docker. The supplied full PostGIS setup uses Docker.

## Quick start on Windows

From the repository root:

```powershell
.\tool\prepare-places.ps1
.\tool\prepare-places-db.ps1
.\tool\start-places.ps1
```

Preparation creates the ignored `.tools/api-venv`, installs the committed dependency lock, downloads the Metro Manila extract from [OSM France](https://download.openstreetmap.fr/extracts/asia/philippines/), checks its published MD5 for transfer consistency and imports only the Pasig/Ortigas rectangle. The checksum is not an authenticity signature. The first download is approximately 61 MB at the recorded source date. Do not expand coverage without measuring resources. All extracts, generated snapshots, credentials and logs stay under ignored paths.

Open Docker Desktop first and wait for its Linux engine. Database preparation prompts once for a local password, starts the project-scoped PostGIS container, waits for readiness and imports the snapshot. It stores a Windows-user-encrypted credential in the ignored `data/local/places-db.credential.xml`; another contributor creates their own local credential. No password or connection URL is bundled into the app. If `WAYDAY_DB_PASSWORD` is already supplied, preparation can use it without prompting. An existing saved credential takes precedence; changing an environment variable does not reset an initialized database password.

The startup script now defaults to **PostGIS mode**. It loads the local credential and listens only on `127.0.0.1:8780`; access logs are disabled so queries and pin coordinates are not logged by Uvicorn. `/health` must report `catalog_mode: postgis`. It never falls back automatically from a failed database. An API already running in another mode must be stopped explicitly.

For an explicitly chosen lightweight development alternative, stop the API and use `.\tool\start-places.ps1 -Mode file`. File mode is a bounded in-memory read model using the real source-backed snapshot, not fixtures or a personal database. It does not apply PostGIS correction records and must not be used as evidence that database integration passed.

Android emulators reach it at `http://10.0.2.2:8780`. The Flutter app uses this default on Android. On a physical USB device, use `adb reverse tcp:8780 tcp:8780` and run Flutter with `--dart-define=WAYDAY_API_URL=http://127.0.0.1:8780`. The debug manifest permits HTTP for this local setup; a release needs a configured HTTPS endpoint. The laptop must remain awake and the service must be running. No LAN listener or public deployment is needed.

Stop the managed API with `.\tool\stop-places.ps1`. It checks the recorded PID, Python executable and command, including a matching Windows venv child process, before stopping anything. Stop only this database with `docker compose -f services/api/compose.yaml stop places-db`; its named volume retains the catalog. To refresh data, stop the API, run `.\tool\prepare-places.ps1 -Refresh`, run `.\tool\prepare-places-db.ps1`, then start the API again. Snapshot replacement and database imports are atomic. Restart the API after an import to reload source metadata; file mode also retains its loaded records until restarted.

## Contract

OpenAPI is available at `http://127.0.0.1:8780/docs` while running.

| Endpoint | Input | Meaning |
| --- | --- | --- |
| `GET /health` | None | Readiness, configured mode and source date; includes an actual catalog read |
| `GET /v1/places` | `q` (2–100 characters), `limit` (1–12, default 8), optional paired `near_lat`, `near_lon` | Search mapped names, addresses and aliases within the fixed pilot rectangle |
| `GET /v1/places/nearby` | `lat`, `lon` in degrees | Up to three containing named areas or mapped landmarks within 100 metres; area representative points can be farther away |

Responses include `places`, `coverage` and attribution. A place includes source ID/URL/date, name, nullable address, coordinates, category, coordinate kind, nullable raw opening-hours text, hours status and optional straight-line distance in metres. Distances are never road distances or travel estimates. Missing hours are `unknown`; recorded hours are `unverified`, never a claim that a business is open now. Polygon representative points are explicitly distinguished from mapped point coordinates; neither establishes an entrance. API responses are `no-store`.

Invalid parameters return 422. An unavailable/missing catalog returns 503 with `detail.code = catalog_unavailable`. A successful empty result remains distinct from an outage. There are no request-time Nominatim, Overpass or other community geocoder calls. The Flutter client debounces search, applies a five-second timeout and ignores stale responses; manual map selection and saved places remain available on failure.

Nearby responses add optional `match_kind`: `area` means the point is covered by an imported mapped footprint, `point` means a mapped point is within 10 metres, and `nearby` means proximity only. The app prefers a unique containing place; otherwise a unique point may supply the name. Ambiguity and merely nearby matches require explicit selection. Broad city/place boundaries are excluded from automatic identity. This is map lookup, not interpretation or entrance verification. Footprints stay server-side, keeping responses bounded. PostGIS uses [ST_Covers](https://postgis.net/docs/ST_Covers.html), including polygon boundaries and respecting holes; explicit file mode applies the equivalent geometry predicate.

The 2026-10-18 import contains 13,033 records, including named residential areas and neighbourhoods. Grand Monaco La Impreza (`osm/relation/17592405`) was present in the extract but omitted by the former category filter; it is now searchable. Source geometry and hours remain unverified in the field. Migration `002_place_footprints.sql` adds an optional geometry column and GiST index, preserving existing places and corrections. Regenerate an older point-only snapshot with the importer before preparing the database, as described in [the run guide](../../docs/wayday/RUNNING_WAYDAY.md).

Bounds, in longitude/latitude order: west `121.035`, south `14.525`, east `121.115`, north `14.615`. This is a pilot rectangle, not an administrative boundary. Some adjacent-city places fall within it; the rest of Metro Manila is not covered. OSM name variants and initials derived from mapped names support abbreviations such as PLP; this is separate from errand interpretation. Alias collisions can produce multiple results, so the user selects a specific place.

## Verified local PostGIS runtime

`compose.yaml` provisions a local-only PostgreSQL/PostGIS development database, limited to 512 MB, with a named volume and a password supplied through `WAYDAY_DB_PASSWORD` outside source control. It does not start automatically. The initial migration is `migrations/001_places.sql`. `PostgisCatalog` uses bound SQL, bounded connection/query waits, trigram search and indexed geography queries in metres with SRID 4326. The importer upserts source IDs and removes stale catalog entries transactionally while retaining separately sourced correction records.

The normal scripts above configure local PostGIS automatically. For an explicitly configured development connection:

```powershell
# Set a locally generated WAYDAY_DB_PASSWORD without committing it.
docker compose -f services/api/compose.yaml up -d
# Set WAYDAY_DATABASE_URL to a postgresql+psycopg connection URL locally.
.\.tools\api-venv\Scripts\python.exe services/api/tools/import_postgis.py
$env:WAYDAY_CATALOG_MODE = 'postgis'
.\.tools\api-venv\Scripts\python.exe -m uvicorn wayday_api.app:app --app-dir services/api/src --host 127.0.0.1 --port 8780 --no-access-log
```

The M2-03 runtime gate passed on 2026-10-17: PostgreSQL 17.5, PostGIS 3.5.2 and pg_trgm 1.6 imported 12,245 unique places, retained them through restart, and served real Android searches. Six isolated-database integration cases verify repeat imports, updates/removals, correction retention, complete transaction rollback, metric proximity and HTTP outage/recovery without file fallback. A controlled stop/start of the pilot database also returned 503 and recovered. Query plans confirmed the GiST proximity index. Text search currently uses a sequential scan for its correction-aware query; measured pilot latency is acceptable, but no larger-scale performance claim is made. See [the handoff and measurements](../../docs/wayday/M2_DATABASE_HANDOFF.md).

This completes backend runtime verification, not M2-04 place quality or all of M2. File mode does not apply the separate correction table; a manually moved pin remains the user correction path in the app. Only independently verified, source-linked aliases belong in that table. The correction table currently supports aliases, not a general catalog editing UI.

## Checks, privacy and licensing

```powershell
.\tool\verify-places-db.ps1
```

The verification script runs all 18 tests and checks the live API is ready in PostGIS mode. Seven integration tests create and drop uniquely named synthetic databases on this local server, never clear the pilot catalog, and require database-creation privileges. For unit-only work, `python -m pytest services/api -q` runs the eleven non-database cases and skips those seven unless `WAYDAY_TEST_DATABASE_URL` is configured. Fixtures are synthetic; live downloaded datasets are not committed. Tests cover aliases/provenance, metric bounds, unknown hours, missing catalogs, validation and database transaction behavior. Android emulator tests separately establish real search; physical GPS accuracy and journeys remain separate checks. A Starlette/httpx TestClient deprecation warning is recorded; the pinned test suite passes and no dependency migration is implied.

OSM data is [ODbL 1.0](https://www.openstreetmap.org/copyright); preserve attribution and review derived-database obligations before distributing a catalog. Data freshness does not establish field accuracy. FastAPI, Uvicorn, Psycopg, SQLAlchemy, PyOsmium and Shapely are free local dependencies with their respective upstream licenses; no account, trial expiry, billing or guaranteed hosting is involved. The lock includes development/import tools. This local service has no public availability commitment or production hardening claim.
