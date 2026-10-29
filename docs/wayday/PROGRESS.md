# Wayday Project Progress & Activity Log

This document records the chronological activity history, milestone achievements, contributor attribution, and verification records for the Wayday project.

### [2026-10-29] Move Google Maps attribution below search results

- Changed the standard PlaceSearchFragment attribution position from TOP to BOTTOM, keeping the SDK's credit inside its results container above Wayday's fallback actions. Source labels, result cards/order, queries, quotas and confirmation are unchanged. Updated Design and D43 with the supported placement.
- Analyzer and all 21 focused Google/panel tests pass; the normal ARM64 debug APK builds successfully. No new live provider requests or phone installation were made. Bottom placement has been compiled but was not rechecked on a device; the preceding rendered/keyboard checks used top placement. The full-suite baseline remains recorded in the previous entry.

### [2026-10-29] Restore the screenshot-based search layout

- Restored shared source/origin/location/area controls, the Places heading, saved-place/status rows, and full Use name only / Back to map actions across Google and Other sources. Source choices now use compact text with selected weight and underline. Keyboard visibility keeps the same controls instead of replacing them with a Search options menu or hiding fallback actions. The original title, rounded query field, custom pin-icon result rows, distance labels, credits, draft and confirmation semantics remain intact.
- Google retains standard native cards/order/attribution and uses supported Figtree overrides with regular sixteen-unit names, muted fourteen-unit addresses and flat white surfaces. Content-sized header/footer regions scroll when constrained; normal panels retain a 180-unit native viewport, with 45 percent reserved on short panels. The first rendered check exposed clipped correction copy; the final sizing allows the full normal-screen controls and fallback rows to fit. Google cards remain visually different from custom provider rows rather than being copied into a custom list.
- A new platform-channel fixture verifies exactly one native creation/search binding across keyboard insets, resizing, text scaling and rebuilds, plus one disposal on close. It loads the real bundled font for layout measurements. The updated small-phone/1.6-text fixture verifies that visible-style controls, original-text action and full fallback rows remain reachable by scrolling. All 21 focused Google/panel checks pass. Final analyzer reports no issues. The full suite has 159 passes and eight failures, all among the nine previously recorded baseline names; the earlier empty/unavailable/retry/save-failure test passed in both runs. No new failing test names appeared.
- The final isolated Google check passes on the API-37 emulator with the application targeting API 36, at 360 by 736 logical units: actual Android Back hides the IME, query/interface and native identity survive, the standard card selects a validated pin, and Confirm location returns the chosen provider reference. The final one-query sample returned two records with no details load. This task made three bounded Google search bindings in total: an initial harness check encountered a five-pixel IME-hide transition, followed by two successful checks while refining layout. The harness now waits for actual dismissal instead of checking after a fixed delay. No other live provider was called; dashboard usage was not inspected.

- The isolated Other sources fixture also passes at 360 by 640 logical units, 1.3 OS text scale and disabled animations. Actual system Back and Gboard's visible hide arrow each preserve the query/interface; provider credits and the complete name-only/map actions remain reachable by scrolling, and explicit Close search returns to the map. Rendered Google and fixture screens were inspected against the owner's references. Fixture distances are synthetic/public test data, not coverage evidence. No personal-phone installation, uninstall, location read or task-data change was performed. All-device/TalkBack coverage remains unverified.

- Built the final normal ARM64 debug APK successfully and inspected its application ID (`dev.wayday.wayday`) and target API 36. The final analyzer is clean after the integration-test updates. Changed-file credential scan found no embedded key values; local documentation links resolve and diff whitespace checks pass. Emulator size, density, text scale, animation and keyboard overrides were reset, and the task-owned emulator was stopped. The APK was not installed on the owner's personal phone. No request policy, data migration, billing, routing/navigation or release work was added.

### [2026-10-29] Google-first search, Philippine interpretation and consistent picker design

