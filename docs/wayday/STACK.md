# Technology stack and dependency inventory

Initial research: 2026-10-15; mapping research and selected next direction updated 2026-10-27. Flutter and Today/Recurring Drift/SQLite storage are implemented. MapLibre/Protomaps, place search, navigation handoff, and later routing/solver choices below are planned and uninstalled unless explicitly listed as current dependencies. No external account or paid service has been provisioned.

Platform sequencing clarified on 2026-10-16: build and verify Android first; iOS comes later. The iOS considerations below apply to that later phase and do not block Android development.

## Mobile options

| Option | Fit for Wayday | Tradeoff |
| --- | --- | --- |
| **Flutter / Dart — selected** | One Android/iOS UI implementation, custom map overlays and timeline screens, structured offline persistence | The team learns Dart and still needs native platform work for geofences |
| React Native / TypeScript | Strong alternative for a team already comfortable with React; supports native modules | The HTML prototype is not a reusable React app; platform permissions and native map integration still need work |
| Separate Kotlin and Swift apps | Direct platform control | Two applications increase implementation and maintenance work for a small capstone team |

The recommendation reflects the owner's Flutter preference and the proposed UI, not a claim that Flutter always outperforms React Native. Both frameworks require platform-specific configuration. See [Flutter architecture](https://docs.flutter.dev/app-architecture/guide) and [React Native setup](https://reactnative.dev/docs/set-up-your-environment).

## Backend options

| Option | Fit for Wayday | Decision |
| --- | --- | --- |
| **FastAPI / Python — selected** | Typed request validation and direct Python access to OR-Tools | Use a modular monolith |
| Django / Django REST Framework | Useful when administration, account management, and conventional content workflows dominate | Extra framework scope is unnecessary for the initial planner API |
| NestJS / TypeScript | Attractive for a TypeScript team and conventional API services | No official OR-Tools TypeScript binding; would require a separate solver integration |
| Supabase Cloud | Hosted PostgreSQL/PostGIS and optional future authentication | Deployment candidate; does not replace the Python optimizer or routing engine |

