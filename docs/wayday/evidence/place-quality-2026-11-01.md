# Place information, pin confirmation and recommendation quality

Date: 2026-11-01, Asia/Manila. Owner-approved D66 implementation.

## Implementation

Choose a place retains its content-sized sheet, fixed errand pager and appended suggestions. Rows include the existing formatted address and available Google rating/count without requests on display. Equal locality/address lines are suppressed. Main plan rows remain compact; ratings are disclosed in Details.

The owner subsequently requested explicit open/closed status. Details and alternatives now show Open now/Closed now from fresh current hours, or Usually open/closed now for weekly fallback. A local minute-boundary timer updates the label without provider calls. Closing endpoints are exclusive. Reported permanent/temporary closures override an opening indicator, and unknown/failed/stale/pin-only hours never become Closed. Calculated visit compatibility remains separate, including warnings for a closed visit time or closing before completion. A future trip is not filtered by today's status.

The manual MapLibre picker no longer rebuilds the screen for raw zoom changes. A separate notifier updates the rounded zoom at most four times per second. The native map remains mounted. Selection uses the controller's final idle camera rather than its last movement event. Confirm location stays actionable through ordinary movement after a valid selection, waits at most three seconds for settling, prevents duplicate taps and rejects superseding gestures/selections. Invalid/unfinished captures retain the picker and show feedback. Manual labels, search identity, current-location confirmation and provider provenance are preserved.

Today treats its date as a plan date. Empty/default forms follow Manila midnight/startup/resume, except during composer/editor work or an accepted current trip. Explicit dates, populated/custom forms and legacy dates with unknown selection history are preserved. An additive dateSelected JSON field records the distinction; no Drift migration is required. Clear and atomic Finish reset to the current Manila date. Date-selection metadata is excluded from historical review/draft source fingerprints.

New Gemini interpretation/clarification requests can return validated PlaceSearchIntent variants and preferred/acceptable venue types. Historical builders remain frozen lookup paths, including the preceding location-intent versions. Saved fields remain optional. No automatic model upgrade, separate recheck control or phrase-based item classifier is added.

The native SDK bridge requests rating/count, passes primary type and result position, and marks its enriched metadata profile. Discovery assigns complementary queries to at most one corridor and two anchor searches total. Initial discovery combines bounded responses before shortlisting. Browsing consumes cached results first, adds up to three unique results and does not enlarge solver input. Suitability filtering is shared. General groceries prefer supermarkets/public markets over broad smaller-shop matches; suitable fallback and unrated businesses remain eligible.

The worker compares mandatory feasibility and approved constraints, optional completion, aggregate suitability, road seconds, count-tempered rating evidence, stop count and arrival. The quality prior is `(count * rating + 20 * 3.5) / (count + 20)`; missing data is neutral. It is Wayday's heuristic, not Google's score or proof of inventory/popularity. Confirmed branches and overrides remain authoritative. Hours, no-opening-wait and traffic refinement remain enforced.

## Verification and limits

Regression tests failed before the selection, date-default, semantic-contract and ranking implementations. Initial failures are in ignored `.tools/map-selection-red.log`, `.tools/date-defaults-red.log`, `.tools/search-intent-red.log` and `.tools/place-ranking-red.log`.

The zoom regression sends 100 changing events over successive widget pumps and asserts that none rebuild the picker map. This isolates eliminated Flutter rebuild work with a map double. The native profile rehearsal below is separate from physical-phone responsiveness and cold-cache/network qualification.

Semantic fixtures validate transport, suitability, ranking and recovery. They do not prove live Gemini generalization, stock, membership access or listing completeness. Routine checks make no live Gemini, Places, Routes or Navigation requests. The disposable US$0.782 accounting-recovery floor and existing allocations remain unchanged. The personal-phone installation and its data are untouched.

## Android fixture evidence

The enriched bridge and mocked selection/discovery/ranking/date fixture built successfully in 387.8 seconds. Its first run completed seven checks before Android's low-memory killer terminated the disposable process during the date widget check. Emulator logcat explicitly records the low-memory kill, not a Dart assertion. The emulator originally had 2 GiB RAM.

Relaunching the same disposable AVD with 3 GiB RAM, without wiping its data, allowed all eight checks to pass. The rerun build took 302.1 seconds, installation 2.472 seconds and checks eight seconds. Logs: ignored `.tools/place-quality-android.log` and `.tools/place-quality-android-retry.log`. No personal package was installed or operated on that emulator; the connected personal phone was not used.

That Android fixture snapshot predates the extra accepted-trip date case and the owner's open/closed-status comment. Those later cases passed host tests and are compiled in the final Android artifact; they are not described as independently exercised on a physical phone or in that earlier fixture run.

The host compatibility group passed 26 checks, including actual SQLite close/reopen, immediately preceding interpretation reuse with no generation, historical pending/failed/corrupt guards and midnight behavior. A later seven-check group covered clarification-version reuse, accepted-trip date protection, retained endpoint identities and SQLite persistence. The opening-status and existing hours group passed fifteen checks, including clock transitions without a request. The missing openAt contract first failed static analysis in ignored `.tools/hours-status-red.log`.