- Implemented Google-first search with an explicit session-scoped Other sources choice across the shared From/To/errand/saved-place picker. Only the selected group runs. The Android bridge hosts standard Places SDK 6.0.2 UI Kit search/details fragments in FlutterFragmentActivity using hybrid composition. Query, origin and draft survive source changes and keyboard dismissal; confirmation remains explicit. Google cards and their order are not copied into the merged list.
- Added the pinned NSI 8.0.20260918 Philippine/global subset: 389 brands, literal aliases/category mappings, bundled BSD-3-Clause notice and omission manifest. Conservative local typo matching, selectable ambiguity, Search original text, McDo/Jolibee/Megamall and Filipino categories share one interpreter. Supported bare nearby brands use Geoapify Places; qualified names and landmarks keep named requests. Existing provider quotas, caches, country filtering, deduplication and ranking remain in place.
- Implemented one Google scheduler with one-second debounce, 1.1-second spacing, twenty starts/minute and one hundred/rolling day across search/details. Reservations persist through the shared ledger before binding; accounting failure blocks dispatch. Cancelled calls stay counted without outage cooldowns. Stale callbacks cannot overwrite the query/source/draft, and interacted native results stage updates behind Updated results. Missing keys/services and failures preserve explicit fallback without provider fan-out.
- Google place IDs, user-owned labels and static credit are durable provider references. JSON omits temporary coordinates and returned Google names/addresses. Separate private Android cacheDir leases expire thirty days after acquisition, with startup/resume/access/timer purging; copies share the original expiry. Repositories hydrate ID references without a SQL migration. Expired/evicted pins retain labels and offer explicit refresh; no startup network sweep is added.
- Native qualification exposed the SDK's intended callback limitation: search/details return IDs and coordinates but omit names/addresses/country. Added a pinned public-domain Natural Earth Philippine validation mask (97 polygons, 7,406 vertices, about 167 KB), with a 250-meter shoreline uncertainty exclusion and no retained world dataset. Foreign/unconfirmed points cannot commit; coastal/reclaimed land and omitted islands may need manual/Other sources fallback. This is cartographic membership, not a legal or road-access guarantee.
- Corrected the owner's design concern: compact source controls and content-sized headers replace the large outlined selector/fixed split. Supported native theming reuses bundled Figtree, Cornflower buttons, app text colors and quiet flat rows. Typing condenses actions into a source/origin row and Search options menu; hiding the IME restores full controls without requests. Native attribution remains visible. Android font resources are generated from the existing Figtree asset without an additional downloaded font.
- Initial native attempts received REQUEST_DENIED (9011). The owner's screenshot/confirmation established that only dev.wayday.wayday was authorized; the owner then added dev.wayday.wayday.maptest with the verified debug certificate. Google requests subsequently succeeded. The physical Samsung attempt was interrupted by ADB disconnect; current native verification used the isolated API-37 emulator while retaining target API 36. No personal app installation/data was replaced or uninstalled.
- The bounded live sample made eight Google query bindings, zero details bindings and zero Other sources requests, returning 2/10/10/10/1/10/1/10 candidates for Megamall, McDo, mcdonals, Jollibee/Cebu, Colon Street/Cebu, Mercury Drug/Davao, Carbon Market/Cebu and convenience stores. The rendered Megamall cards were the two building sections; no standalone root was invented. Callback names are absent, so nonempty counts do not establish every business label's correctness or complete coverage. The separate metadata qualification loaded standard details once, without a raw Places call.
- Native checks passed real Google card touch, original label retention, coordinate eligibility, explicit confirmation, fragment disposal, real keyboard Back/hide preservation and missing-Google-services fallback. A 360x640 logical viewport at 1.3 OS text scale with animations disabled passed selection/confirmation; task-emulator settings/services were restored. The real MapLibre/Google view combination also passed. The Flutter small-screen/keyboard layout fixture passes at 1.6 text scale. Full TalkBack traversal and all keyboards remain unverified.
- `flutter analyze` passes. The full suite reports 157 passes and the same nine existing failures, with no new failure names; the baseline was 139 passes/nine failures. Android ARM64 debug builds succeed at API 36. The [qualification JSON](evidence/google-search-qualification-2026-10-29.json) lists existing failures and actual checks/counts. Billing dashboard consumption was not accessible, so no account-wide usage or zero-cost claim is made. A verbose diagnostic echoed local build defines; that ignored diagnostic file was redacted, and a source scan found no configured credential values in maintained files. No billing change, backend, routing, navigation, public release or new account was performed.

### [2026-10-29] Google local credentials and restricted Routes qualification

