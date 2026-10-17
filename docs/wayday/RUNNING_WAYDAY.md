# Run Wayday as a contributor

Updated 2026-10-18. Android first, upright portrait. Work on `rudy-branch`. The application is at `apps/mobile/`; open that folder, not only its `android/` subfolder, in Android Studio with the Flutter and Dart plugins.

## Choose what you need

| Work | Docker? | Local Python API? |
| --- | --- | --- |
| UI, local errands, Recurring, saved places or interpretation | No | No; catalog lookup is unavailable, but local editing works |
| Real name search and named map-pin matching with the file catalog | No | Yes, explicit file mode |
| Full backend/PostGIS development and database integration tests | Yes for the supplied setup | Yes, default PostGIS mode |

Basemap tiles require connectivity in all modes. Offline personal editing is separate from map-tile availability. The phone never connects directly to PostgreSQL or receives its password. No public backend is deployed; each contributor runs their own services if needed. There is no required Wayday sign-in.

## Run the Android application

Install the Flutter version recorded in [the mobile guide](../../apps/mobile/README.md) and a compatible Android SDK/JDK on your machine. The repository's ignored `.tools/` directory is machine-local and is not included in a clone. The PowerShell wrapper uses it when present, otherwise Flutter from PATH.

Start a virtual device in Android Studio Device Manager, or connect an Android phone with USB debugging. From the repository root:

```powershell
.\apps\mobile\tool\flutter.ps1 pub get
.\apps\mobile\tool\flutter.ps1 devices
.\apps\mobile\tool\flutter.ps1 run -d emulator-5554
```

Replace `emulator-5554` with the ID printed by `devices`. Keep the terminal open: `r` reloads, `R` restarts Flutter and `q` quits. If a successful emulator installation disconnects specifically with a DevFS/DDS error, the documented local workaround is `run --no-dds -d emulator-5554`. It is not a general crash remedy.

For Android Studio run controls, open `apps/mobile`, select the Android device and run `lib/main.dart` as a Flutter configuration. Set the Flutter SDK to your own installation. This laptop's optional SDK/cache environment variables are documented in [the mobile guide](../../apps/mobile/README.md); do not copy another developer's absolute paths into tracked configuration. Stop and run again after native Android changes.

From and To are session-only. Cold launch or Flutter hot restart clears them; ordinary background/resume and module changes preserve the current session. Errands, their selected places, notes, Recurring templates, saved places, date and other trip settings remain local and durable. Recurring groups start collapsed and expand when tapped. Restarting does not erase the personal workspace.

## Optional search without Docker

With Python 3.12 or later installed, run from the repository root:

```powershell
.\tool\prepare-places.ps1
.\tool\start-places.ps1 -Mode file
```

Preparation creates an ignored virtual environment, installs pinned packages, downloads the bounded source extract and imports actual map records. The first download/import takes time. It is not a shipped example catalog. File mode includes mapped area matching, but does not apply the PostGIS correction table or run database tests.

## Full PostGIS setup

Open Docker Desktop and wait for its Linux engine, then run:

```powershell
.\tool\prepare-places.ps1
.\tool\prepare-places-db.ps1
.\tool\start-places.ps1
.\tool\verify-places-db.ps1
```

The database preparation prompts for each developer's own local password and saves it encrypted for that Windows user under ignored `data/local`. The API defaults to PostGIS; `/health` must report `ready` and `postgis`. Database/API startup scripts never silently switch modes. If another mode is already running, stop it first with `.\tool\stop-places.ps1`.

When upgrading an existing point-only catalog to mapped footprints/residential search, regenerate from the already downloaded extract before database preparation:

```powershell
.\.tools\api-venv\Scripts\python.exe services/api/tools/import_places.py data/downloads/metro_manila.osm.pbf --metadata data/downloads/metro_manila.osm.json
```

Then run database preparation and restart the API. Migration `002_place_footprints.sql` adds optional mapped areas without clearing existing places or corrections. Missing source boundaries remain unknown; database upgrades cannot invent them.

## Networking, stopping and verification

API: `127.0.0.1:8780`; emulator API address: `10.0.2.2:8780`, already the Android default. Physical USB testing uses ADB reverse and the API URL define described in [the mobile guide](../../apps/mobile/README.md). Fresh search needs the laptop awake and the API running. The database listens only on `127.0.0.1:55432`.

Stop the API with `.\tool\stop-places.ps1`. Stop only the project database with `docker compose -f services/api/compose.yaml stop places-db`; its volume preserves the catalog. Do not delete volumes or clear app storage as a routine restart step.

Mobile checks: `.\apps\mobile\tool\flutter.ps1 analyze` and `.\apps\mobile\tool\flutter.ps1 test`. These use synthetic map/search fixtures and require no Docker or live API. Database checks: `.\tool\verify-places-db.ps1`, which creates and drops isolated synthetic test databases on the configured local server, then checks the live PostGIS API.

See [API setup and contract](../../services/api/README.md), [database handoff](M2_DATABASE_HANDOFF.md), [task board](../../PLANNING.md) and [progress log](../../PROGRESS.md). Place-name lookup and mapped-area matching do not change the independently owned errand interpretation module.