See [FastAPI](https://fastapi.tiangolo.com/) and [OR-Tools supported languages](https://developers.google.com/optimization/introduction).

## Planned libraries and licenses

This inventory records intended direct dependencies and license families. Exact versions, native/transitive dependencies, notices, and platform minimums must be reviewed when scaffolding. It is not a completed audit of a shipped binary.

| Component | Purpose | License / official reference |
| --- | --- | --- |
| Flutter / Dart | Mobile SDK and language | BSD-style; [Flutter license](https://github.com/flutter/flutter/blob/master/LICENSE), [Dart license](https://github.com/dart-lang/sdk/blob/main/LICENSE) |
| `flutter_riverpod` | View-model state and dependency injection | MIT; [license](https://pub.dev/packages/flutter_riverpod/license) |
| `go_router` | Screen navigation | BSD-3-Clause; [license](https://pub.dev/packages/go_router/license) |
| Drift / SQLite | Phone persistence and migrations | MIT / public domain; [Drift license](https://pub.dev/packages/drift/license), [SQLite](https://sqlite.org/copyright.html) |
| `maplibre_gl` | Native map rendering and offline regions | BSD-style with bundled notices; [repository and license](https://github.com/maplibre/flutter-maplibre-gl) |
| `geolocator` | Current location and permissions | MIT; [license](https://pub.dev/packages/geolocator/license) |
| `flutter_local_notifications` / `timezone` | Local notifications and zoned scheduling | BSD-style; [notifications license](https://pub.dev/packages/flutter_local_notifications/license), [timezone license](https://pub.dev/packages/timezone/license) |
| FastAPI / Pydantic | HTTP API and validation | MIT; [FastAPI](https://fastapi.tiangolo.com/), [Pydantic license](https://github.com/pydantic/pydantic/blob/main/LICENSE) |
| SQLAlchemy / Alembic | Database access and migrations | MIT; [SQLAlchemy license](https://github.com/sqlalchemy/sqlalchemy/blob/main/LICENSE), [Alembic license](https://github.com/sqlalchemy/alembic/blob/main/LICENSE) |
| PostgreSQL / PostGIS | Geographic catalog and spatial queries | PostgreSQL License / GPL-2.0-or-later; [PostgreSQL](https://www.postgresql.org/about/licence/), [PostGIS licensing](https://github.com/postgis/postgis/blob/master/LICENSE.TXT) |
| Valhalla | Road routes and travel-time matrices | MIT; [repository](https://github.com/valhalla/valhalla) |
| OR-Tools | Branch selection and stop scheduling | Apache-2.0; [repository](https://github.com/google/or-tools) |
| Flutter test tools / pytest / Ruff | Verification and code checks | SDK license / MIT; [pytest](https://github.com/pytest-dev/pytest), [Ruff](https://github.com/astral-sh/ruff) |

Use native Android and iOS geofencing APIs through a small Flutter bridge. `geolocator` alone is not a complete killed-app geofence solution. Do not substitute a tracking SDK based only on a permissive wrapper license: some native engines require a paid release license. For example, [flutter_background_geolocation](https://pub.dev/packages/flutter_background_geolocation) advertises release licensing separately from debug access.

The shell bundles Figtree and its SIL Open Font License in `apps/mobile/assets/fonts/`; it makes no runtime font requests. Material icons come from the Flutter SDK. A simple route mark is authored as a native vector and browser favicon.

## Current mobile versions

- Flutter 3.47.8 stable, Dart 3.13.7, Riverpod 3.4.3, GoRouter 18.1.0, Drift 2.35.3, drift_flutter 0.3.1, and flutter_lints 6.0.0. Drift's dev tooling uses drift_dev 2.35.2 and build_runner 2.17.1; see `apps/mobile/pubspec.lock` for exact resolved dependencies.
- Android project generated by this Flutter SDK: compile/target API 36, Android Gradle Plugin 9.1.0, Gradle 9.3.1, and NDK 28.2.13676358. Java source/target compatibility is 17. M1-01 recorded Microsoft OpenJDK 21.0.12.1; Stage 1 verification uses the machine's configured Android Studio OpenJDK 25.0.3.
- The wrapper prefers the ignored `.tools/` Flutter SDK and uses local package/Gradle cache paths. It also uses optional `.tools/android-sdk` and `.tools/jdk` installations when present; otherwise Android/JDK tooling comes from the existing machine configuration. Android local.properties remains ignored. These are development dependencies, not files to commit or services to deploy. No global PATH modification is required.
- Figtree is sourced from [Google Fonts](https://github.com/google/fonts/tree/main/ofl/figtree) under SIL OFL 1.1. Its license ships beside the font. This is not a completed license audit of a release binary.

## Data and service boundaries

### Maps: MapLibre, Protomaps, and a Wayday style — selected, not installed

Research and owner direction recorded 2026-10-27. MapLibre is the renderer; Protomaps supplies an OSM-derived regional basemap; PMTiles is its archive format. The selected Flutter binding, native requirements, resource use, and regional package size still need the M3 feasibility checks. Do not treat a README feature matrix as verification in this app.

#### Regional package preparation evidence

M3-02 prepared the rectangular pilot package from Protomaps build `20261026.pmtiles`, schema 4.15.2, source snapshot `2026-10-26T04:00:00Z`, with zooms 0–15. The extracted archive is 8,046,175 bytes; the complete package is 14,418,095 bytes including its 47,944-byte manifest. Its 268 payload files include all 256 Noto Sans Regular glyph ranges, four light sprite resources, an authored Wayday style and license/provenance notices. Every payload has a SHA-256 inventory entry. The manifest SHA-256 is `f7f6365e029031a8d8a6bc4b2b3884a6decad867071a89a68c98235b9f60a798`.

`pmtiles` 1.31.2 extracted 114 tiles using four download threads, 40 requests and 8.4 MB transferred in 17.30 seconds; archive/header/metadata verification passed. A cached repeat preparation completed in 7.58 seconds with identical manifest and payload hashes. The cached Python process peak working set was 28,422,144 bytes; this excludes archive extraction, the native renderer and host memory. Two decoded source tiles contained nonempty roads/buildings/POIs, which establishes vector content rather than road routability or searchable-business completeness.

Fonts/sprites are pinned to `protomaps/basemaps-assets` commit `028c18f713baecad011301ff7a69acc39bcc2ae7`, with downloaded bytes checked against its Git blob inventory. Noto glyphs retain SIL OFL 1.1; sprite icons retain the upstream MIT notice; OSM/Protomaps attribution and source notices travel with the package. No remote resource URL is used as a rendering fallback. Five offline failure tests cover corruption, missing glyphs, unsafe paths, network-resource rejection and preserving repository markers/prior packages. Preparation tooling and the style are tracked under `tools/maps/`; raw/generated/app-package resources remain ignored. Android native/offline rendering remains M3-03, rather than a result of package preparation.

Protomaps basemap code is BSD-3, map design is CC0, and OSM-derived tiles require visible OSM attribution and applicable data obligations. PMTiles reference implementations are BSD-3 and the format is an open specification. Supply the style, fonts/glyphs, sprites, notices, and manifest as well as tiles for offline rendering. MapLibre Native/Flutter supports PMTiles, but a remote archive still needs networking; evaluate a local regional archive on Android. Keep the last valid version during package replacement.

Sources: [MapLibre Flutter](https://github.com/maplibre/flutter-maplibre-gl), [PMTiles integration](https://github.com/maplibre/flutter-maplibre-gl/blob/main/website/docs/advanced/pmtiles.md), [Protomaps licensing](https://github.com/protomaps/basemaps#licensing-and-attribution-guidelines), [regional extraction](https://docs.protomaps.com/pmtiles/cli), [style assets](https://docs.protomaps.com/basemaps/maplibre).

Use a custom Wayday style for streets, city names, landmarks, POI icons, zoom-dependent labels, and selected stops. Maputnik is an MIT-licensed style editor. Style filters cannot expose POIs or attributes absent from the tile schema, so keep search in a separate catalog. Map styles do not change the fixed light application theme. [Maputnik](https://github.com/maplibre/maputnik), [MapLibre layers](https://maplibre.org/maplibre-style-spec/layers/), [Protomaps layer contents](https://docs.protomaps.com/basemaps/layers).

| Alternative | Cost/license boundary | Current disposition |
| --- | --- | --- |
| flutter_map | BSD-3; pure Flutter; vector capabilities depend on additional packages | Fallback renderer if measured MapLibre integration is unsuitable; [source](https://github.com/fleaflet/flutter_map) |
| OpenMapTiles / Planetiler | OpenMapTiles code BSD-3, design CC-BY 4.0; Planetiler Apache-2.0; generation uses local compute/storage | Alternative tile-generation pipeline if the selected schema lacks needed content; [OpenMapTiles](https://github.com/openmaptiles/openmaptiles), [Planetiler](https://github.com/onthegomap/planetiler) |
| OpenFreeMap | Free public service without an SLA; offline downloads limited to 3,000 tiles or 50 MB, at most four parallel requests, identifying User-Agent | Not the selected provider/design direction after owner feedback; [terms](https://openfreemap.org/tos/) |
| MapTiler Cloud | Free plan restricted to non-commercial/R&D use; current page lists 100k API requests/month, pauses at exhaustion, and Flex from USD 30/month | Not the default zero-spending dependency. Third-party renderers generate tile-request usage; [pricing](https://www.maptiler.com/cloud/pricing/), [terms](https://www.maptiler.com/terms/cloud/) |
| Standard OSM raster tiles | Public endpoint policy requires attribution/caching and prohibits offline prefetch | Do not use for offline packages; [policy](https://operations.osmfoundation.org/policies/tiles/) |

Local software avoids a metered map API but still needs development resources, storage, bandwidth, and an update/distribution path. No hosted map account or paid service has been adopted. Record and recheck exact release notices and terms during implementation.

### Places: an indexed regional catalog — planned

Use a separate installed OSM-based POI catalog for initial regional search, with bounded text/category/area queries. Preserve source IDs, snapshot dates, original tags/hours, and separately sourced corrections. The personal Drift database owns errands and confirmed places; public catalog replacement must not erase them. A later PostGIS catalog is conditional on actual server queries, not a prerequisite for local search.

Start by auditing at least 30 public Pasig/Ortigas destinations across relevant categories. Record branch/pin accuracy, duplicates, missing places, hours, and closed-business signals; no measured nationwide completeness is established. Use Philippine categories and aliases supported by the audit. [Philippine conventions](https://wiki.openstreetmap.org/wiki/Philippines/Mapping_conventions).

#### Pilot coverage evidence, 2026-10-27

M3-01 used a frozen, independently selected sample of 35 public destinations within west/south/east/north `[121.045, 14.548, 121.116, 14.617]`. This rectangle includes adjacent-city Ortigas malls; it is not the Pasig administrative boundary. The sample intentionally clusters mall errands, one bank brand and Poblacion landmarks, so its match rates do not estimate population completeness.

| Sample category | Plausible site/branch match | Ambiguous | Not found in bounded review |
| --- | --- | --- | --- |
| Groceries and wet markets | 4 | 0 | 1 |
| Pharmacies | 2 | 1 | 2 |
| Banks | 3 | 2 | 0 |
| Offices | 0 | 0 | 5 |
| Food | 2 | 0 | 3 |
| Haircuts | 0 | 0 | 5 |
| Landmarks | 5 | 0 | 0 |
| Total | 16 | 3 | 16 |

The final Overpass extract contains 11,679 elements and 5,278,128 bytes, with OSM snapshot `2026-10-27T06:59:26Z`; its SHA-256 is recorded in the [audit summary](evidence/pilot-place-audit-summary.json). Only one of the 16 matched sites has an OSM opening-hours value. No entrance or pin received independent field/survey verification. A plausible site match does not verify current operation, a dispensing pharmacy service, inventory, a floor, or an accessible entrance. Original incorrect directory-floor assumptions are retained in the frozen sample and corrected in the reviewed results.

The [35-row results](evidence/pilot-place-audit-results.csv), [frozen references and sample](evidence/pilot-place-audit-sample.json), and [manual review](evidence/pilot-place-audit-review.json) preserve source IDs, dates, coordinate kinds and explicit uncertainty. Raw extracts and failed-request evidence stay under ignored `data/downloads/pilot-audit/`. This supports proceeding to bounded map and road feasibility, not claiming complete automatic destination coverage. Later catalog/recommendation tasks must retain no-candidate/manual-pin paths and qualify branch/service identity. Overture inclusion is deferred until a same-sample comparison demonstrates an attributable improvement and resolves duplicates and source licenses. See D31 in [Decisions](DECISIONS.md).

| Source/tool | License and capability | Limitation or replacement path |
| --- | --- | --- |
| OSM / Geofabrik | ODbL geographic data; Philippines extracts and updates | Attribution/derived-database obligations; uneven POI/hours coverage. Keep manual pins and freshness visible; [licensing](https://www.openstreetmap.org/copyright), [extracts](https://download.geofabrik.de/asia/philippines.html) |
| Overture Places | Optional supplement with per-source CDLA Permissive 2.0, Apache-2.0, and CC0 records | Audit Philippine coverage, source licenses, identities, and duplicates. Existence confidence is not proof of opening hours; [documentation](https://docs.overturemaps.org/guides/places/) |
| AllThePlaces | Published dataset CC0; collection code MIT | Source-chain coverage and collectors vary; no validated Philippine coverage claim. Prefer published output to repeated scraping; [project](https://github.com/alltheplaces/alltheplaces) |
| Photon | Apache-2.0; typo-tolerant multilingual search with geographic bias | Self-hosting needs resources; public demo has throttling and no availability guarantee. Consider only if local search becomes insufficient; [project](https://github.com/komoot/photon) |
| Osmium tools | GPL-3.0 processing utilities for extracts/change files | Build-time data maintenance, not a phone runtime dependency; [manual](https://osmcode.org/osmium-tool/manual) |

Public Overpass is useful for bounded exploration, but operators discourage using its public instances as a consumer-app backend. Use extracts and local indexes for normal app queries. [Operator guidance](https://dev.overpass-api.de/overpass-doc/en/preface/commons.html).

Public Nominatim is not the default search service: it prohibits autocomplete and systematic POI enumeration, caps aggregate application traffic at one request per second, and requires identification, attribution, and switchability. [Usage policy](https://operations.osmfoundation.org/policies/nominatim/).

Refresh public data with regional snapshots initially; evaluate incremental change files only when scale requires them. Keep provenance, deletions, schema compatibility, correction overrides, and atomic replacement explicit. Public-data refresh is not cloud synchronization of personal errands.

### Google Maps navigation handoff — planned

Use explicit Maps URLs with confirmed coordinates; no Google API key is needed for the links. Next-stop navigation is primary. Whole-trip links must respect product/mode support and the documented limit of up to three intermediate waypoints in mobile browsers and nine otherwise. URLs do not return a planning matrix, prove arrival/completion, or preserve every vehicle restriction. Provide an app/browser/readable-destination fallback and retain local trip state. [Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started).

### Application references and research limits

| Repository | Relevant learning | Reuse boundary |
| --- | --- | --- |
| [Room TBA / UPLB](https://github.com/uplbtools/room-tba) | Local aliases, offline search, map-linked details and corrections | MIT code; CC-BY campus map data; OSM/hosted tile and university imports have separate conditions |
| [Sakay.ph original web app](https://github.com/sakayph/sakayph) | Metro Manila map interaction and local destination presentation | MIT frontend; separate backend, not evidence that the current mobile app is open source |
| [Lens / Mapa](https://github.com/Shiiroi/mapa) | Philippine PSGC/boundary filtering and documented sources | MIT code with data notices; a boundary/statistics app, not a nationwide store catalog |
| [Every Door](https://github.com/Zverik/every_door) | Mobile POI collection/correction | GPL-3.0-or-later; code reuse must respect that license |
| [Organic Maps](https://github.com/organicmaps/organicmaps) | Offline search, bookmarks and map packages | Apache-2.0 code; binary maps and server use have separate conditions |
| [Arangkada AI](https://github.com/youngNwis31/arangkada-ai) | Philippines-focused Flutter/POI research reference | README states educational/personal use; do not assume a reusable open-source license |

These were source/documentation references, not apps built or verified in Wayday. Community reports explain risks but are not current service contracts. See the [Overpass operator discussion](https://community.openstreetmap.org/t/overpass-api-performance-issues/140598/182), [MapLibre filtering/cluster example](https://stackoverflow.com/questions/79030353/maplibregl-how-to-filter-by-features), and [Philippine developer cost discussion](https://www.reddit.com/r/PinoyProgrammer/comments/107jk8m/); official policies above govern adoption.

### Routes and optimization: Valhalla and OR-Tools

Run Valhalla locally with a bounded regional graph. Evaluate the five product profiles against its costing models: walking uses pedestrian costing, biking uses bicycle costing, motorcycle uses motorcycle costing, and sedan starts with auto costing. Truck costing is a candidate when the confirmed truck class matches its access and dimensional assumptions. Motorcycle costing is marked beta. All mappings require local validation. [Routing profiles](https://valhalla.github.io/valhalla/api/route/api-reference/)

Valhalla documents vehicle height, width, length, weight, and truck access restrictions. These do not establish ground-clearance support. Vehicle height concerns overhead obstacles; the owner's low/high ground-clearance distinction concerns the space below a vehicle. Validate road data and any additional engine support before promising clearance-aware routes. A high-clearance pickup must not automatically receive heavy-truck assumptions. Public-commute costing is outside Wayday scope.

Valhalla's own optimized-route endpoint does not replace Wayday's scheduling rules. OR-Tools handles branch alternatives, priorities, and timing constraints using the profile-specific matrix supplied by Valhalla. [Time windows](https://developers.google.com/optimization/routing/vrptw)

Use Valhalla's public demo only for modest, deliberate evaluation under its fair-use policy. Published client use calls for operator notification and an identifying client header. It is not a guaranteed deployment backend. [Demo server guidance](https://valhalla.github.io/valhalla/start/introduction/)

No traffic feed is selected. OSM road data does not provide live Manila traffic. OR-Tools is a local algorithm library and needs no AI API key or credits.

### Future cloud: Supabase

Supabase Cloud is allowed as a free-tier candidate under the updated cost policy. The current Free plan lists a 500 MB database, 1 GB file storage, 5 GB egress, two active projects, and pausing after one week of inactivity. Recheck these before adoption. A regional catalog can exceed that database allowance; measure it first. [Pricing](https://supabase.com/pricing)

Supabase supports [PostGIS](https://supabase.com/docs/guides/database/extensions/postgis), but hosting PostgreSQL there does not host the Python service or Valhalla graph. Those need a separate deployment decision. Self-hosting the entire Supabase suite adds services and maintenance; local PostgreSQL is the simpler initial choice.

## Cost policy and replacement paths

- Target zero spending. Free tiers and trials are acceptable; prefer ongoing free capability for the baseline.
- Record quota, expiry, billing prerequisites, behavior at exhaustion, and fallback when adding a service. Do not activate billing or purchase resources under a documentation task.
- An expiring trial must have an exit path. Its presence must not become a promise of permanent availability.
- Local software still uses existing hardware, storage, electricity, and network access. There is no dedicated server or guaranteed uptime.
- Make map/routing endpoints configurable. Keep provider payloads behind adapters and use ordinary PostgreSQL access to limit cloud coupling.
- On exhaustion or outage, preserve local state, expose unavailability, and use saved results with timestamps. Do not silently switch to a billed endpoint.

## Platform and distribution costs

Android APK distribution can avoid an app-store publishing account. iOS compilation needs macOS and Xcode access. Free Apple personal-device testing requires periodic reprovisioning; normal App Store distribution needs program membership. No hardware or publishing purchase is assumed. [Flutter iOS guide](https://docs.flutter.dev/deployment/ios), [Apple account limits](https://developer.apple.com/help/account/basics/about-your-developer-account)

## Version policy

The mobile project now commits its application lockfile. Backend versions remain unselected until that project is authorized. Verify runtime behavior and native license terms at the selected versions before release. Revisit recommendations when hardware measurements, regional coverage, or team experience justify a change.