- Saved the two owner-supplied Google credentials in ignored `.env.local`, preserving the Geoapify and LocationIQ values. Extended the allowlisted local configuration loader and blank example to support both Google names. The existing Flutter wrapper and Android Studio defines-file argument remain the configuration entry points. Gradle passes only the Android SDK key into Google manifest metadata; missing Google configuration does not add a startup dependency. No secret values were printed, committed, placed in source/run arguments, or added to reports. A scan of 187 source/documentation/configuration files found no Google key values.
- Added a deliberate bounded Routes probe and runner. The first live pass used public Mandaluyong landmark names and four starts, without retries: one correct DRIVE/TRAFFIC_AWARE Compute Routes request returned usable HTTP 200 output; wrong Android package and wrong SHA-1 headers were separately rejected with HTTP 403 `API_KEY_ANDROID_APP_BLOCKED`; one correct one-element Compute Route Matrix request returned usable HTTP 200 output. Counts are three route attempts and one requested matrix element, including the two denied route attempts. The sanitized [report](evidence/google-routes-qualification-2026-10-29.json) stores status/error enums, elapsed time and counts, not keys, private locations, full URLs, response bodies or returned Google route data. Subsequent runs use the Manila date and a unique filename if an existing report would be overwritten.
- Added six fake-transport regressions covering the full bounded flow, no key in URLs/reports, rejection of generic service-denial false positives, accepted incorrect identifiers, initial access failure, sanitized transport errors and empty-success responses. All six pass. `flutter analyze` passes; the full `flutter test` run has 139 passes and the same nine previously recorded failures, with unchanged failure names and no new regressions.
- Built the normal ARM64 debug APK successfully. Read-only inspection confirms application ID `dev.wayday.wayday`, target API 36, the SDK key matching local configuration in manifest metadata, and no Routes key in that metadata. The personal phone app was not installed, uninstalled or modified. This build/configuration check does not verify SDK initialization or native Google UI, because no Google SDK dependency or app feature integration was added yet.
- Recorded D42 and updated the product/architecture/stack/mobile guidance to distinguish the selected Google UI Kit, traffic-aware planning and embedded-navigation direction from the implemented credential/probe preparation. Preserved the independent Valhalla study, existing map/search providers, manual selection and saved places. The Console screenshots establish saved search limits, but the suggested Routes/Navigation reductions still need saved-table confirmation. Billing dashboard consumption was not accessible from the local tooling. No account creation, billing activation, purchase, deployment, background tracking, planner, release or public gateway was performed.

### [2026-10-29] Near me brand-spelling ranking correction

- Reproduced the owner's reported `jolibee` ordering with six public-coordinate fixtures. Literal `Jolibee` results received a stronger match group than nearby `Jollibee` records, placing approximately 6.6/55.3/125.4/134.3-kilometer results above 1.5/3.6-kilometer results. This was a relevance-classification defect rather than a missing device-origin reference. The new regression failed with the original screenshot order before the fix and passes with nearest matching branches first afterward.
- Read-only inspection of the connected Samsung's running debug app confirmed precise-location permission, an active device origin, completed Geoapify and LocationIQ searches, and Photon blocked through the adapter's access-denial path (401/403; the original exact status is not retained). No result update was staged behind the interaction freeze. The local accounting file recorded one request per provider with no cooldown or rate-failure streak, so local quota exhaustion did not cause the warning. Photon availability remains external; the client does not bypass its denial or substitute a paid source.
- Added a shared, bounded brand-term registry for Jollibee/Jolibee and McDonald's variants. Ranking recognizes named branches without optional brand metadata and retains explicit branch/locality qualifiers. Provider requests use the canonical term, LocationIQ enables its distance ordering for registered brand-only searches, and alias variants share one cache identity. The displayed query and provider record/provenance remain unchanged; no extra alias requests, general fuzzy correction, permission changes or quota reset were introduced.
- All 34 focused matching/adapter/controller/panel tests pass. Dart analysis passes. The full suite has 133 passes and the same nine baseline failures listed in the earlier search-pilot entry, with no new failure names. Regression cases cover the reported distances/spellings, qualified branches, canonical transport, cache reuse, partial access failure and stable selection. No live provider calls were made during investigation or automated verification. Temporary debugger forwarding was removed; queries, private coordinates, credentials and full request URLs were not emitted or saved. The owner's installed app and saved data were not modified.
- Built the normal ARM64 debug APK successfully with local provider configuration and confirmed application ID `dev.wayday.wayday`, target API 36. It is ready for a normal Android Studio Stop/Run; the existing phone session was left intact rather than replacing its running draft during investigation.

### [2026-10-28] Shared location and relevance-aware place search

