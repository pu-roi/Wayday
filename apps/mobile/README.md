# Wayday mobile

Android-first Flutter app with Today and Recurring. It uses one light Cornflower theme, compact errand lists, focused editing, and Riverpod controllers. Android stores personal data in a local Drift/SQLite database. Earlier Today and Recurring persistence was verified across force-stop and relaunch on the API 37 x86_64 emulator on 2026-10-27. Isolated emulator checks during reconciliation exercised app startup, adding an errand, the regional renderer and online map pin selection. Physical-device coverage and an Android upgrade from Rudy's database remain unverified. The browser preview remains in memory.

## Run

Use Flutter 3.47.8 stable (Dart 3.13.7). Install Android prerequisites for your machine and connect a device with USB debugging, or start an Android emulator. From this folder:

```powershell
./tool/flutter.ps1 pub get
./tool/flutter.ps1 devices
./tool/flutter.ps1 run -d <android-device-id>
```

The PowerShell wrapper uses the ignored repository-local `.tools/` SDK when present; otherwise it uses Flutter from PATH. It does not download or install tooling. Standard `flutter` commands work with a separately configured toolchain. Online search and online map pins need internet. The direct-client search pilot combines Geoapify, LocationIQ, and Photon; the first two use the owner’s free API keys and Photon is key-free. No local server is required. The optional Use my location button requests foreground location permission; manual pin selection works without it. The separate offline Pasig/Ortigas map preview is under Settings. The Photon adapter uses the public demo for limited testing and can be configured with `--dart-define=WAYDAY_PLACE_SEARCH_URL=https://your-photon-host/api/`. The demo may throttle requests or become unavailable without notice; it is not a production availability guarantee. See [Photon's demo terms](https://github.com/komoot/photon#demo-server). The online map uses the configurable `WAYDAY_MAP_STYLE` and defaults to OpenFreeMap, which is provided without an availability guarantee; see [its terms](https://openfreemap.org/tos/).

To include the offline Pasig/Ortigas map, prepare the regional package from the repository root before building:

```powershell
py tools/maps/build_package.py --pmtiles .tools/pmtiles/pmtiles.exe --copy-to-app
```

The [regional-data guide](../../docs/wayday/CONTRIBUTING.md#regional-maps-and-data) describes the pinned local tool and source/cache requirements. Generated tiles, glyphs and sprites remain ignored; a fresh source checkout without preparation builds a readable Map unavailable state and keeps manual label editing usable. The Android build uses a [project-local patch](third_party/maplibre_gl/WAYDAY.md) of `maplibre_gl` 0.27.1 and pins native OpenGL 13.7.1 for bundled PMTiles range reads. Its plugin requires JDK 21 or newer; the current machine uses Android Studio JBR 25. The space-free `NotoSansRegular` asset alias preserves the original licensed glyph bytes.

For a local browser preview of the same widgets:

```powershell
./tool/flutter.ps1 run -d chrome
```

The web target is a design-review convenience that starts empty and keeps session data in memory. Browser behavior does not verify Android system insets, Back gestures, keyboard behavior, or physical-device performance. iOS is deferred.

### Location and search relevance

Opening the app does not request location. In place search, Use my location explains the benefit and requests foreground permission only after a tap. Once Android grants access, each opening of search obtains a fresh location automatically; keyboard focus changes do not repeat it. One application-scoped controller shares acquisition and fixes across From, To, errands, and saved-place editing. A fix up to five minutes old can support initial results while a new fix is acquired, with a fifteen-second timeout. Approximate access works without a forced precision upgrade. Denial, disabled services and timeout retain ordinary search/manual selection; Open settings is an explicit action. Temporary permission and revocation are checked quietly. Device fixes are retained only in app memory and are sent to enabled search providers as relevance hints. No location history or background tracking is added.

The origin label shows Near me, Near your approximate location, This map area, or Philippines. Search this area explicitly uses the local map center for named and category searches; category requests retain the five-kilometer radius and zoom-10 requirement. Panning alone does not alter the origin, query or provider activity. Near me restores device relevance. Search-location updates preserve the draft and map position; the map's separate location control retains its smooth zoom-18 flight. A new fix replaces pending work; after dispatch, at most one replacement wave per query is allowed when the initial device origin was absent or moved at least 250 meters. All existing debounce, quota, cache and failure controls still apply.

Matching prioritizes exact/canonical names, qualified brands, complete name/address word matches, then partial matches. Comparable branches are ordered by distance. Registered aliases cover Megamall/SM Megamall, McDonald's punctuation/spelling variants, and Jollibee/Jolibee. Recognized brand branches remain comparable without optional provider brand metadata. Brand aliases use one canonical provider query/cache entry while preserving the displayed text and explicit branch qualifiers; they do not add requests for each spelling. LocationIQ uses distance sorting for registered brand-only searches. These aliases cannot supply a place missing from provider responses. Saved places remain separate. Incoming batches may improve ranking until pointer, scroll or accessibility interaction freezes visible rows and records; Updated results applies staged changes locally without new requests. Selection still requires Confirm location. Distances are straight-line estimates among returned candidates, with coarse uncertainty buckets for approximate access, not walking/driving routes or a guarantee of the nearest business nationwide.

Keep the existing API-36 Android target for this change. The session-based location-button integration must be reviewed before API 37 adoption; see the [Android/Play policy preview](https://support.google.com/googleplay/android-developer/answer/16909972).

The native location/keyboard harness uses real Android permission and IME surfaces but fixture search responses and public fixture coordinates, never device coordinates. Reset only the isolated `dev.wayday.wayday.maptest` app's location permissions before a deliberate run. Use `./tool/test-map.ps1 -DeviceId <device-id> -Target integration_test/location_search_test.dart`. At `WAYDAY_LOCATION_DENY_READY`, deny the system prompt; at `WAYDAY_LOCATION_ALLOW_READY`, allow while using. At `WAYDAY_LOCATION_BACK_READY`, press system Back; at `WAYDAY_LOCATION_IME_CLOSE_READY`, tap the keyboard hide control. It checks query/draft preservation, ranking, and a new acquisition on reopening without another prompt. No provider quota is consumed. This does not measure real GPS quality or business coverage.

### Keyboard and Back in location search

Dismissing the keyboard keeps the search interface, typed query, available results, pending search, and map draft intact. Android system Back hides the keyboard first; further system Back events while searching keep the session open. Use the app bar's Close search button or Back to map to close search explicitly. These actions retain the field text for reopening; choosing a result keeps the existing transition to map confirmation. The field's Clear search action clears text without closing search. Once search is closed, Back cancels the picker normally.

The isolated native keyboard check uses fixture results and a map double, so it makes no provider calls. Run `./tool/test-map.ps1 -DeviceId <device-id> -Target integration_test/keyboard_navigation_test.dart` and send one physical/system Back event when `WAYDAY_KEYBOARD_HARDWARE_BACK_READY` appears in the test output, then tap the keyboard’s own hide/close button when `WAYDAY_KEYBOARD_NATIVE_DISMISS_READY` appears. The harness uses the separate map-test application ID and disables automatic uninstall. It verifies actual IME insets, native Back, the installed keyboard’s close control, preserved query/results, and explicit search/picker closing. The Samsung SM A546E check passed on 2026-10-28; it does not validate other keyboard applications or the native map renderer.

## Search pilot configuration

Keep `GEOAPIFY_API_KEY` and `LOCATIONIQ_API_KEY` in the ignored repository-root `.env.local`, using `.env.example` as the template. The wrapper automatically generates ignored `.tools/search-defines.json` and supplies it for `run`, `build`, and `drive`. Keys are never printed by the configuration script. Missing keys disable their providers without blocking startup. An environment file protects the checkout; credentials compiled into a direct-client APK are extractable. This is a presentation pilot, not a public download configuration. Public APK distribution requires a shared search gateway with centrally enforced quotas and credentials removed from the binary.

For Android Studio, first run this from `apps/mobile/`:

```powershell
./tool/configure-search.ps1
```

In Run > Edit Configurations > Flutter, add `--dart-define-from-file=../../.tools/search-defines.json` under Additional run args. Use the same project-local Flutter SDK as the wrapper. Regenerate the file after changing keys. Never paste keys into a tracked run configuration, source file, log, or screenshot.

### Google credential configuration and Routes qualification

On 2026-10-29 the owner selected Places UI Kit for Google place search, Routes API for traffic-aware planning inputs, and Navigation SDK for embedded Google navigation. The credential slice added local configuration and a bounded Routes tool. D43 now implements standard Google UI Kit search through Places SDK 6.0.2; the bounded isolated native sample now passes after test identity authorization. Planning, Google route rendering and navigation remain unconnected. No background tracking, SQL migration or deployment is included.

Keep two additional values in the same ignored `.env.local`:

```dotenv
GOOGLE_MAPS_ANDROID_API_KEY=<restricted Android SDK key>
GOOGLE_ROUTES_API_KEY=<separate restricted Routes REST key>
```

The SDK key allows Places UI Kit and Navigation SDK, with Android package/signing-certificate restrictions. The separate Routes key allows only Routes API and has the corresponding Android restrictions for the private direct-client qualification. Application identifiers are headers, not proof against a determined client impersonating an APK. Public distribution still requires appropriate shared controls; never remove restrictions to work around a denied request.

Run `./tool/configure-search.ps1` again after updating local values. The existing CLI wrapper and Android Studio `--dart-define-from-file` argument now supply all four provider keys. Android's Gradle configuration decodes only `GOOGLE_MAPS_ANDROID_API_KEY` into the `com.google.android.geo.API_KEY` manifest entry; it does not copy the Routes key into that entry. Missing Google values produce an empty SDK value without preventing the existing app from building. The ignored file protects source control, not an installed APK: the Android SDK key is embedded in the manifest, and any future direct-client Routes credential will also be extractable.

The explicit qualification runner uses two named public Mandaluyong landmarks. It makes at most four starts: a traffic-aware driving route with the correct identity, two route attempts with separately incorrect package/certificate values, and a one-element matrix with the correct identity. It stops on the first unexpected result, times each request out after five seconds, and never retries. A generic access denial does not count as proof of Android identifier enforcement. Its sanitized report includes status, error enums, elapsed time and request counts, with no keys, response bodies, returned route data, private coordinates or full URLs.

To deliberately repeat this live check from `apps/mobile/` (consumes Google quota independently of phone accounting):

```powershell
$debugSha1 = '<SHA-1 fingerprint of the debug certificate authorized in Google Cloud>'
../../.tools/flutter/bin/dart.bat run tool/qualify_google_routes.dart --live "--sha1=$debugSha1"
```

The runner reads the Routes key directly from `.env.local`; never pass a key as a command-line argument. Running without `--live` and a fingerprint prints instructions without sending requests. The checked-in [qualification report](../../docs/wayday/evidence/google-routes-qualification-2026-10-29.json) records four attempts: correct route/matrix identities returned HTTP 200 and usable estimates; incorrect package and certificate each returned HTTP 403 `API_KEY_ANDROID_APP_BLOCKED`. This is endpoint/access qualification, not native SDK, actual traffic accuracy, planner, or vehicle-profile verification. Fake transports cover these cases in `test/google_routes_probe_test.dart` without network calls.

The owner's billing screenshot showed a paid account with remaining trial credit expiring December 16, 2026. Do not treat that as a zero-charge guarantee or create another account. Budget alerts do not stop Maps requests. Project quotas apply across keys; applicable monthly free allowances aggregate across projects linked to the billing account. The Console search screenshot showed 100 standard queries/day, 100 sessions/day and zero advanced queries/day. Suggested temporary Routes caps of 30 requests/day and 30 matrix elements/day, and Navigation caps of 15/day for each destination method, still need confirmation in their saved Console tables. A 30-element daily matrix cap supports only tiny tests: a 5-by-5 matrix uses 25 elements, while 6-by-6 needs 36. The final planner's request capacity is not established by these temporary caps.

Google Routes content must use a Google map when used with a map; the future route-review surface cannot put it on MapLibre. Places UI Kit has its own non-Google-map exception and must retain its supplied attribution/components. Saved Google content requires a retention review before integration: coordinate caching is limited to 30 consecutive days, while place IDs have a separate indefinite-storage exception. Existing saved non-Google places are unchanged. See [D42](../../docs/wayday/DECISIONS.md#d42--google-service-direction-local-credentials-and-bounded-qualification) and the [Google service inventory](../../docs/wayday/STACK.md#google-services--selected-direction-and-credential-qualification).

One application-scoped scheduler serves every picker. Geoapify and LocationIQ starts are at least 1.1 seconds apart, Photon starts are at least two seconds apart, and each provider has one in-flight call. LocationIQ is capped at 50 starts per rolling minute; Photon at 10. Conservative local rolling-24-hour budgets are 500 calls for each keyed provider and 100 for Photon. Calls and cooldowns are saved before dispatch to an application-support accounting file containing only provider identifiers, timestamps, and failure streaks. Corrupt/unwritable accounting pauses network search rather than resetting allowances. These controls cover one installation, not all users of a provider account; other devices, dashboard experiments, reinstalling the app, or editing its files can bypass that local accounting. The provider dashboard is the account-wide authority.

Each provider has a 100-entry memory LRU cache: 15 minutes for successful results, 60 seconds for empty results, and no cached failures. Saved places persist separately. Limits, Retry-After, temporary outages, daily exhaustion, and credential failures preserve partial results and manual selection. No automatic retry loop, balance polling, paid fallback, persistent query history, or location history is introduced. Full request URLs and keys are excluded from diagnostics. Web preview cannot persist quota accounting and fails closed for new network calls.

To deliberately repeat the small live qualification (this consumes real provider quota), run from `apps/mobile/`:

```powershell
../../.tools/flutter/bin/dart.bat run tool/qualify_search.dart
```

The runner reads `.env.local`, spaces requests, stops querying a provider after access/rate denial, and writes sanitized public-place candidates to `docs/wayday/evidence/search-qualification-2026-10-28.json`. This explicit tool is separate from phone accounting and automated tests. Check dashboard usage before and after running it. The recorded initial pass used 31 search calls plus one diagnostic call: both keyed providers worked; Photon returned access denied from the test host. Results are not independently surveyed business or entrance verification. See [search review](../../docs/wayday/evidence/search-qualification-2026-10-28.md).

## Build and verify

```powershell
./tool/flutter.ps1 analyze
./tool/flutter.ps1 test
./tool/flutter.ps1 build apk --debug --target-platform android-arm64
```

Stage 1 verification on 2026-10-27 passed the analyzer and all 48 tests. A combined ARM64/x86_64 debug APK was built using `./tool/flutter.ps1 -FlutterArguments @('build', 'apk', '--debug', '--target-platform', 'android-arm64,android-x64')`. API 37 x86_64 emulator checks covered an existing-database upgrade, fresh empty startup, editing, selection controls, notes, independent copies, Undo, and populated/empty force-stop/relaunch. The fresh secondary Android user initially showed a system-process not-responding dialog; it recovered after Wait. No app crash was observed during the subsequent walkthrough. This is functional emulator evidence, not physical-device, TalkBack, or performance verification. See [Progress](../../docs/wayday/PROGRESS.md) for the task evidence.

The debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. Its provisional application ID is `dev.wayday.wayday`. It is for local testing, not store submission. An ARM64 build requires an ARM64 Android device; omit the target-platform argument to build other supported architectures.

Run the test-only native map harness with `./tool/test-map.ps1 -DeviceId <android-device-id>`. Use this wrapper rather than a direct integration-test command: it supplies the separate `dev.wayday.wayday.maptest` application ID and disables Flutter's automatic uninstall, which can otherwise remove the normal personal-data app during cleanup. Its edits use memory repositories and it requires the prepared package. Disable Wi-Fi and mobile data before launch to verify an offline cold start; ADB remains available on the emulator. It checks real rendered roads/labels, pan/zoom, a temporary verification layer, credits, manual-label drafts and unavailable-package editing. It does not verify physical-device performance, real location, searchable places or route calculation. On a memory-constrained Windows host, `$env:GRADLE_OPTS = '-Dorg.gradle.jvmargs=-Xmx3g -Dorg.gradle.workers.max=2'` bounds build memory/workers without changing global Gradle settings. The wrapper restores its process-local Gradle property after the run; build the normal APK without that property for distribution.

The tests cover rapid consecutive quick add with preserved focus and Anytime defaults, save/cancel, multiline note copying and independence, interruptible list disclosure, reduced motion, feedback replacement and automatic dismissal, preservation of timing, numeric time validation and midnight, deadline order, manual map labels, all five travel choices, remove/clear/undo, recurring creation/editing/deletion, duplicate prevention, forced light appearance, unavailable planning, and larger text on a small phone. To write actual Flutter widget-renderer captures, set `$env:WAYDAY_CAPTURE = '1'` before running tests. Captures go to the ignored root `.impeccable/review/` folder. They are distinct from ADB `native-*.png` captures made on a connected phone.

## Explore

- New installations start with empty Today and Recurring lists and unset From/To labels. Tap a row to edit a draft. Back discards the draft; Save commits it.
- On Android, Today settings, errands, and Recurring lists persist locally across launches. Existing rows, including previously edited examples, are preserved. Clearing Today or deleting every Recurring list keeps those lists empty on the next launch.
- The SQLite upgrade keeps old labels as unresolved places. If both Roi and Rudy databases are found, the app asks which data to use; choosing Rudy imports a copy into a separate database and keeps both original files. A corrupt or unsupported source is not silently reset. This recovery flow has synthetic-database tests but has not yet been verified against real installations on Android.
- Add errand opens a short inline composer. Submit with the arrow or keyboard action; it stays open so another errand can be added immediately. Done adding closes it. Every new errand defaults to Anytime.
- Rows expand into the list as they are added; the composer keeps its focus and follows the growing content. Today and Recurring lists expand/collapse with short, interruptible transitions. The platform's Remove animations preference makes these transitions immediate.
- The focused editor has optional multiline Notes for shopping lists or details to remember. Notes stay out of the compact list body; a small note icon marks errands that have them. Save commits notes and Back discards the draft.
- Timing and repeat frequency use visible labeled radio choices. Weekly and fortnightly metadata use a weekday sheet with pending selection, Done/Cancel, and focus restoration. Monthly day uses numeric entry from 1 to 31; invalid input is revealed on Save even after the Repeat section is collapsed or scrolled away. These remain editor drafts until Save or Save list.
- From/To Map buttons, the focused editor's Open map action and saved-place location editing use one map-based picker with a persistent search field. Google is the initial source with a one-second typing pause; Other sources explicitly selects Geoapify/LocationIQ after 800 ms and Photon after 1.5 seconds. The source choice is retained only for the app session. Automatic search requires three characters; keyboard Search accepts two. Every adapter restricts results to the Philippines and rejects foreign results. Category suggestions include palengke, restaurants, groceries, shops, and pharmacies; they require map zoom 10 or closer and search within five kilometers. Back to map followed by Search this area deliberately refreshes named or category results using the selected map area; panning alone makes no requests. Already-authorized searches refresh device location and default to Near me until an area is explicitly chosen. Selecting a result or saved place centers it on the same map. Moving the map selects a draft pin without changing the search text or adding a positioning label, and disables confirmation until the pin settles. Confirm location commits once. Explicit name-only entry remains available on failure, without invented coordinates. Today displays an online preview of confirmed coordinates without a route; the separate offline preview in Settings is limited to the prepared Pasig/Ortigas package. The Google picker flow has isolated Android verification, including a real native map; the legacy recovery path and all-device coverage remain separate verification.
- Leave, Home by, and Travel share a tinted footer inside the route surface. Times use hour/minute fields, AM/PM, and quick choices; there is no clock dial. Home by must follow departure on the same day.
- The day menu appears when errands exist and can clear them with Undo. There are no example-reset actions. In-app feedback uses themed floating snackbars: four seconds normally, six with Undo. New feedback replaces old messages; accessible navigation keeps actionable feedback available.
- Recurring contains named reusable errand lists with the same rows and focused editor as Today. Create a list, add errands consecutively, edit its name/repeat metadata, or delete it with Undo. Back discards a list draft; Save list commits it. Tapping a saved list's errand opens its focused editor directly.
- Add to Today copies a group's errands with independent IDs, retaining timing, priority, and notes. Source item IDs prevent duplicate addition. Editing Today's copies does not change the source list. Repeat settings are descriptive; groups are only added when you choose.
- Settings explains on-device Android saving, browser session storage, and unavailable planning. Profile contains no sample identity. There are no theme or color-scheme selectors. Plan my day opens the manual review screen; it does not calculate travel times or opening hours.

Automatic recurrence, task completion, saved trips, in-app road routing, schedule solver, notifications, production backend, cloud synchronization and analytics are not implemented. Online place search depends on an external service and OSM coverage; it does not guarantee a business is open or accurately mapped. The local Valhalla feasibility tools and versioned planning contract are development evidence, not connected app functionality.

## Source map

- `lib/app/`: app/router, navigation shell, fixed light theme, and storage/feature information.
- `lib/core/data/`: Drift database schema, SQLite startup, and persistence error reporting.
- `lib/core/widgets/`: section surfaces, shared motion and feedback, selection controls, numeric time entry, and the shared manual-label place picker.
- `lib/features/maps/`: read-only regional package validation and the reusable native map surface.
- `lib/features/errands/`: shared errand model, compact rows/composer, and focused editor.
- `lib/features/today/domain/`: day model and transportation profiles.
- `lib/features/today/data/`: in-memory preview repository and SQLite Today repository.
- `lib/features/today/presentation/`: Today, grouped trip settings, and state controller.
- `lib/features/recurring/`: reusable list models, in-memory preview and SQLite repositories, controller, overview, and draft editor.
- `assets/fonts/`: bundled Figtree and its OFL license.
- `test/`: interaction and layout checks.

The [product scope](../../README.md#product-requirements), [decisions](../../docs/wayday/DECISIONS.md), and [architecture](../../docs/wayday/ARCHITECTURE.md) remain the broader project references. Historical Asikaso sources are preserved.


## Google-first search (D43)

From, To, errands and saved-place editing share the same picker. Google is initially selected; Other sources explicitly selects Geoapify/LocationIQ/Photon. Source choice lasts only for this app session. Switching preserves the field, origin and draft and never queries both groups. Saved places are filtered locally. Back or keyboard hide preserves search/query; Close search and Back to map explicitly close it. A selected Google record remains a draft until Confirm location.

The shared interpreter bundles 389 Philippine/global NSI brands at version 8.0.20260918 / fd4f3c84636838ac2f514a3f00e6a5eb415d59ae. McDo, Jolibee and Megamall are recognized without changing displayed input. Local fuzzy matching permits one edit for names of at least five characters, two for at least eight, and only auto-corrects a unique best match. Short terms, numbers and branch/locality qualifiers remain intact. Search original text bypasses correction; ambiguous suggestions are selectable. Filipino categories include Convenience and sari-sari stores, pharmacies, markets and restaurants. Nearby bare brands use Geoapify Places when supported; specific branches/landmarks remain named searches.

Google uses its standard native name/address cards and attribution, with no custom result merge/reordering. It has a one-second pause, three-character automatic/two-character submitted minimum, one active logical request, latest pending query, 1.1-second spacing, twenty starts/minute and one hundred/rolling day shared by search/details. The shared ledger reserves before binding and fails closed if saving fails. No custom Google response cache exists. Interaction freezes visible cards; Updated results applies an eligible staged binding locally. Panning never searches. Missing keys/services, access errors and quotas offer explicit Other sources without silent failover.

A Google selection requires an ID, valid coordinates, native retrieval timestamp and verified Philippine eligibility. Unknown selection metadata may load one standard details component under the same quota; confirmation remains blocked if still invalid. Your label starts with the original query. Durable Today/Recurring/saved records keep that label, place ID and static provenance/credit, excluding returned Google names/addresses and coordinates. Temporary coordinates live separately in Android cacheDir, excluded from backup/transfer, for at most thirty days from acquisition. Every coordinate access checks the lease; startup, foreground return, access and foreground expiry timers purge expired entries. Copies never extend expiry. Offline unexpired pins remain usable with credit; expired/evicted pins keep labels and require an explicit Refresh Google pin action. This is not offline Google search, downloaded Google maps or live traffic.

### Isolated native qualification

Authorize `dev.wayday.wayday.maptest` and the actual debug certificate on the SDK key, retaining the personal app entry. The verified test APK SHA-1 is `DB:F4:CB:E2:C5:F4:D0:39:27:E8:3D:C0:87:0C:57:5C:5B:43:8A:1B`. The key must allow Places UI Kit in the Wayday Cloud project. Run `./tool/test-map.ps1 -DeviceId <id> -Target integration_test/google_search_test.dart`; this target explicitly loads ignored configuration and disables uninstall. Other fixture tests do not receive live keys automatically.

The bounded harness uses public fixture coordinates, at most eight search loads plus one necessary details resolution, and stops on its first failed sample. It covers Megamall, McDo/mcdonals, Jollibee/Cebu, a Cebu street, Davao pharmacies, Carbon Market and convenience stores. It records correctness/count booleans, not returned names/addresses/IDs, private locations or credentials. At WAYDAY_GOOGLE_IME_READY, send Android Back to hide the IME; the harness then verifies query/search preservation and Flutter-dispatched Back. The initial native requests returned REQUEST_DENIED (9011) because only the normal app package was authorized. After the owner added the isolated identity, the eight-search sample passed. SDK callbacks contain IDs/coordinates but no returned names/address/country fields; the debug-only harness reports field-presence booleans, not card text. Name correctness must be reviewed visually. Build/sample success does not establish complete provider coverage or dashboard consumption.

Rebuild the dictionary deliberately with `py -X utf8 tool/build_brand_dictionary.py`. `assets/notices/nsi/SOURCE.json` records eleven source paths, 862 unsupported-geography omissions and 5,969 outside-Philippines omissions. The BSD notice is bundled and visible in map credits. No logos or branch coordinates are downloaded by this tool.


### Philippine eligibility without another service

Live qualification found that both standard UI Kit callbacks omit country/address fields even though the native cards display addresses. Country validation therefore uses the existing native coordinates against a local public-domain Natural Earth v5.1.2 Philippine land mask (commit f1890d9f152c896d250a77557a5751a93d494776). It contains 97 polygons and 7,406 vertices, about 167 KB. Structured foreign-country status, when present, takes precedence over this fallback. Points within 250 meters of the mask shoreline remain unconfirmed; some islands, reclaimed land and coastal places may be rejected. These users retain manual/Other sources selection. This is cartographic eligibility, not legal territory/access verification, and costs no network request.

Regenerate deliberately with `py -X utf8 tool/build_philippine_boundary.py`. The tool selects only the PHL feature and stores its source checksum/notice, discarding the raw world data. Credits are under map licenses. The fixed unit sample verifies Luzon, Visayas, Mindanao, Palawan and Batanes, and rejects Sabah, Taiwan, Indonesian islands, open water and invalid points.


### Current verification and design

The [sanitized qualification record](../../docs/wayday/evidence/google-search-qualification-2026-10-29.json) records the eight-search sample, metadata limitations, native controls and retained local accounting. Eight query bindings returned 2/10/10/10/1/10/1/10 records respectively; selection required no details load once local country validation was present. Native Google cards visibly returned the Megamall building sections rather than a standalone root, and their order was preserved. Do not describe callback field-presence booleans as automated business-name correctness. Console dashboard consumption was unavailable; local counts do not replace account-wide billing/quotas.

The picker restores the owner's previous search layout: compact underlined source choices, visible origin/location/area actions and Places heading, shared saved/status rows, and full Use name only / Back to map actions. Keyboard visibility keeps this same interface. On constrained Google viewports the controls and fallback regions scroll while native cards/attribution retain a usable viewport; Other sources keeps its original lazy pin-icon rows and distance labels. Google uses supported Figtree, regular-weight place-name, muted-address and flat-surface styling while retaining native card structure and order. Layout changes preserve the native host and do not rebind requests. Progress records the screenshot-restoration checks separately from the earlier integration qualification. Full TalkBack traversal, all keyboards and complete Philippine/coastal business coverage remain unverified.

For a bounded one-query confirmation check, use `./tool/test-map.ps1 -DeviceId <id> -Target integration_test/google_search_test.dart -GoogleSingleSample`. Add `-GoogleRealMap` to exercise the real native map; the full eight-query sample otherwise uses a deterministic map double and public fixture location. At WAYDAY_GOOGLE_IME_READY send system Back; the harness taps the standard native card and checks Confirm location separately. Missing-services qualification was performed only on the task emulator with Google Play services disabled and restored afterward, never on the personal phone.

The initial Google integration had 157 passing tests and nine baseline failures. After the screenshot-based restoration, `flutter analyze` has no issues and `flutter test` has 159 passes and eight failures, all among those nine baseline names; one previously failing case passed in this run. The restoration adds a native-view identity/request-count regression and updates the keyboard layout check. Progress records the current Android build and rendered checks. Google search, coordinates and pin expiry do not implement traffic, routes or navigation.
