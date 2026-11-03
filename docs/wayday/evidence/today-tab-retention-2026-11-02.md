# Today map and tab-state retention — D70

## Root cause and repair

The owner reported a temporary black/reloaded map when returning to Today from Recurring, Profile or Settings. The source used one go_router ShellRoute and switched its child route with context.go. This removed Today from the tree; MapLibreMap.dispose then disposed its native controller/platform view. Returning constructed a new native view and loaded its style. Tile caching alone would not preserve that instance.

The shell now uses the installed go_router 18.1.0 StatefulShellRoute with four lazy navigator branches, retained in an indexed stack. Inactive branches are offstage, have Flutter tickers disabled and cannot receive focus. Tab departure dismisses keyboard focus, while scroll, disclosures and unfinished composer text remain in memory. Selecting the already active tab is a no-op. Root-level editors/planning and existing route paths remain compatible.

ShellTabActivity provides internal visibility to Today. Hidden/background pages stop the default-date timer; reactivation checks existing default-date eligibility. A visibility revision and post-await guards reject stale recovery work after another tab switch or background transition. Explicit/populated dates, drafts, editors, current trips and source revisions retain their existing protections. Banners and bottom-bar/rail transitions have stable content slots, preventing another route-subtree replacement.

No production map code, style/provider, attribution, marker policy, provider requests, storage schema, dependency or Cloud configuration changed. Legitimate marker edits still update the same map; explicit Retry may recreate a failed view. Retention lasts for the running session and does not guarantee survival of process death/resource reclamation or add offline tiles.

## Host verification

- Added regression tests before the repair. They failed on map disposal during tab departure and loss of unfinished composer state with the original single-shell route.
- The final full `./tool/flutter.ps1 test --reporter expanded` run passed **614 tests with one existing skip**. No tests were skipped or disabled for this repair.
- `./tool/flutter.ps1 analyze` reported **no issues**. `git diff --check` passed.
- Eight focused tab tests cover repeated tab round trips, direct route navigation, disposal only at shell removal, retained draft/scroll, keyboard dismissal, selected-tab no-op, storage banners, bottom-bar/rail transitions, midnight/explicit-date/draft protection, root date-editor Back, late recovery completion, background/resume and unavailable-map explicit Retry. Existing Today, map, persistence, current-trip and date tests also ran in the full suite.
- The unavailable-map test mocks the native transport without delivering style success: it creates one map, retains it through tab switches, then observes a second creation only after Retry. The lifecycle simulation follows Android's inactive/hidden/paused/resumed transition ordering.

Local logs are ignored under `.tools/tab-retention-*.log`. No fixtures were injected into the personal application's data or journals.

## Native verification

The guarded command is `./tool/test-map.ps1 -DeviceId emulator-5554 -Target integration_test/today_tab_retention_test.dart`. It uses the existing disposable Wayday_Clarification_Test emulator, a temporary 4 GB RAM override and phone density 440 (approximately 393 logical pixels wide). The guard verifies that the personal package is absent; `--no-uninstall` retains disposable data/accounting. The prior density override is restored afterward.

This fixture uses actual MapLibre/OpenFreeMap rendering with memory repositories and an empty mocked search service. It requests no Google/Gemini service, GPS or personal storage. It records the platform-view ID, sets a synthetic public-area camera, compares identity and camera after nine round trips, checks that Loading map does not return, and verifies a real GeoJSON marker update in the same view.

The first native run passed all nine identity/camera/return-state checks but its final marker assertion used the wrong method-channel return type (the native reply is a map containing features). After correcting that decoding, a second run again passed tab retention but queried the source before its asynchronous renderer update completed. The fixture now checks that Flutter supplies the new A pin, then waits for actual native source content within ten seconds rather than treating a Flutter pump as native completion. These earlier incomplete fixtures are not recorded as full passes; no production map changes were made to address either test error.

Before/return captures were copied to ignored `.tools/tab-retention-captures/`. The first capture was taken before all basemap tiles arrived; the return capture shows the rendered roads at the retained camera. Initial tile completion remains network dependent. Screenshots and identity assertions do not establish frame-by-frame absence of every possible compositor flash.

The final guarded native run **passed** in 26 seconds and emitted `WAYDAY_TODAY_TAB_RETENTION_PASSED nativeView=0 switches=9`. It verified the same platform-view ID and unchanged camera after all nine round trips, no renewed Loading map state on return, the new A pin in the Flutter request and a nonempty updated native GeoJSON source without replacing the map. Final before/returned/markers captures were retained in the same ignored output folder and inspected. The marker capture does not prove that the asynchronous camera refit and marker painting had finished; the native source-content assertion is the marker-update evidence. The prior emulator density override was restored to 240; its stored 2 GB AVD configuration was not edited, and the temporary 4 GB emulator process was stopped after verification.

## Qualification limits

Physical-phone tab return, TalkBack and frame-rate/memory behavior remain separately unqualified. Background/resume is covered by host lifecycle simulation; the native fixture covers tab switches and native marker-source updates, not an unplugged-phone rehearsal. No personal-phone update/reset, paid provider rehearsal, credential/accounting reset or publication is part of this repair. Existing unrelated working-tree edits are preserved.