- Implemented application-scoped permission checks, explicit consent, fresh acquisition on search opening, shared in-flight location work, a five-minute memory fallback, approximate access, explicit settings actions, fifteen-second acquisition timeout and background/revocation safeguards. Search-location actions preserve the query, interface, draft and camera; the separate map action retains its smooth zoom-18 flight. Panning changes only the viewport; named/category Search this area and Near me explicitly choose the origin.
- Added deterministic matching/ranking over the complete provider pool before the thirty-result limit, Megamall/McDonald's aliases, optional provider brand/alternate-name/locality metadata, straight-line distance labels and approximate uncertainty buckets. Pointer, scroll and accessibility interaction freeze visible records; Updated results applies later changes locally. A held-pointer regression verifies stable row position and selection provenance. Existing quotas, cache accounting, provider credits and saved-place JSON remain intact.
- Dart analysis passes. The full widget/unit suite has 129 passes and the same nine baseline failures listed below, with no new failing test names. Focused checks also cover two-character explicit map-area search, fresh acquisition without repeated prompts, stale/background callbacks, context replacement caps, alias/branch/locality ranking, small-screen credits and late-result selection. No live provider requests were made during this slice.
- The isolated native fixture passed on the existing Android 17/API 37 Medium Phone emulator, with the application still targeting API 36: real Deny and While using permission controls, preserved query/draft, nearest fixture branch, real system Back, a tap on Gboard's visible keyboard-hide arrow, and a fresh acquisition on reopening without another prompt. The harness uses public synthetic coordinates, mocked transport and the separate `.maptest` application ID, with automatic uninstall disabled. The owner's normal app was not installed, uninstalled or changed. The phone was disconnected, so physical-device location behavior, actual GPS quality, provider coverage, TalkBack and performance remain unverified.
- Preliminary native runs required more emulator memory, enabling its virtual keyboard, correcting UTF-8 fixture encoding and establishing a fresh editor connection after the system dialog. The final harness separates IME restore policy from keyboard-dismissal behavior; it does not claim automatic keyboard restoration after Android's permission dialog. The emulator keyboard preference was restored, temporary device captures were removed, and the task-owned emulator was stopped after verification. See [the native regression](../../apps/mobile/integration_test/location_search_test.dart).
- Rebuilt the normal ARM64 debug APK with local provider configuration successfully after native verification. The final focused picker/origin/panel checks and analyzer pass. The APK was not installed on the owner's disconnected phone.

### [2026-10-28] Location search keyboard and Back correction

- Removed the coupling between keyboard inset changes and search dismissal. System Back now hides the keyboard while retaining the search interface, query, available results, pending search, and map draft. Subsequent system Back events also keep search open. Added an explicit app-bar Close search control; it and Back to map close the session while retaining the field text. Explicit result selection and normal picker cancellation keep their existing behavior.
- Added three widget regressions for system Back, keyboard dismissal/inset transitions, and delivery of an in-flight result after the keyboard closes. Updated the existing explicit-close test. Dart analysis passes; the full widget/unit suite has 110 passes and the same nine baseline failures listed in the earlier search-pilot entry. Rebuilt the normal ARM64 debug APK successfully after native verification.
- The isolated native fixture passed on the connected Samsung SM A546E: a real ADB Back event and a tap on the Samsung keyboard's actual close arrow each hid the IME without closing search or losing text/results. Explicit Close search then returned to the map, and normal Back cancelled the picker. Two preliminary harness attempts used a child MediaQuery with keyboard insets already removed by Scaffold; the final test correctly observes native FlutterView insets. The test uses fixture data and a map double, makes no provider calls, uses the separate `.maptest` application ID, and disables uninstall. It does not verify other keyboards or the native renderer. See [the native regression](../../apps/mobile/integration_test/keyboard_navigation_test.dart).

### [2026-10-28] Multi-provider search presentation pilot

