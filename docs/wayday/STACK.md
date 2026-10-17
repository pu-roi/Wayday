# Technology stack and dependency inventory

Initial research snapshot: 2026-10-15. The Android UI shell was authorized on 2026-10-16; its installed toolchain and direct dependencies are recorded below. Backend, mapping, routing, and database recommendations remain for later implementation. No external account or paid service has been provisioned.

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

## Current UI shell versions

- Flutter 3.47.7 stable, Dart 3.13.5, Riverpod 3.4.3, GoRouter 18.1.0, and flutter_lints 6.0.0. See `apps/mobile/pubspec.lock` for exact resolved dependencies.
- Android project generated by this Flutter SDK: compile/target API 36, Android Gradle Plugin 9.1.0, Gradle 9.3.1, and NDK 28.2.13676358. Java source/target compatibility is 17; the local build runs on Microsoft OpenJDK 21.0.12.1.
- SDKs, package caches, Gradle caches, Android tooling, and the local JDK are under ignored `.tools/`. They are local development dependencies, not files to commit or services to deploy. No global PATH modification is required.
- Figtree is sourced from [Google Fonts](https://github.com/google/fonts/tree/main/ofl/figtree) under SIL OFL 1.1. Its license ships beside the font. This is not a completed license audit of a release binary.

## Data and service boundaries

### Maps: MapLibre and OpenFreeMap

MapLibre draws the map; it does not supply places, travel estimates, or an optimizer. OpenFreeMap supplies a free public vector basemap without account registration or API keys. Its public service has no SLA.

OpenFreeMap permits offline area downloads with limits of 3,000 tiles or 50 MB per download, at most four parallel requests, and an identifying User-Agent. Adopt the conservative default of stopping at either limit. Do not split a larger download into smaller jobs to evade the policy. Verify the latest terms before implementation. Keep required OpenStreetMap/OpenMapTiles attribution visible. [Provider policy and terms](https://openfreemap.org/)

MapLibre's iOS offline cache can be evicted under storage pressure; check completeness before relying on it. [Offline region documentation](https://github.com/maplibre/flutter-maplibre-gl/blob/main/website/docs/advanced/offline-regions.md)

The standard OSM tile server prohibits offline prefetching. Do not use it for Wayday offline packs. [OSM tile policy](https://operations.osmfoundation.org/policies/tiles/)

### Places: regional OpenStreetMap data

Import a regional OSM extract into the local PostGIS catalog. Preserve source identifiers, data dates, and opening-hours text. Add manual pins and clearly sourced corrections. Wet markets and small businesses may have incomplete coverage; assess the pilot area rather than assume a commercial places API's completeness.

OSM data uses ODbL; retain attribution and review derived-database redistribution obligations. Application code has a separate license. [OSM copyright and licensing](https://www.openstreetmap.org/copyright), [Geofabrik extracts](https://download.geofabrik.de/asia/philippines.html)

Public Overpass is useful for bounded exploration, but its operator discourages using public instances as the backend for general consumer apps. Use extracts for the application catalog. [Overpass guidance](https://dev.overpass-api.de/overpass-doc/en/preface/commons.html)

Public Nominatim is not the default address or business search service. It disallows autocomplete and systematic POI enumeration, caps aggregate application traffic at one request per second, and requires identification, attribution, and switchability. Use the local catalog and manual pins initially. [Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/)

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

The mobile project now commits its application lockfile. The backend commits pinned direct dependencies and its resolved lockfile as described below. Verify runtime behavior and native license terms at the selected versions before release. Revisit recommendations when hardware measurements, regional coverage, or team experience justify a change.

## M1 local persistence versions and limits

The first functional batch adds Drift 2.35.2, drift_flutter 0.3.1, UUID 4.6.0 and the resolved SQLite native runtime (see pubspec.lock). Drift development generation uses drift_dev 2.35.1 and build_runner 2.16.2. No server or account is needed. Drift/SQLite/UUID package licenses remain upstream; downloaded runtime assets are not committed. The web preparation script pins compatible official Drift release assets with SHA-256 verification; rerun it after dependency updates and review checksums/version compatibility. Storage is private app data on Android with automatic backup disabled; browser data is origin-scoped and independently clearable. No encryption or cross-device backup capability is claimed. [Drift platforms](https://drift.simonbinder.eu/platforms/)

Sharing later uses FCM for follower events, with Supabase Auth/PostgreSQL as a hosting candidate, not an adopted service. A TypeScript/MapLibre GL JS viewer and native Android App Links are planned. No external account, billing or public service was created. See [the approved plan](IMPLEMENTATION_PLAN.md) and [measured feasibility prerequisites](FEASIBILITY.md).

## M2 manual map additions

Pinned `maplibre_gl` 0.27.1 (BSD-3-Clause) and `geolocator` 14.1.1 (MIT), with transitive versions in the mobile lockfile. MapLibre uses its Android OpenGL SDK. OpenFreeMap Liberty is the configurable public basemap; attribution remains visible. No account or billing is provisioned. The public service has no availability guarantee. Location is an explicit one-time foreground request with manual fallback. See [integration limits](MAP_REVIEW_HANDOFF.md). No search, road routing or AI service was added.


## M2 pilot search runtime

The local FastAPI module and source-backed catalog importer are implemented at [services/api](../../services/api/README.md). Direct dependencies are pinned in its pyproject and all resolved import/test/runtime dependencies in `requirements.lock`. FastAPI 0.143.3, Uvicorn 0.54.0, SQLAlchemy 2.1.5, Psycopg 3.3.6, PyOsmium 4.3.1 and Shapely 2.2.0 are local dependencies with upstream licenses. No account, billing or public deployment is used. Flutter adds HTTP 1.6.0, pinned through the application lockfile.

PostgreSQL/PostGIS is now the verified default regional catalog store. The local Docker runtime passed M2-03 with PostgreSQL 17.5, PostGIS 3.5.2 and pg_trgm 1.6. The container is capped at 512 MiB; an observed sample used approximately 126 MiB, not a capacity guarantee. File snapshot mode remains an explicitly selected bounded development read model, never automatic failover. Local database credentials use Windows-user DPAPI in ignored configuration; no credential is shipped in Flutter. See [the database handoff](M2_DATABASE_HANDOFF.md). A Metro Manila OSM France extract is clipped during import to the fixed pilot rectangle; downloaded and generated data remain ignored. File mode is limited to 20,000 records and requires a restart after refresh. The API listener is loopback-only; Android debug permits local HTTP, while release configuration requires an HTTPS endpoint. Search has no request-time dependency on public Nominatim or Overpass.

Android map composition uses MapLibre's TextureView option to support Flutter overlays and reduce the default Virtual Display's input/z-order limitations. This is separate from Flutter's renderer and needs native testing. No production Impeller opt-out is committed; emulator GPU recovery is a local testing concern, not a claim of physical-device performance.


## Mapped-area refinement, 2026-10-18

Shapely 2.2.0 was already pinned for importing; it is now a direct API dependency as file mode also evaluates imported footprints. No new package download or public geocoder was introduced. Optional PostGIS MultiPolygon geometry uses SRID 4326 and a GiST index through additive migration 002. Source geometry stays server-side; nearby responses carry only match classification and the existing bounded place metadata. Named residential/place records remain inside the existing pilot bounds. See [contributor run modes](RUNNING_WAYDAY.md).
