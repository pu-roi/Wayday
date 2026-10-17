# Pasig/Ortigas pilot feasibility

Observed on 2026-10-17. This is an M2 prerequisite spike, not a routing or map acceptance result. See [the approved plan](IMPLEMENTATION_PLAN.md) and [task board](../../PLANNING.md).

## Observed environment

| Check | Observation | Implication |
| --- | --- | --- |
| Physical memory | 15.8 GB | Measure combined emulator, database, import and routing use before running everything together |
| Logical processors | 8 | Does not establish solver/graph throughput |
| Free space on C: | Approximately 15.8 GB before this batch's builds | Measure peak import, graph and image space; do not assume a full-country import fits |
| WSL | docker-desktop distribution registered | No ordinary development Linux distribution was listed |
| Docker | CLI installed; Linux engine pipe unavailable | PostGIS and Valhalla containers were not running during the check |
| Android | emulator-5554 connected | Emulator can verify startup/storage; it cannot establish physical background behavior |

No geographic extract, container image or graph was downloaded. No service was started or exposed. RAM/disk observations are a point-in-time baseline, not minimum requirements or production sizing.

## Reproducible next gate

1. Enable an existing suitable Linux/container runtime and verify it can run a disposable local container. Keep listeners local. Do not create cloud accounts or activate billing.
2. Obtain a dated, bounded OSM extract covering Pasig/Ortigas with enough surrounding roads for actual journeys. Record source, attribution, size and clipping method; keep extracts/graphs under ignored local-data paths.
3. Before importing, estimate the peak space of input, intermediate files, database, graph, runtime images and builds, plus host headroom. Stop if it exceeds available storage. Do not silently expand to a country graph.
4. Import source-keyed POIs into PostGIS using SRID 4326 coordinates. Use geography or a suitable metric projection for metre-based bounded searches. Retain original hours, source date and separately sourced corrections. Inspect grocery/market, pharmacy, bank, haircut and coffee coverage; unknown hours stay unknown.
5. Build a separate Valhalla graph; record extract date, graph version, build time, peak RAM, disk and warm/cold matrix latency. Measure asymmetric/unreachable legs rather than substituting straight lines.
6. Test walking, biking, motorcycle, sedan and pickup/light-truck profiles against local access cases. Validate vehicle dimensions separately from ground clearance. Do not claim motorcycle or pickup suitability from engine availability alone.
7. Record measured outcomes here before enabling real planning. Unsupported regions, missing catalog data and provider outages must remain explicit in the application.

## Service boundaries and costs

- MapLibre/OpenFreeMap display the basemap. Neither supplies the application's regional business catalog or scheduler. Keep attribution visible and respect provider offline limits.
- Use imported OSM data for normal search. Public Nominatim autocomplete and systematic POI enumeration are prohibited; public Overpass/Valhalla demos are not deployment backends.
- Existing hardware is the initial compute. A sleeping laptop is unavailable. No permanent zero-cost public API/routing hosting has been established.
- Supabase database/Auth hosting is evaluated only against measured catalog/shared-data size, pausing, egress, backups and access controls. Python and road-graph compute need separate capacity.
- Current fallback is local editing and saved data. Fresh search/planning must report unavailability; do not synthesize business hours, place coordinates or road times.

## M1 verification alongside this spike

The native SQLite file was created by the Android app. A new errand survived force-stop and an airplane-mode COLD launch on emulator-5554 (Android 16). Its title and six-errand count were confirmed from a fresh post-launch accessibility capture; the temporary entry was then removed. This verifies native restart/offline storage, not physical GPS, reminder delivery or road routing. Automated checks also cover schema snapshots, transaction rollback and preserving unknown/future data.


## M2 bounded place-catalog implementation

A checksum-verified OSM France Metro Manila extract was imported on 2026-10-17. The source header timestamp is `2026-10-17T01:12:44Z`; source URL and checksum are retained in ignored import metadata. The input was 61,267,747 bytes. The importer retained only the documented pilot rectangle, producing 12,245 named places in a 3,497,877-byte JSON read model. A second import took 75.0 seconds and retained exactly the same sorted source IDs; replacement is atomic. These are point-in-time observations, not performance guarantees or full field-coverage verification.

In a local in-process sample, searches for PLP, Pamantasan, Mercury, Puregold, coffee and gym completed in roughly 4–7 ms. PLP ranked the mapped Pamantasan ng Lungsod ng Pasig first. The snapshot contains 1,376 records with hours text; these remain unverified. All other hours are unknown. Category and address coverage are incomplete, aliases can collide, and polygon representative points are not entrances. Adjacent-city records occur inside the pilot rectangle. No fresh road calculation is implied.

The existing Docker Desktop engine failed to become available, including a host socket startup error. No database container, PostGIS import or SQL query plan was validated. The local FastAPI service therefore uses explicitly configured file snapshot mode; it never falls back automatically from a failed database. The PostGIS baseline and adapter are implemented but retain an open runtime gate. No account, billing or public deployment was created. See [the service guide](../../services/api/README.md).

Native emulator checks established real search results, a moved center pin, a cancelled location request and a simulated GPS fix at a known Pasig coordinate. Reported 5-metre accuracy was emulator metadata, not measured physical accuracy. An AVD cold start with software GPU settings recovered black application frames; neither the exact host fault nor physical-device frame rate was established. Android is now portrait-only; rotation-lock and final captures are verified separately in the progress log.


## M2-03 runtime gate closed

The earlier Docker failure is historical. After the owner started Docker successfully, local PostGIS setup and the M2-03 runtime gate passed. The catalog contains 12,245 distinct source IDs, repeat imports preserve the count, and six isolated-database cases plus ten API cases pass. A controlled database stop returned 503 from the live API; restart recovered without file fallback and retained all records. The native Android chooser returned the real PLP result through PostGIS. Interpretation and its tests were unchanged.

Initial import took approximately 7.1 seconds. A 100-metre proximity plan used `places_position` (GiST), with approximately 12.5 ms execution in one sample. Correction-aware PLP text search used a sequential scan at approximately 5.1 ms; its trigram index must not be claimed as used by that query. Six public search terms with three HTTP requests each had per-term medians around 19–44 ms and a maximum of 99.9 ms. The database used approximately 126 MiB against its 512 MiB cap in one sample, and host disk free space was roughly 7.9 GB after setup. These measurements do not authorize geographic expansion or establish production capacity. The Valhalla graph remains unbuilt.

See [the database handoff](M2_DATABASE_HANDOFF.md) for commands, isolated-test safety, verified versions and remaining M2-02/M2-04 gates. No real-world hours or entrance correction was inferred from the database tests.


## M2-07 mapped areas and residential coverage

On 2026-10-18 the bounded importer was extended to named residential areas and place/neighbourhood records, and retained valid source MultiPolygon footprints. The snapshot now has 13,033 records. Grand Monaco La Impreza is source relation 17592405, already present in the downloaded extract but previously excluded by the category filter. It now appears in both PostGIS and explicit file-mode search. This is a filter correction, not an invented location or field validation of its extrapolated source geometry.

Migration 002 adds optional footprints and an index without dropping existing data or corrections. Seven PostGIS integration cases and eleven non-database API cases pass, including old point-only imports, area containment beyond a centroid radius, boundaries, holes and broad-city exclusions. Native Android inspection confirmed a moved PLP pin retained its real name and selected coordinates. Both chosen From/To endpoints cleared after cold launch; Recurring groups were initially collapsed. Physical GPS and full pilot quality checks remain open.