- Implemented a shared Geoapify/LocationIQ/Photon search service, latest-only scheduling, 800/1500 ms input delays, per-provider spacing/minute/rolling-day budgets, persisted reservations/cooldowns, cache TTL/LRU, conservative deduplication, progressive stable rows, and partial failure handling. Corrupt or unwritable quota accounting prevents new provider calls. Named lookup remains Philippines-wide; explicit Filipino category aliases use five-kilometer local searches. Panning updates context without requesting data or changing typed text.
- Added preserved provider/attribution JSON metadata without a database migration, user-activated attribution links, and ignored local key configuration for the Flutter wrapper and Android Studio. The direct-client APK contains extractable credentials and local budgets cannot enforce shared-account quotas; public distribution still requires a shared gateway. No backend, hosting, billing activation, app account, or synchronization was added.
- `flutter analyze` passes. The full suite has 107 passes and nine failures; exact failure names match the previously recorded baseline. Twenty-nine focused search/adapter/quota/panel tests pass, including the existing picker search tests updated for the new scheduler. The nine baseline failures remain listed below; no new test regression was observed.
- Built the ARM64 debug APK with the local Flutter 3.47.8 SDK, supplied local defines, and the Gradle cache used by Android Studio. The first wrapper build was stopped while preparing a separate Gradle cache; the completed verification used the existing cache. The app was not installed or uninstalled on the owner's phone. Native picker search, performance, TalkBack, and permission behavior remain unverified.
- A deliberate fixed Philippine sample made 31 search requests and one diagnostic request: both owner-provided keys worked, while Photon returned access denied from this host and was skipped after the first failure. Account dashboards were not available, so request counts are client-observed rather than dashboard measurements. The [review](evidence/search-qualification-2026-10-28.md) and [candidate evidence](evidence/search-qualification-2026-10-28.json) retain public results and limitations without keys or full request URLs.

The pre-existing failures are:

- `online_pin_picker_test.dart`: map pin confirmation returns chosen coordinates.
- `regional_map_test.dart`: unavailable map preserves label saving and Back cancellation at large text; settings credits work without a map and report missing notices; blank native renderer expires without preventing manual label entry.
- `saved_places_profile_test.dart`: place picker offers the updated saved place; profile edits, cancels and deletes without changing another place; empty, unavailable, retry and save failures are visible.
- `today_test.dart`: unset endpoints cancel unchanged and save actual manual labels; manual map labels edit endpoints and errand locations without geocoding.

### [2026-10-28] Unified location picker implementation

- Combined place search, saved places and online pin positioning into one picker route with a single Confirm location action. Search waits 600 ms, serializes requests, retains only the latest queued query and discards stale responses. Programmatic camera positioning preserves place identity; manual movement produces a draft pin with outdated address/source details removed. Explicit name-only fallback and draft cancellation remain available.
- Added and updated search-controller, selection, location-race and navigation tests, plus the isolated Android map harness. Dart analysis passes. Flutter execution remains blocked by Windows application control during native-asset preparation; these tests and the native interaction have not been verified in this change.

### [2026-10-28] Profile, Today map and credits updates

- Added local saved-place viewing, name/location editing and confirmed deletion through Profile, retaining independent place details in existing errands/endpoints. Today displays confirmed places on an online map inside its route surface; it does not calculate a route. Detailed map notices are available from Settings and the map information control.
- A project-local MapLibre 0.27.1 patch adds a per-map Android attribution-button option, so Today and the combined picker can use one themed information control. This requires a full Android rebuild and device verification. Icon-only attribution remains explicitly recorded as differing from OpenStreetMap Foundation's published safe-harbour guidance.
- The copied FastAPI service remains a bounded pilot catalog implementation for review, separate from mobile online search. Automatic recommendations, road estimates, itinerary optimization and reminders remain unimplemented. Earlier native evidence is historical and does not verify the current picker or patched plugin.

### [2026-10-28] Repository status and branch preparation

- Updated README, architecture, decisions, stack and agent guidance to distinguish current mobile capabilities, the imported pilot API, earlier evidence and outstanding verification. Removed the stale task-count percentage without recreating the retired task board.
- Checks passed: mobile Dart analysis; 22 routing/contract tests; 14 backend unit tests; the preserved prototype check; and 126 local document links. Seven PostGIS integration tests were skipped without a configured test database. Flutter tests and the isolated Android harness remain blocked by Windows application control. No runtime or device result is implied by the documentation update.

> [!NOTE]
> This log records completed work and verification evidence. The owner supplies current task priorities and sequence directly; no active task board is maintained.

---

## Progress Summary

The activity log records completed implementation, research and checks. Historical task identifiers below are evidence references, not an active task board or a current completion percentage. The owner supplies current work directly; the latest native verification limits are recorded above.

---

## Activity Log

