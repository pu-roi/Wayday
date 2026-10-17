# Search and map place chooser

Mode: Operate. Android phone first, locked to upright portrait. This is a precisely specified extension of Wayday's Canvas/Cornflower/Figtree world, guided by the owner's Move It search-list and large-map screenshots. The reference supplies interaction structure, not a replacement brand or pixel reproduction.

## Direction contract

THESIS: Choose a recognizable real place, then confirm its location with minimal effort.

OWN-WORLD: Existing Material app bars, filled search field, compact result rows, readable blue actions and one light Cornflower theme. Real OpenFreeMap geography is the map material. Do not add invented results, travel estimates or decorative cards.

STORY: From, To and errand places open search with business/landmark suggestions and saved places. Choose on map is always available. A selected result supplies its name and coordinates. A full-screen map uses a fixed center pin and a compact confirmation area. Moving away resolves the mapped place name from a unique containing boundary or otherwise a unique point within 10 metres. Ambiguous/nearby places require explicit choice; unmatched selections remain Dropped pin. Names do not prove entrances. No custom-name or coordinate input is required.

FIRST VIEWPORT: A normal Back/header, one clearly labeled search field, then readable place names and address detail. Map and location controls stay accessible below the result area. The map screen gives most of its space to geography, with a fixed pin, a location control, visible attribution and a safe-area confirmation button. Loading, empty search, unavailable catalog, permission denial and cancellation have useful recovery paths. Larger text remains scrollable in portrait. Landscape is outside the product scope; rotating the Android phone must retain portrait.

FORM: User-pinned search-list and full-map sequence inside the established Android system, code-led; seed: none (precisely specified extension; no concept roll).

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.

## Data and scope

The bounded local place API searches imported OSM names, addresses and aliases; it does not interpret errand text or recommend branches for a schedule. The current imported catalog contains 13,033 source-backed records. File snapshot mode is an explicitly selected local-development read model, not automatic fallback from a failed database. PostGIS is now the verified default catalog store; M2-03 database runtime checks are complete, while physical-location and pilot coverage gates remain open. M2 overall remains incomplete. No accounts, paid APIs, public geocoder autocomplete or deployment are introduced. Source-date metadata is retained; the chooser explicitly states incomplete coverage and unverified hours and entrances. Manual pin selection remains available without the catalog; uncached basemap availability still requires connectivity.

Location uses an explicit one-time foreground request. The whole UI wait is bounded to 12 seconds, Cancel location abandons its result, and manual map touches invalidate pending fixes. Accuracy and failure messages keep the pin review explicit. This is not live tracking. Android map composition uses TextureView to support Flutter overlays; camera refocusing is limited to explicit focus changes. Startup requests portraitUp and the activity manifest declares portrait for the whole Android app.

## Implemented interaction record — 2026-10-17

The search screen centers a column capped at 560 logical units with 20-unit side insets, a shared filled search field and scrollable saved-place/result rows. Search begins at two characters after a 350 ms debounce; the API wait is bounded to five seconds and stale responses are ignored. Loading, empty pilot results and unavailable search have explicit copy and retry/manual alternatives. Choose on map and Use my location remain below the list. Saved places with coordinates may return directly; unresolved saved labels open the map.

The pin screen gives remaining space to the real basemap and fixed center pin. Its compact details scroll within a 26%-of-screen-height cap above a safe-area Confirm location action and separate optional Save to my places icon. Mapped names retain their coordinates until the map moves away; manual movement resolves mapped place identity where supported, retaining Dropped pin when unknown. Coordinates are read-only supporting text. No name or coordinate input form is exposed. Ambiguous or merely nearby places appear as explicit choice buttons, not automatic business-entrance corrections.

Native emulator evidence is `.impeccable/review/native-m2-search-phone.png`, `native-m2-pin-phone.png`, `native-m2-pin-large-text.png`, and `native-m2-portrait-lock.png` in that directory. PLP search, loaded tiles, manual map selection, simulated GPS/cancellation and retained portrait under rotation were exercised; large-text confirmation was captured at 1.3 scale. These are not physical GPS, TalkBack or performance verification. The current verification run passed Flutter analysis, 64 Flutter tests, 10 local API tests and Android APK build. That UI run did not close the runtime or coverage gates; the later M2-03 backend batch separately verified the PostGIS runtime without changing the UI. Coverage remains open.
