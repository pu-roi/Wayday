# Wayday mobile

Android-first Flutter UI shell with Today, Recurring, a sample Profile, and Settings. It uses one light Cornflower theme, compact errand lists, focused editing, and Riverpod controllers backed by a local Drift/SQLite workspace. See [the approved plan](../../docs/wayday/IMPLEMENTATION_PLAN.md) and [live task board](../../PLANNING.md) for subsequent milestones.

## Run

See [the contributor quick start](../../docs/wayday/RUNNING_WAYDAY.md) for app-only, Docker-free search and full PostGIS modes. Docker is optional for UI and interpretation work.

Use Flutter 3.47.7 stable (Dart 3.13.5). Install Android prerequisites for your machine and connect a device with USB debugging, or start an Android emulator. From this folder:

```powershell
./tool/flutter.ps1 pub get
./tool/flutter.ps1 devices
./tool/flutter.ps1 run -d <android-device-id>
```

The PowerShell wrapper uses the ignored repository-local `.tools/` SDK when present; otherwise it uses Flutter from PATH. It does not download or install tooling. Standard `flutter` commands work with a separately configured toolchain. Manual review needs no server, API key or account. Map tiles require connectivity. Use my location requests one foreground fix; permission denial leaves manual pins and coordinates available.

The wrapper forwards Flutter flags such as `-d` and `-v` unchanged in Windows PowerShell 5.1 and PowerShell 7. Run `./tool/flutter-wrapper-checks.ps1` to verify argument forwarding and exit-code handling with an isolated fake Flutter executable; this check does not download or launch Flutter.

If the Android emulator builds and installs successfully but disconnects with `DevFSException` / `Service connection disposed`, try bypassing the Dart Development Service:

```powershell
./tool/flutter.ps1 run --no-dds -d emulator-5554
```

This workaround was verified on the local API 36 emulator on 2026-10-17, including interactive hot reload and hot restart. It does not establish the underlying DDS failure's cause and is not a general remedy for app crashes. DDS-dependent IDE/DevTools features may be limited. Keep the terminal session open: `r` reloads, `R` restarts, and `q` quits.

### Android Studio

Install the Flutter and Dart plugins, then use **File > Open** to open this `apps/mobile/` folder, which contains `pubspec.yaml`. Set the Flutter SDK to the repository's `.tools/flutter` folder when using the local toolchain. Select the running Android emulator or connected phone in the device selector, and run `lib/main.dart` with a Flutter run configuration.

Android Studio does not invoke `tool/flutter.ps1`. To reuse its installed tools and caches, add these environment variables under **Run > Edit Configurations > main.dart > Environment variables**, replacing `<repository>` with the absolute Wayday checkout path:

| Variable | Local value |
| --- | --- |
| `ANDROID_HOME` | `<repository>/.tools/android-sdk` |
| `GRADLE_USER_HOME` | `<repository>/.tools/gradle` |
| `PUB_CACHE` | `<repository>/.tools/pub-cache` |
| `JAVA_HOME` | The installed JDK directory inside `<repository>/.tools/jdk` |

Keep these machine-specific settings in ignored IDE configuration. A `CXX1101` error about a missing NDK `source.properties` indicates an incomplete NDK in the selected SDK. Check which SDK is selected before reinstalling: a complete copy may already exist in `.tools/android-sdk`. Flutter updates the ignored `android/local.properties` SDK path when it runs.

Use the Flutter toolbar's Hot Reload and Hot Restart controls during a run. Stop and run again for native Android or toolchain changes. Restarting the app preserves committed local errands; unsaved editor drafts still require Save.

For a local browser preview of the same widgets:

```powershell
./tool/prepare-storage-web.ps1
./tool/flutter.ps1 run -d chrome --web-port 8767
```

The web preparation downloads two checksum-pinned official Drift 2.35.2 assets into ignored web paths. Serve the wasm file as application/wasm. Browser data belongs to the origin (including port) and is separate from Android data; use one preview tab at a time. Clearing site data removes it. No runtime third-party script/CDN dependency is used for storage. The web target is a design-review convenience. Browser behavior does not verify Android system insets, Back gestures, keyboard behavior, or physical-device performance. iOS is deferred.

## Build and verify