### [2026-10-27] M5-02: Define automatic-planning inputs and outcomes.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: Planning · input contract
- **Summary**: Defined wayday.planning.v1 through a narrative specification, JSON Schema, 14 explicitly synthetic acceptance examples and executable cross-field checks. The contract separates editable input from calculated snapshots, preserves original text and fixed destinations, defines English/Filipino/Taglish clarification cases, versioned editable visit estimates and buffers, explicit Asia/Manila single-day timestamps, arrival/start/completion meanings, optional prerequisites, request revisions and completed history. It distinguishes missing candidates, no route, proven conflict, timeout, outage and unsupported capability outcomes. Truck subtypes require relevant explicit parameters; no clearance or complete legal-access verification is claimed. Initial limits of 12 errands, three candidates each and 38 matrix locations are bounded policy awaiting full-size performance measurement. All 22 routing/contract tests and independent team review passed. No API server, solver, automatic recommendations or Flutter planning models were implemented.


### [2026-10-27] M5-01: Validate regional routing and vehicle support early.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: Routing · feasibility gate
- **Summary**: Built and measured pinned local Valhalla3.9.1 on buffered pilot OSM data:18 real public-site routes, six4x4 matrices,30 asymmetric nonwalking pairs and explicit outside-graph400/code171. Source-way review and12t vs20t mapped15t weight contrast passed; actualPBFcheckrefs reports no missing members. Published graph/source/version/resource evidence:177,084,082-byte graph/PBF/timezone directory,673,581,738-byte image,352,440,320-byte containerpeak under2threads/4GiB; graphstages39+13s, warmmedian0.063s/max0.265s (not full-cap performance). Isolated Linux conversion and Docker-volume build resolve Windows DLL/9p issues without global policy/settings changes. Distinguish pickup/heavy subtypes and incomplete dimensions/access/motorcycle/ground-clearance data; finiteHGVpenalty is not a prohibition. Lead independent local route and source checks plus team review passed. No production API, mobile routing or legal/clearance guarantee introduced.


### [2026-10-27] M3-02: Prepare a licensed regional map package.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: Maps · data packages
- **Summary**: Prepared the bounded Protomaps 4.15.2 map package from 20261026.pmtiles using pmtiles1.31.2. Verified archive 8,046,175 bytes, zoom0-15, exact pilot bounds, MVT/gzip and CLI verify. Complete package 268 payload files 14,370,151 bytes plus 47,944-byte manifest, including all256 Noto Sans Regular glyph ranges, four light sprites, authored Wayday style, OFL/MIT/OSM notices and SHA256 per-file manifest. Source assets pinned to commit028c18f713baecad011301ff7a69acc39bcc2ae7 and checked against Git blob hashes. Extraction17.30s/40requests/8.4MB transfer; cached repeat7.58s with identical manifest/payload hashes, Pythonpeak28.4MB (excludes earlier CLI/native rendering). Five offline failure tests and lead verification passed. Raw/generated/app-package resources remain ignored; tracked tooling preserves prior packages and nested repository markers. Native/offline Android rendering remains M3-03.


### [2026-10-27] M3-01: Audit pilot place coverage.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: Data · feasibility
- **Summary**: Audited 35 independently frozen public Pasig/Ortigas samples against a bounded OSM extraction: 16 plausible site/branch matches, 3 ambiguous and 16 not found; only one matched site has OSM hours, no surveyed entrance accuracy. Final extract 11,679 elements, 5,278,128 bytes, snapshot 2026-10-27T06:59:26Z with reproducible query and raw/sample/tool/results hashes. Published CSV, frozen references, manual review and summary; preserved floor corrections separately, retained missing/ambiguous denominators, documented clustered-sample/adjacent-city limits, and explicitly deferred unvalidated Overture inclusion. Three offline matching/provenance regressions and independent review passed; raw data stays ignored. Bounded map/road feasibility may proceed; automatic catalog completeness is not established.


### [2026-10-27] DOC-08: Ground Stage 2 execution and integration boundaries in the source audit, with team ownership and verification gates.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: Documentation · implementation readiness
- **Summary**: Recorded the read-only source audit and Stage 2 execution brief in the existing Planning authority. Defined a 35-destination independently selected pilot sample, reproducible provenance and matching evidence, map/routing parallel paths, exclusive agent ownership and Android/offline gates. Preserve the existing picker/layout/editors/repositories; separate renderer, confirmed-place migration, pin selection, catalog search and computed-trip responsibilities. Added durable-save failure/retry acceptance to M4-01. Independent team review approved after navigation-dependency wording clarification. Verified 121 local links/anchors across 17 maintained documents, preserved all 31 prior task records and dependency declarations, and restricted changes to Planning/Progress. Prior source-audit analyzer and 48 tests passed; this planning-only update changes no runtime code, installs no packages and completes no map/routing tasks.


