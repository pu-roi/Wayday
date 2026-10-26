# Wayday mobile

Android-first Flutter app with Today and Recurring. It uses one light Cornflower theme, compact errand lists, focused editing, and Riverpod controllers. Android stores Today and Recurring data in a local Drift/SQLite database. Persistence was verified across force-stop and relaunch on the API 37 x86_64 emulator on 2026-10-27. The browser preview remains in memory.

## Run

Use Flutter 3.47.8 stable (Dart 3.13.7). Install Android prerequisites for your machine and connect a device with USB debugging, or start an Android emulator. From this folder:

```powershell
./tool/flutter.ps1 pub get
./tool/flutter.ps1 devices
./tool/flutter.ps1 run -d <android-device-id>
```

The PowerShell wrapper uses the ignored repository-local `.tools/` SDK when present; otherwise it uses Flutter from PATH. It does not download or install tooling. Standard `flutter` commands work with a separately configured toolchain. No server, API key, location permission, or account is needed.

For a local browser preview of the same widgets:

```powershell
./tool/flutter.ps1 run -d chrome
```

The web target is a design-review convenience and uses in-memory sample data. Browser behavior does not verify Android system insets, Back gestures, keyboard behavior, or physical-device performance. iOS is deferred.

## Build and verify

```powershell
./tool/flutter.ps1 analyze
./tool/flutter.ps1 test
./tool/flutter.ps1 build apk --debug --target-platform android-arm64
```

The debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. Its provisional application ID is `dev.wayday.wayday`. It is for local testing, not store submission. An ARM64 build requires an ARM64 Android device; omit the target-platform argument to build other supported architectures.

The tests cover rapid consecutive quick add with preserved focus and Anytime defaults, save/cancel, multiline note copying and independence, interruptible list disclosure, reduced motion, feedback replacement and automatic dismissal, preservation of timing, numeric time validation and midnight, deadline order, manual map labels, all five travel choices, remove/clear/undo, recurring creation/editing/deletion, duplicate prevention, forced light appearance, unavailable planning, and larger text on a small phone. To write actual Flutter widget-renderer captures, set `$env:WAYDAY_CAPTURE = '1'` before running tests. Captures go to the ignored root `.impeccable/review/` folder. They are distinct from ADB `native-*.png` captures made on a connected phone.

## Explore

- Today starts with five example errands. Tap a row to edit a draft. Back discards the draft; Save commits it.
- On Android, Today settings, errands, and Recurring lists persist locally across launches. Example data is seeded only when the database has no saved Today settings; clearing Today or deleting every Recurring list does not reseed data on the next launch.
- Add errand opens a short inline composer. Submit with the arrow or keyboard action; it stays open so another errand can be added immediately. Done adding closes it. Every new errand defaults to Anytime.
- Rows expand into the list as they are added; the composer keeps its focus and follows the growing content. Today and Recurring lists expand/collapse with short, interruptible transitions. The platform's Remove animations preference makes these transitions immediate.
- The focused editor has optional multiline Notes for shopping lists or details to remember. Notes stay out of the compact list body; a small note icon marks errands that have them. Save commits notes and Back discards the draft.
- From/To Map buttons and the focused editor's Open map action open an illustrative map preview with manual place labels. There are no real coordinates, search results, or movable pins.
- Leave, Home by, and Travel share a tinted footer inside the route surface. Times use hour/minute fields, AM/PM, and quick choices; there is no clock dial. Home by must follow departure on the same day.
- The day menu can clear errands with Undo or restore the example. Settings can also reload the example. In-app feedback uses themed floating snackbars: four seconds normally, six with Undo. New feedback replaces old messages; accessible navigation keeps actionable feedback available.
- Recurring contains named reusable errand lists with the same rows and focused editor as Today. Create a list, add errands consecutively, edit its name/repeat metadata, or delete it with Undo. Back discards a list draft; Save list commits it. Tapping a saved list's errand opens its focused editor directly.
- Add to Today copies a group's errands with independent IDs, retaining timing, priority, and notes. Source item IDs prevent duplicate addition. Editing Today's copies does not change the source list. Repeat settings are descriptive; groups are only added when you choose.
- Settings describes the preview and can reload the example day. There are no theme or color-scheme selectors. Plan my day explains that calculation is not connected.

Automatic recurrence, task completion, real language parsing, business search, live map, routing, schedule solver, notifications, backend, cloud synchronization, and analytics are not implemented.

## Source map

- `lib/app/`: app/router, navigation shell, fixed light theme, and preview settings.
- `lib/core/data/`: Drift database schema, SQLite startup, and persistence error reporting.
- `lib/core/widgets/`: section surfaces, shared motion and feedback, numeric time entry, and illustrative map picker.
- `lib/features/errands/`: shared errand model, compact rows/composer, and focused editor.
- `lib/features/today/domain/`: day model and transportation profiles.
- `lib/features/today/data/`: in-memory preview repository and SQLite Today repository.
- `lib/features/today/presentation/`: Today, grouped trip settings, and state controller.
- `lib/features/recurring/`: reusable list models, in-memory preview and SQLite repositories, controller, overview, and draft editor.
- `assets/fonts/`: bundled Figtree and its OFL license.
- `test/`: interaction and layout checks.

The [product scope](../../docs/wayday/README.md#product-requirements), [decisions](../../docs/wayday/DECISIONS.md), and [architecture](../../docs/wayday/ARCHITECTURE.md) remain the broader project references. Historical Asikaso sources are preserved.
