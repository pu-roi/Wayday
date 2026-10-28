# Regional routing feasibility evidence

Measured on 2026-10-27 for M5-01. The [machine-readable measurements](routing-pilot-2026-10-27.json) retain public sample coordinates, source/version hashes, profile parameters, road estimates, asymmetric matrices and resource evidence. This is local engine feasibility, not a public API, completed planner, observed travel-time benchmark or physical road-safety verification.

## Outcome and supported boundary

Valhalla 3.9.1 built the buffered OSM graph and returned all 18 sampled routes and six four-by-four matrices. Walking, biking, motorcycle, sedan and separate pickup/heavy-delivery evaluation fixtures are executable. All six unordered pairs were asymmetric in each of the five non-walking matrices; the walking sample was symmetric. All 96 sampled matrix cells were reachable. An explicit outside-graph probe returned HTTP 400 / engine code 171, not a fabricated zero-time leg. It does not establish an unreachable pair inside the pilot.

The supported study box remains west/south/east/north `[121.045, 14.548, 121.116, 14.617]`. The graph box adds 0.04 degrees on each side (approximately 4.3–4.4 km); full source way/restriction members may extend beyond it. A journey near a graph boundary must be investigated for clipping before being declared disconnected. Public-site positions came from the completed place audit and are not surveyed entrances. Route endpoints snapped 15.2–36.3 meters from those positions.

## Resource measurements

The XML source was 75,038,987 bytes and converted PBF 5,973,189 bytes. `osmium check-refs --check-relations` found zero missing way nodes or relation members. The graph and accompanying PBF/timezone files occupied 177,084,082 bytes on the task-owned Docker volume. The official AMD64 image occupied 673,581,738 bytes. Two threads and a 4 GiB memory cap were used; the native-volume build recorded a cgroup peak of 352,440,320 bytes. This is container memory, not total Windows/WSL memory.

Graph-stage logs recorded 39 seconds for initial build and 13 seconds for enhancement through cleanup. The collector's 168.901-second readiness upper bound also includes startup and delayed observation, and is not the graph-only duration. The first attempt additionally downloaded the 2026d timezone polygons (about 74 MiB compressed) and produced a 122,478,592-byte timezone database. Its cgroup peak was 390,639,616 bytes. Network/download, conversion, extracted timezone scratch files, Docker layers and host VM overhead are separate resource costs; these figures are not a total installation-size promise.

The recorded repeat evaluation's median request latency was 0.063 seconds and maximum 0.265 seconds across 18 routes plus six 4x4 matrices. This measures a warm local engine. The proposed 38-location contract budget still requires a later load test.

## Vehicle and restriction findings

- Walking uses pedestrian costing; biking uses bicycle costing. Source-way trace review found pedestrian-access roads in the walking result and a bicycle-permitted, motor-vehicle-prohibited F. Concepcion Street segment in the bicycle result. Motorized traces used different streets. These are comparisons with the same OSM snapshot, not independent legal-access verification.
- Motorcycle costing is marked beta in the [official API reference](https://valhalla.github.io/valhalla/api/route/api-reference/). Successful pilot requests do not establish comprehensive Philippine motorcycle restrictions.
- Sedan and pickup fixtures use auto costing. Pickup dimensions were sent explicitly as synthetic representative fixtures; this evaluation does not independently prove all auto dimension restrictions are enforced. It does not assign those dimensions to users.
- Heavy-delivery uses truck costing with explicit dimensions, total/axle weight, axle count, hazard status and an explicit finite HGV access penalty; that penalty is not a legal-access prohibition or guarantee. The 12-ton fixture traversed OSM way 23395375, tagged `maxweight=15`; a 20-ton fixture avoided that way and produced a longer alternate route. This verifies one mapped weight comparison, not citywide truck-ban, time-conditional, axle, width, height or surface correctness.
- Buffered source ways had 610 `hgv`, 276 `maxheight`, 179 `maxweight`, one `maxwidth`, one `maxlength` and no `maxaxleload` tags. Missing values remain unknown. Vehicle height concerns overhead clearance; no ground-clearance model or passability guarantee exists for any profile.

The gate permits proceeding with explicitly qualified static road estimates and contract work. It does not enable a claim of clearance-aware or legally certified heavy-vehicle routing. Keep those limitations visible in later calculation/review and record unsupported capability requests explicitly. No live traffic, elevation import, international-border behavior or observed driving-time accuracy was evaluated. The admin database was disabled for the bounded local study; timezone data was retained.

## Reproduction and environment recovery

Run from the repository root, using the existing Docker Desktop installation. No account or global policy change is required:

```powershell
py -m venv .tools/routing-venv
./.tools/routing-venv/Scripts/python.exe -m pip install -r tools/routing/requirements.txt
docker desktop start --timeout 60
./.tools/routing-venv/Scripts/python.exe tools/routing/prepare_graph.py fetch
./.tools/routing-venv/Scripts/python.exe tools/routing/prepare_graph.py convert
```

The fetch is a bounded, identifying Overpass research request, not an application backend. It records the query, snapshot, hashes and source restrictions under ignored `data/downloads/routing-pilot/`. Do not rerun it for routine tests. Conversion uses the pinned Linux build-time image because Windows Application Control blocked pyosmium's native DLL; the policy was left unchanged.

Windows bind-mounted graph random I/O stalled in `p9_client_rpc`. Use a fresh task-owned Docker volume for graph work, then export only needed measurements/graph files to ignored data directories. For a new run, copy `pilot.osm.pbf` into that volume first; copying a compatible previously built `timezones.sqlite` avoids repeating the timezone download. Example for the initial volume name, only when it does not already exist:

```powershell
docker volume create wayday-routing-pilot-graph
docker run --rm --network none --entrypoint sh -v "D:/Documents/Github/Wayday/data/local/routing-pilot:/input:ro" -v wayday-routing-pilot-graph:/output ghcr.io/valhalla/valhalla-scripted@sha256:31d96eb75f73e5f5b3dc40702edfda16c4e1793a384a8235bcf00dd3eed1b9bc -c "cp /input/pilot.osm.pbf /output/"
./.tools/routing-venv/Scripts/python.exe tools/routing/run_graph.py --named-volume wayday-routing-pilot-graph
./.tools/routing-venv/Scripts/python.exe tools/routing/evaluate_routes.py
./.tools/routing-venv/Scripts/python.exe tools/routing/publish_evidence.py
```

The runner refuses to overwrite an existing evaluation container. Reuse its completed measurement with `--collect-existing`, or choose and coordinate a fresh run explicitly. It binds only `127.0.0.1:18002`, avoiding unrelated containers already occupying port 8002. Starting Docker Desktop automatically resumed two pre-existing containers; the evaluation did not reconfigure, stop or delete those containers, or change Docker settings. The task-owned `wayday-routing-pilot` container was stopped after verification; retain its measurements and source graph for reproducibility. Graphs, raw downloads, logs and databases stay ignored. Valhalla is MIT; build-time osmium-tool is GPL-3.0; OSM and timezone-derived data require attribution and applicable ODbL obligations. No public service or generated graph is published by this change.