### [2026-10-27] DOC-07: Move the canonical README to the repository root and repair documentation rules, links, and skill references.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: Documentation · entry point
- **Summary**: Moved the full canonical README from docs/wayday to the repository root, preserving every section, product requirements and design-tool schema metadata. Rebased outgoing links and updated incoming links, ownership rules, and six affected project-skill references. Recorded D30 superseding the README-location part of D28; retained historical decision/progress context. Verified 121 local links/anchors across 17 maintained documents, identical product content and link destinations, unchanged seven skill frontmatters, correct three-root-Markdown layout, and unchanged application/historical source files. Documentation-only work; no Flutter checks required.


### [2026-10-27] M2-04: Verify the empty-state editing workflow.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: Android · checkpoint
- **Summary**: Stage 1 integrated checkpoint passed: flutter analyze clean; flutter test 48/48; debug APK built with android-arm64,android-x64 using Android Studio OpenJDK25.0.3. API37 x86_64 emulator verified existing-database upgrade preserves all four tables, fresh empty startup/unset endpoints, consecutive creation, editing/notes/numeric time, repeat/day controls, independent recurring copies, clear/remove/delete Undo, populated force-stop/relaunch with exact table comparison, and cleared/deleted lists remaining empty. Used disposable secondary user10 and removed it after restoring owner user0 and original animation settings. Native font-scale1.3 and reduced-motion checks passed. Secondary-user cold startup showed Android system-process ANR and UI automation delays; choosing Wait recovered and no app crash occurred during the subsequent walkthrough. Physical-device, TalkBack and performance verification remain unclaimed. Independent team review approved final fixes; maintained docs updated; local screenshots/database evidence remain ignored.


### [2026-10-27] M2-03: Replace unpredictable form dropdowns.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: UI · selectors
- **Summary**: Replaced timing/repeat dropdowns with radio rows, weekday with confirmation sheet, and monthly day with validated numeric 1-31 input. Preserved notes, optional status, numeric time entry, draft Save/Back and metadata-only recurrence. Independent review found offscreen lazy-disposed monthly validation and zero-duration scroll recovery issues; both fixed with direct controller validation and jumpTo for reduced motion. Forty-item regression covers empty/32 and focus recovery. Focused 17 tests, full 48 tests and analyzer pass. Native API 37 walkthrough confirmed monthly32 rejection,31 acceptance, weekly normalization, weekday Cancel/Done and large-text controls.


### [2026-10-27] M2-02: Define shared selection patterns.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: UI · shared design
- **Summary**: Added typed selection options, reusable labeled radio rows and a single-choice sheet with pending selection, Done/Cancel, dismissal cancellation, keyboard semantics, focus restoration, scrolling and reduced motion. Documented tokens/behavior in DESIGN and generated bundled-font synthetic preview in ignored .impeccable/review/selection-controls.png. Component/editor focused suite passes 17 tests; full suite 48 and analyzer clean. Inspected native weekday sheet on API 37 emulator at font scale 1.3 and with animations removed. No new package or production component gallery.


### [2026-10-27] M2-01: Start with user-created data.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: Mobile · real data
- **Summary**: Removed production sample factories, initial seeding and example-reset actions; new Android/browser state starts with empty lists and unset endpoints. Preserved schema version 1 and every existing row, including settings-missing orphan errands. Samples are explicit test-only fixtures. All eight repository tests and the integrated 48-test suite pass. Installed APK upgrade preserved every value in all four tables of the preexisting API 37 emulator database; fresh-user populated and cleared force-stop/relaunch checks passed. Existing user data was backed up locally and left intact. Browser state remains session-only.


### [2026-10-27] DOC-06: Consolidate seven execution stages into five with explicit dependency paths, safe overlap, and preserved verification gates.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: Documentation · execution plan
- **Summary**: Consolidated the seven execution stages into five, moved map package/rendering feasibility into the early gates, grouped local trip storage with maps/places, and grouped navigation with integrated verification and pilot acceptance. Recorded D29 and explicit dependency paths and safe overlap, including interface ownership and serialized shared-schema changes. Verified that all 23 runtime tasks appear exactly once across the five stages, no stage precedes its prerequisites, detailed task specifications and runtime board rows match HEAD, and local links/anchors in the three affected documents resolve. Independent team-agent review approved the changes. Documentation only; no application implementation or Flutter checks.