```powershell
./tool/flutter.ps1 analyze
./tool/flutter.ps1 test
./tool/flutter.ps1 build apk --debug --target-platform android-arm64
```

The debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. Its provisional application ID is `dev.wayday.wayday`. It is for local testing, not store submission. An ARM64 build requires an ARM64 Android device; omit the target-platform argument to build other supported architectures.

The tests cover rapid consecutive quick add with preserved focus and Anytime defaults, save/cancel, multiline note copying and independence, interruptible list disclosure, reduced motion, feedback replacement and automatic dismissal, preservation of timing, numeric time validation and midnight, deadline order, source-backed places and manual pins, all five travel choices, remove/clear/undo, recurring creation/editing/deletion, duplicate prevention, forced light appearance, independent review drafts, stale-response protection, location cancellation and larger text on a small portrait phone. To write actual Flutter widget-renderer captures, set `$env:WAYDAY_CAPTURE = '1'` before running tests. Captures go to the ignored root `.impeccable/review/` folder. They are distinct from ADB `native-*.png` captures made on a connected phone.

## Explore

- On a new installation, Today starts empty; subsequent starts restore the saved workspace. Existing saved errands are preserved. There is no example-day loading action. Tap a row to edit a draft. Back discards the draft; Save commits it.
- Add errand opens a short inline composer. Submit with the arrow or keyboard action; it stays open so another errand can be added immediately. Done adding closes it. Every new errand defaults to Anytime.
- Module changes, including Today's Add from a recurring list action, use a short fade and slight slide while the navigation shell stays fixed. Remove animations makes module changes immediate.
- Rows expand into the list as they are added; the composer keeps its focus and follows the growing content. Today and Recurring lists expand/collapse with short, interruptible transitions. The platform's Remove animations preference makes these transitions immediate.
- The focused editor has optional multiline Notes for shopping lists or details to remember. Notes stay out of the compact list body; a small note icon marks errands that have them. Save commits notes and Back discards the draft.
- The trip date button edits the active draft date (Asia/Manila); it does not switch between multiple saved days.
- The editor shows an editable assumed 15-minute visit duration. Review suggested details explicitly to accept limited text rules; title edits preserve accepted values and original text.
- Place search uses real imported names, addresses and landmark aliases in the Pasig/Ortigas pilot. Results supply their names; existing saved places remain available. Distinct same-named branches can be saved independently.
- From/To Map buttons and the editor's Open map action open the search chooser. Choose a result or Choose on map, then move the full-screen map beneath its fixed pin and Confirm location. No custom name or coordinate input is required; coordinates are read-only. A pin inside one mapped place boundary takes that name; a unique mapped point within 10 metres can also match. Ambiguous or merely nearby places are selectable suggestions. Without a reliable match, Dropped pin remains usable. Use my location requests one foreground fix with a bounded wait and Cancel. Manual gestures invalidate pending fixes. No tracking or sharing starts.
- Leave, Home by, and Travel share a tinted footer inside the route surface. Times use hour/minute fields, AM/PM, and quick choices; there is no clock dial. Home by must follow departure on the same day.
- The visible Clear action clears errands with Undo; it appears only when the list has errands. In-app feedback uses themed floating snackbars: four seconds normally, six with Undo. New feedback replaces old messages; accessible navigation keeps actionable feedback available.
- Recurring contains named reusable errand lists with the same rows and focused editor as Today. Groups start collapsed and expand when their header is tapped. Create a list, add errands consecutively, edit its name/repeat metadata, or delete it with Undo. Back discards a list draft; Save list commits it. Tapping a saved list's errand opens its focused editor directly.
- Add to Today copies a group's errands with independent IDs, retaining timing, priority, and notes. Source item IDs prevent duplicate addition. Editing Today's copies does not change the source list. Repeat settings are descriptive; groups are only added when you choose.
- Profile shows Jace Bellen as a read-only sample with unset contact details. It creates no account and publishes nothing. Settings describes local storage, the trip time zone, and current limitations. There are no theme or color-scheme selectors. Plan my day opens a vertical draft review. Drag or use Options to reorder, change priority and select places. Back discards review changes; confirmation saves into Today with a revision guard. Find your way is the placeholder label; its current behavior still saves the reviewed draft locally, including when pins are missing. No calculated route or active trip is implied.

