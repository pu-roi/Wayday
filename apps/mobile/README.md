# Wayday mobile

Android-first Flutter app with Today and Recurring. It uses one light Cornflower theme, compact errand lists, focused editing, and Riverpod controllers. Android stores personal data in a local Drift/SQLite database. Earlier Today and Recurring persistence was verified across force-stop and relaunch on the API 37 x86_64 emulator on 2026-10-27. Isolated emulator checks during reconciliation exercised app startup, adding an errand, the regional renderer and online map pin selection. Physical-device coverage and an Android upgrade from Rudy's database remain unverified. The browser preview remains in memory.

## Run

Use Flutter 3.47.8 stable (Dart 3.13.7). Install Android prerequisites for your machine and connect a device with USB debugging, or start an Android emulator. From this folder:

```powershell
./tool/flutter.ps1 pub get
./tool/flutter.ps1 devices
./tool/flutter.ps1 run -d <android-device-id>
```

The PowerShell wrapper uses the ignored repository-local `.tools/` SDK when present; otherwise it uses Flutter from PATH. It does not download or install tooling. Standard `flutter` commands work with a separately configured toolchain. Online search and online map pins need internet, but no local server, API key, or account. The optional Use my location button requests foreground location permission; manual pin selection works without it. The separate offline Pasig/Ortigas map preview is under Settings. Search defaults to the public Photon demo for limited testing and can be configured with `--dart-define=WAYDAY_PLACE_SEARCH_URL=https://your-photon-host/api/`. The demo may throttle requests or become unavailable without notice; it is not a production availability guarantee. See [Photon's demo terms](https://github.com/komoot/photon#demo-server). The online map uses the configurable `WAYDAY_MAP_STYLE` and defaults to OpenFreeMap, which is provided without an availability guarantee; see [its terms](https://openfreemap.org/tos/).

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
- From/To Map buttons, the focused editor's Open map action and saved-place location editing use one map-based picker with a persistent search field. Search runs after a 600 ms typing pause through a Photon-compatible service with a Philippines country filter; invalid and foreign results are excluded. Selecting a result or saved place centers it on the same map, and moving the map selects a draft pin. Confirm location commits once. Explicit name-only entry remains available on failure, without invented coordinates. Today displays an online preview of confirmed coordinates without a route; the separate offline preview in Settings is limited to the prepared Pasig/Ortigas package. The unified picker and recovery path still require Android verification.
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
