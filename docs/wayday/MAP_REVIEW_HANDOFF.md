# M2 map and manual review integration

Owner-confirmed scope, 2026-10-17: real maps and editable review first, followed by a search-first place chooser and full-screen map. The Android phone app is portrait-only. Interpretation stays independently owned and unchanged. Local catalog search is now implemented; M2-03 PostGIS runtime is verified; physical-location and coverage gates remain open. Branch recommendations, road routing and trip execution are not operational.

## Current flow

Today → Plan my day → Review your day → choose places, reorder errands and change priority → Find your way (placeholder). Back discards the review. Confirmation saves the active day locally, without starting a trip or publishing information. The action currently saves a draft when places lack coordinates. Its new label is a placeholder; active trip execution remains M4. Required and optional errands remain in the list; neither is automatically removed.

The review uses V2's vertical visit sequence and focused place changes. Its map shows pins only; there are no fabricated route lines, arrival estimates, best-fit badges or feasibility results. Leave/Home by are user constraints, not predictions. Timing rules retain their arrival-versus-completion meaning. Visit durations remain visibly assumed until confirmed.

MapLibre GL renders the OpenFreeMap Liberty basemap. Search real imported names, addresses and landmark aliases, select a result and confirm it on the full-screen center-pin map, reuse a saved place, or explicitly request a one-time foreground location fix. There is no custom-name or coordinate-entry form. A moved pin resolves its name against mapped boundaries; a unique containing place takes precedence over nearby points. A unique mapped point within 10 metres may also match. Ambiguous/nearby candidates require explicit choice; an unknown pin remains Dropped pin. Broad city/neighbourhood boundaries do not assign a business identity. Coordinates are read-only and no match verifies an entrance. Legacy labels without coordinates remain unresolved until selected on the map. Map credits remain visible; the native attribution control links to provider/source attribution. Device location is not published, streamed or stored as history. Errand places persist when chosen. From and To are session-only and clear on cold launch/hot restart; saved places remain independently reusable.

## Contributor boundaries

- `features/errands/domain/errand_interpreter.dart` and its existing reviewed suggestions are untouched by this slice. Another contributor can develop interpretation separately.
- `Errand` preserves `inputText`, confirmed fields, timing, duration, priority and dependency IDs. Review consumes those explicit fields; it never interprets “bili gamot” into a pharmacy or an appointment.
- `PlaceIntent` distinguishes unresolved, specific, saved and flexible search intent. Manual pin selection produces a specific place with valid latitude/longitude and `user_pin` provenance. The existing JSON workspace can store these coordinates without a database schema change.
- `DayReview` holds an independent draft and the source revision. `TodayController.applyReview` rejects stale commits. Reordering respects prerequisite IDs; the draft reports missing or contradictory prerequisites instead of dropping stops.
- `placeMapBuilderProvider` isolates native map rendering from widget tests. Its test double exists only in test fixtures; production never substitutes an illustration for failed map data.
- `locationReaderProvider` owns the one-time permission/fix adapter. A late fix cannot replace a pin the user chose while waiting.

The local catalog supplies source-keyed places with coordinates, nullable addresses, source dates, coordinate kinds and explicit hours status through the search repository. Results are actual alternatives in the chooser. Metadata persists as optional backward-compatible fields in the existing day JSON aggregate. Distinct branches sharing a name retain separate saved-place identities. A recommendation needs a separate planning result, source revision and explanation; do not label saved places or the first returned branch as recommended. Preserve a user override until they explicitly release it. The `/v1` planning interfaces in the approved architecture remain proposals, not operational endpoints.

## Services, cost and fallback

Pinned additions: `maplibre_gl` 0.27.1 (BSD-3-Clause) and `geolocator` 14.1.1 (MIT), with transitive versions in the lockfile. Flutter's licenses registry carries package notices; the underlying map SDK/data have their own notices and attribution requirements.

The public style is `https://tiles.openfreemap.org/styles/liberty`. No account, API key or billing is used. OpenFreeMap currently advertises no request quota; it has no availability guarantee. Do not infer an offline map download entitlement or routing/search service from map display. Tile/font/sprite requests go to the map provider and may disclose the viewed area. No personal task text or notes are submitted for place search or planning in this slice.

If the map takes too long to initialize, show an explicit retry state while retaining the search route and saved pins. Cached map availability is not guaranteed offline coverage. The local FastAPI search service supports an explicitly selected bounded file read model; PostGIS is now the default and its M2-03 runtime checks passed; Valhalla, the solver and field coverage remain separate gates. See [the database handoff](M2_DATABASE_HANDOFF.md). See [the service setup and API contract](../../services/api/README.md). No public community geocoder or demo routing endpoint is used as an application backend.

References: [MapLibre Flutter](https://pub.dev/packages/maplibre_gl), [OpenFreeMap](https://openfreemap.org/), [Geolocator](https://pub.dev/packages/geolocator), [approved plan](IMPLEMENTATION_PLAN.md), [live task board](../../PLANNING.md).
