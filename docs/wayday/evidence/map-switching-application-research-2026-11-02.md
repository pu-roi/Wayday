# How other applications switch maps and reuse destinations

Research date: 2026-11-02 (Asia/Manila). Requested after the owner rejected a disabled OpenStreetMap choice for an already planned trip. This is research, not authorization to replace search, redesign screens, export restricted content or deploy another build.

## Findings

Applications do keep an ordered coordinate model independent of their map renderer. The owner's proposed storage/rendering design is established practice. Three separate capabilities must be distinguished: changing the background map; rerouting through another engine; and continuing embedded live navigation/GPS/voice. Evidence for the first does not establish the other two or the right to reuse every provider's coordinates.

The previous explanation was too narrow if read as saying that independently selecting every destination again is the only possible remedy. Places UI Kit offers a distinct documented route to non-Google map display, including migration from existing Place IDs. That deserves qualification before requiring a manual confirmation flow. It is not a blanket permission to reuse standard Places SDK responses or send UI Kit outputs to arbitrary external routing services.

## Applications and developer implementations

### TREK: the closest open-source trip-planner example

Primary sources inspected through GitHub on the research date:

- [Map settings](https://github.com/liketrek/TREK/wiki/Map-Settings) and [map features](https://github.com/liketrek/TREK/wiki/Map-Features).
- [MapViewAuto.tsx](https://github.com/liketrek/TREK/blob/main/client/src/components/Map/MapViewAuto.tsx): reads the selected renderer, passes the same map properties to Leaflet or a lazily loaded MapLibre/Mapbox implementation, and falls back to Leaflet for initialization/chunk/WebGL/token failures. This is renderer availability recovery, not demonstrated Google navigation outage recovery.
- [mapViewContract.ts](https://github.com/liketrek/TREK/blob/main/client/src/components/Map/mapViewContract.ts): shared place, route and ordered waypoint contracts independent of the map SDK.
- [Places.entity.ts](https://github.com/liketrek/TREK/blob/main/server/src/db/entities/Places.entity.ts): database latitude/longitude fields alongside optional Google/OSM identifiers and source metadata.
- [MapViewGL.tsx](https://github.com/liketrek/TREK/blob/main/client/src/components/Map/MapViewGL.tsx): creates map points from stored longitude/latitude and reconciles markers from that common model.
- [RouteCalculator.ts](https://github.com/liketrek/TREK/blob/main/client/src/components/Map/RouteCalculator.ts): converts ordered points into routing inputs, with separate OSRM/Valhalla selection and request accounting.

This is almost exactly the coordinate/renderer separation the owner described. The [developer's search documentation](https://github.com/liketrek/TREK/wiki/Places-and-Search) describes its own index/OpenStreetMap and optional Google search; [NOTICE.md](https://github.com/liketrek/TREK/blob/main/NOTICE.md) subjects Google content to Google's terms. The inspected files demonstrate technical coexistence, not a special Google contract or proof that every Google-derived field is licensed for every renderer/router. Its planner routing and external navigation handoff also do not establish an embedded Google-to-alternative turn-by-turn switch identical to Wayday's requirement. Do not copy its AGPL implementation into Wayday as an incidental fix.

### RouteYou: map layer is separate from routing

[Developer help on map layers](https://help.routeyou.com/en/topic/view/302/map-layers) explicitly separates cartographic layers from routing and lists Google/OSM alternatives. [Current map-layer help](https://support.routeyou.com/hc/en-us/articles/14352942626844-Map-layers-and-map-details) describes changing the displayed layer while viewing a map.

The relevant design is to keep the route/waypoints separate from the background layer. Public documentation does not expose the entire implementation, destination-data contracts or a guarantee that Google-powered routing is replaced when the background changes. Do not present layer switching alone as independent navigation failover.

### Traccar: the same GPS coordinates on multiple basemaps

[Official map-layer documentation](https://www.traccar.org/map-layers/) supports multiple basemaps. In the [developer's MapRoutePath.js](https://github.com/traccar/traccar-web/blob/master/src/map/MapRoutePath.js), tracked positions become a GeoJSON line using each position's longitude/latitude. [useMapStyles.js](https://github.com/traccar/traccar-web/blob/master/src/map/core/useMapStyles.js) configures basemaps separately.

This demonstrates the same point-overlay separation, using tracking data rather than proving portability of Google Places results. It is a GPS tracking application, not evidence of an equivalent errand-guidance engine. Some published tile configurations need their own service/contract review; they are not recommendations to copy unreviewed Google tile URLs.

### Ubilabs: Google place content displayed on Mapbox through UI Kit

The developer's [UI Kit article and demo description](https://ubilabs.com/en/insights/google-maps-places-ui-kit), published August 29, 2025, describes rendering Google Place Details over a Mapbox map with customizable UI Kit components. The same article describes passing a Place ID from search to the UI Kit component. This is a concrete example of obtaining permitted frontend content through a different Google product instead of treating a standard Places API response as unrestricted data. It demonstrates map/display integration, not a verified Geoapify navigation export. Its historical pricing claims are not used as current cost evidence.

## Official Google evidence relevant to a less disruptive repair

1. [Getting started with Places UI Kit](https://developers.google.com/maps/architecture/places-ui-kit-getting-started) explicitly supports a map chosen by the developer. It identifies search/details components and JavaScript/Android/iOS support.
2. [Adopt Places UI Kit for existing Places API users](https://developers.google.com/maps/documentation/javascript/adopt-places-ui-kit) shows migrating an existing Place ID into a rendered details component. Its programmatic data section allows Place ID, location and viewport from Search/Details; Basic Autocomplete returns only Place ID. This is a JavaScript guide and is not proof of identical Android callbacks.
3. Android has [Advanced Place Details](https://developers.google.com/maps/documentation/places/android-sdk/advanced-place-details-ui-kit) and [Basic Autocomplete](https://developers.google.com/maps/documentation/places/android-sdk/basic-place-autocomplete-ui-kit) components. Wayday's current native UI Kit bridge already handles a place-loaded event and location separately from its standard recommendation SDK bridge. Actual native component/version/callback behavior must be tested before relying on a migration path.
4. [Service-specific terms](https://cloud.google.com/maps-platform/terms/maps-service-terms), sections 14 and 15, distinguish standard Places content from UI Kit. Section 15 permits non-Google maps and temporary coordinate caching, while retaining attribution and third-party export/content restrictions. [Android policies](https://developers.google.com/maps/documentation/places/android-sdk/policies) also illustrate UI Kit attribution on a non-Google map.

Inference for Wayday: resolving the already accepted Place ID through an actually rendered, attributed UI Kit component could preserve branch identity for a non-Google display without another business-name search or user repinning. It must fetch content through the appropriate product and preserve its source; changing the provider string on an existing SDK coordinate lease does not accomplish that. UI Kit resolution remains Google-dependent at preparation time. The materials checked do not conclusively qualify sending those coordinates to Geoapify for calculated navigation. That use needs an explicit applicable documented permission or written provider clarification before a live integration; do not turn display permission into an unsupported navigation claim.

## Developer discussions reviewed

- [Reddit: how Beli combines place data and maps](https://www.reddit.com/r/webdev/comments/1pfqpvs/how_is_beli_doing_this_without_violating_any_map/). Participants speculate about open data, commercial datasets, custom agreements and noncompliance. None is an authenticated account of Beli's implementation or licensing. Do not label Beli noncompliant or claim its architecture is established from that discussion.
- [Stack Overflow: Google Places on Mapbox](https://stackoverflow.com/questions/23086409/google-places-on-mapbox-map). The 2014 answer reflects the older standard-API restriction. It predates UI Kit, so it is historical context rather than a complete answer for 2026. Current first-party terms/docs control the assessment.
- [DEV Community: MapLibre versus Google Maps, by Capawesome](https://dev.to/capawesome/maplibre-vs-google-maps-which-map-sdk-to-use-plc). The plugin developer demonstrates selecting a style URL/OpenFreeMap independently of the renderer. It supports the distinction between map drawing and data services; it does not grant Google Places portability or demonstrate Wayday's full live-navigation switch. Its Capacitor implementation is not Flutter code to drop into this app.

Community threads supplied leads and examples; provider rights are assessed using current official documentation, and technical implementations using their developers' source/docs. A visible feature in another app is not evidence of that app's private commercial terms.

## Recommendation for Wayday

Retain the owner's coordinate-based trip model: task/stop identity, order, latitude/longitude and source/permission metadata separate from renderer and navigation driver. Use the existing trip-local provider selector and current GPS/progress ownership; a provider switch must not recreate errands, change their order, merge shared tasks or silently substitute another branch. The existing driver separation already supports much of this.

Investigate the same-Place-ID UI Kit route first for existing Google-only accepted trips, because it may avoid the rejected repinning experience for map display. Qualification must establish the Android coordinate callback, correct visible component/attribution, caching/expiry, cost, failure behavior and explicit third-party routing permission. Do not enable Geoapify export merely because markers work. Any required visible component must be reviewed against the owner's no-unapproved-UI-change constraint.

For reliable seamless navigation across Google and Geoapify, independently sourced navigation coordinates that both services permit are the clearest architectural option. Acquire and validate them before they are needed for an outage, retain their identity/source separately, and request each engine's own road route. If independent matching cannot establish the exact intended branch, require explicit recovery rather than silent proximity/name substitution. Broader recommendation-source changes remain outside the currently authorized implementation.

No downloaded dataset, new service/account, paid request, application-code change, APK update, Cloud deployment or personal-data operation was performed for this research. No architecture/provider decision is silently accepted by this document.