## Final host and visual checks

Flutter analysis passed with no issues. The final full suite completed in 100 seconds with **553 passes, one skip and the same eight recorded baseline failures**. The failure identities were compared, not merely their count: one online-picker case, three regional-map cases, two saved-place/Profile cases and two Today manual-location cases. Logs remain ignored at `.tools/place-quality-analysis-final.log` and `.tools/place-quality-suite-final.log`.

Inverting the scheduler's suitability priority made the ranking regression select the small shop and fail as expected; the original file was restored byte-for-byte. See `.tools/place-quality-mutation.log`. No test was skipped or assertion weakened to obtain the result.

All three alternatives-sheet checks passed. Fresh captures at 390 units/normal text and 320 units/doubled text were inspected: addresses wrap inside the scrolling content, the header/pager remain available, and actions follow the results without the former forced blank region. These synthetic captures are ignored under `.tools/alternatives-screenshots/`; they are not live Google listing or physical-device evidence.

## Native profile rehearsal

The guarded disposable emulator ran the actual MapLibre/free-basemap picker in profile mode, using the same hybrid-composition setting as the app. Both final runs used 3 GiB RAM and a 540 × 1200 physical display with density 240. Each warmed the visible area for three seconds, then performed six pan/pinch sequences with bounded native zoom animations. The explicit native animation makes zoom callbacks reproducible where injected pointer scaling varies. Both runs verified that native zoom changed from 16.0 to 17.0. They made no Google/Gemini calls or personal-storage operations.

The baseline temporarily restored only the old raw-zoom whole-picker setState callback. The optimized source was restored in finally after verifying that no concurrent edit occurred. Both final rehearsals passed; builds took 143.4 and 172.3 seconds. Logs: `.tools/map-profile-before-final.log`, `.tools/map-profile-after-final.log`; measurements: `.tools/map-profile-before.json`, `.tools/map-profile-after.json`.

| Observed metric | Baseline callback | Optimized callback |
| --- | ---: | ---: |
| Picker map-builder calls during interactions | 16 | 12 |
| Flutter build p95 | 6.180 ms | 5.691 ms |
| Flutter raster p95 | 40.833 ms | 33.138 ms |
| Flutter frames collected | 246 | 262 |
| Frames with total span over 16.667 ms | 226 | 239 |
| Style-ready time before warm-up | 2,107 ms | 2,542 ms |

The remaining twelve map-builder calls include settled selections; the unit regression separately verifies zero root rebuilds from raw zoom events. These are single samples on SwiftShader, not proof of a smooth physical map. Android's per-window HWUI report had p95 48 → 44 ms but a janky-frame share 44.67% → 50.90%; this includes native/window work outside Flutter's counters and does not establish an overall jank improvement. Native GPU/platform composition and tile/network work remain separate potential contributors.

An earlier 1080 × 2400 run displayed a System UI ANR; its measurements were discarded. A subsequent harness attempt found an incorrect Text cast on the zoom indicator's keyed Material container; that fixture was corrected before the final matched runs. No product assertion was removed. Cold/warm cache and phone GPU comparisons remain unqualified. The runner retains the disposable package/data with --keep-app-running, validates emulator isolation, and never uses drive's default uninstall cleanup. Display overrides were reset and the owned emulator was shut down afterward.

## Final Android artifact

The final arm64 debug build, including the open/closed addition and existing ignored search defines, succeeded in 169.4 seconds. Offline inspection verified package `dev.wayday.wayday` and signing SHA-1 `DB:F4:CB:E2:C5:F4:D0:39:27:E8:3D:C0:87:0C:57:5C:5B:43:8A:1B`. It was copied to ignored `.tools/artifacts/wayday-place-quality-personal-debug.apk`, without installing it on the phone.

Artifact SHA-256: `A7005B639714524ABD1CC64276EFF143F44BC300E8E476E82CDFD62E3612878E`.

Affected local Markdown links, PowerShell runner syntax and diff whitespace checks passed. Implementation, mocked checks, native profile rehearsal and live/physical qualification remain distinct. No live paid qualification was attempted; observed charged SKUs, current recommendation quality, GPS and unplugged-phone behavior remain separate checks.

## Sources

- [Android Text Search](https://developers.google.com/maps/documentation/places/android-sdk/text-search): relevance, single-type filtering and metadata.
- [SKU triggers](https://developers.google.com/maps/billing-and-pricing/sku-details/places) and [pricing](https://developers.google.com/maps/billing-and-pricing/pricing): retain conservative US$0.035 search/US$0.020 details estimates without assuming free usage or claiming measured charges.
- [Flutter profiling](https://docs.flutter.dev/perf/ui-performance) and [MapLibre performance](https://maplibre.org/flutter-maplibre-gl/advanced/performance/): distinguish widget work, native rendering, profile builds and device measurement.
- [Runaround](https://getrunaround.com/) and [keyword-aware route search](https://arxiv.org/abs/1208.0077): keep suitability and whole-trip constraints distinct.

No provider, dependency, model, backend, Cloud, quota or billing change is introduced.