### [2026-10-27] DOC-05: Audit all project skills against the consolidated documentation and update affected references, design guidance, and implementation boundaries before pushing.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: Skills · documentation
- **Summary**: Audited all seven project skills and their two tracker helpers against the consolidated docs/wayday authorities. Updated UI guidance to use the root light Cornflower Design system, kept historical references provisional and Today layout specific, and added relevant planning prerequisites and contribution-guide references. Clarified automatic-planning release requirements, editable durations, provisional unknown hours, vehicle subtypes, preservation of existing rows, and deferred reminder/iOS work without authorizing implementation. Verified all seven frontmatters and 35 skill links/anchors, found no references to removed document paths, compiled the Python helper, and exercised disposable tracker list/start/done and dashboard updates plus the PowerShell list wrapper. Formal skill validator remains unavailable because PyYAML is missing; no dependencies were installed.


### [2026-10-27] DOC-04: Consolidate current project documentation in docs/wayday and merge redundant product, roadmap, and development files into their remaining authorities.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: Documentation
- **Summary**: Consolidated the seven current project documents in docs/wayday. Merged the complete product requirement body and schema/platform/stack context into README, merged unique development practices into CONTRIBUTING, and removed PRODUCT, ROADMAP, and DEVELOPMENT after checking their contents and callers. Preserved roadmap readiness conditions in PLANNING, all 23 runtime task specifications, prior completion history, application files, and historical references. Retained DECISIONS for rationale and superseded choices; recorded D28 and updated links, instructions, skill references, and tracker paths. Checked 104 local links/anchors across 19 maintained Markdown files and verified tracker list/start/done, dashboard counts, root fallback, and absence of old-location output using disposable copies. Skill frontmatter/references checked manually; formal validator still lacks PyYAML. No runtime application changes or Flutter checks.


### [2026-10-27] DOC-03: Move root project documentation into docs, consolidate the redundant product pointer, and repair references and task tracking.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: Documentation
- **Summary**: Moved README, CONTRIBUTING, PLANNING, and PROGRESS into docs; retained only AGENTS and DESIGN as root Markdown. Consolidated the redundant root PRODUCT pointer and its schema/platform/stack metadata into docs/wayday/PRODUCT. Updated documentation ownership, relative links, tracker skill, and helper paths. Verified 111 local links/anchors across 22 maintained Markdown files, preserved all 23 runtime task specifications and prior completion history, and tested tracker list/start/done and nested-root fallback on disposable copies. Application code and historical references were unchanged. Manual skill checks passed; the formal skill validator was unavailable because PyYAML is missing. No application implementation or Flutter checks performed.


### [2026-10-27] DOC-02: Consolidate the detailed plan into PLANNING.md and record the clarified automatic-planning release requirements.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: Documentation
- **Summary**: Consolidated the detailed implementation plan into existing PLANNING.md, removed the redundant separate plan, and repaired documentation links. Recorded cleanup-first automatic recommendations/branch selection/order/scheduling as the first-release goal, editable visit estimates, provisional missing-hours notices, and pickup/heavy-vehicle distinctions. Verified 23 detailed runtime task specifications, ordered dependencies, 86 local Markdown links across 13 documents, and unchanged hashes for 90 non-Markdown files. Documentation only; no application implementation or runtime tests.


### [2026-10-27] DOC-01: Audit document ownership and record the selected mapping direction and implementation plan.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: Documentation
- **Summary**: Audited root versus docs/wayday ownership; shortened root PRODUCT tool entry; corrected stale storage claims; recorded MapLibre/Protomaps/local POI and navigation decisions; added 22 dependency-ordered runtime tasks with acceptance criteria. Checked local links in 15 Markdown files, task IDs/dependencies, ignore rules, unchanged historical material, and SHA-256 hashes for 54 mobile non-Markdown files. Skill frontmatter/references checked manually; formal validator could not run because PyYAML is unavailable. No app implementation or runtime tests performed in this documentation task.


### [2026-10-27] M1-01: Persist Today and Recurring data in SQLite while preserving first-launch examples and verify data survives an Android app restart.
- **Status**: [x] DONE
- **Contributor**: Roi Cambe (@pu-roi <roicambe02@gmail.com>)
- **Component**: Mobile · local data
- **Summary**: Implemented and verified local Today/Recurring persistence; Flutter analyzer and full tests pass, Android ARM64/x86_64 debug builds succeed, and both lists survive emulator force-stop/relaunch.