Committed errands, their places, Recurring edits, notes, trip settings and saved places survive restart. From and To are session-only and clear on cold launch or Flutter hot restart; ordinary background/resume does not clear them. Drafts still require Save. SQLite writes are serialized and transactional; failures show a persistent Retry banner, and malformed/unsupported data is never reset to examples. Empty saved lists remain empty. Uninstall/clear storage deletes local data; Android automatic backup is disabled. Local FastAPI place search is connected for development. There is no automatic recurrence, task completion, road routing, solver, native notification or analytics integration yet. M2-03 PostgreSQL/PostGIS runtime validation is complete; physical-location and coverage checks remain open.

## Source map

- `lib/app/`: app/router, navigation shell, fixed light theme, and preview settings.
- `lib/core/widgets/`: shared surfaces, motion, feedback, time entry and the place-picker compatibility export.
- `lib/features/maps/`: native map and foreground location adapter.
- `lib/features/places/`: structured places, saved places and focused pin selection.
- `lib/features/review/`: independent day drafts and vertical review.
- `lib/features/errands/`: shared errand model, compact rows/composer, and focused editor.
- `lib/features/today/domain/`: day model and transportation profiles.
- `lib/features/today/data/`: repository interface and an empty default for new workspaces.
- `lib/features/today/presentation/`: Today, grouped trip settings, and state controller.
- `lib/features/profile/`: read-only sample identity for design review.
- `lib/features/recurring/`: reusable list models, repository, controller, overview, and draft editor.
- `assets/fonts/`: bundled Figtree and its OFL license.
- `test/`: interaction and layout checks.

The [product scope](../../docs/wayday/PRODUCT.md), [decisions](../../docs/wayday/DECISIONS.md), and [architecture](../../docs/wayday/ARCHITECTURE.md) remain the broader project references. Historical Asikaso sources are preserved.

## Storage development

Schema version 1 is the first disk schema; the former prototype had no persistent data to migrate. The workspace stores three format-versioned aggregates in one transaction. Keep future migrations data-preserving; never delete/reseed unknown formats. The committed schema snapshot is in drift_schemas/.

```powershell
# With your Flutter/Dart environment and PUB_CACHE configured:
dart run build_runner build
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas
```

Commit app_database.g.dart and schema snapshots when the database changes. Downloaded browser/native runtimes and live databases stay ignored. SQLite native assets are fetched by the pinned package hook on the first build/test; subsequent runs use local caches. Tests use disposable synthetic databases and do not need a backend or network once dependencies are cached.

## Map integration

See [the contributor handoff](../../docs/wayday/MAP_REVIEW_HANDOFF.md). Override the default style with `--dart-define=WAYDAY_MAP_STYLE=https://your-provider/style.json` when required, preserving attribution. Public tiles have no availability guarantee; downloaded offline coverage is not implemented. Widget-test maps are synthetic and never used in production.


## Local place search and portrait orientation

Prepare and start the API from the repository root with `.\tool\prepare-places.ps1`, `.\tool\prepare-places-db.ps1` and `.\tool\start-places.ps1`, with Docker Desktop running; see [the service guide](../../services/api/README.md). Android emulators use the local API through `10.0.2.2:8780`. Physical USB testing needs `adb reverse tcp:8780 tcp:8780` plus `--dart-define=WAYDAY_API_URL=http://127.0.0.1:8780`. The API must remain running while searching. Cached/saved places and manual pins remain available if catalog search fails; fresh map tiles still require connectivity.

Wayday's Android phone interface is locked to upright portrait at native startup and before Flutter starts. Landscape is not a release feature. Verify larger text and the on-screen keyboard in portrait and verify that rotating the phone leaves the app upright. Android 16 may override orientation restrictions on large displays at least 600 dp wide; tablets are not a verified target for this release. Browser previews remain separate development surfaces.

During M2 testing, a cold start of the existing AVD with `-gpu swiftshader -no-snapshot-load -no-snapshot-save` recovered black app frames. No AVD data was wiped and no permanent production renderer opt-out was committed. If this recurs, cold-boot the virtual device and evaluate its software graphics option before diagnosing GPS as frozen. The exact host/renderer fault was not isolated; physical-device performance remains unverified.
