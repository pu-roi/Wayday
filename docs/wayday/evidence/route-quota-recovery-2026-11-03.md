# Explicit route retry after quota failure

Date: 2026-11-03 (Asia/Manila).

## Cause and implemented change

The owner reported a paused Your plan with retained places and a grey Retry route update button, then explicitly requested that the agent fix it. D74's Cloud cap removal was already complete, including the missed Google Routes planning overrides. Source inspection found the page's local failure blocklist excluded `quota`, so it could not expose the existing retry after provider availability changed.

The page now permits quota-class recovery only when every active candidate choice is present. It invokes the existing `retryRouteRefresh` path, retaining its draft-save, pending-flight, selection/source revision and calculation validation guards. Unresolved discovery quota failures remain blocked by this road-only action. No interpretation regeneration, business-name lookup, branch substitution, new request loop or UI redesign is introduced.

Planning HTTP 429 keeps kind `quota` and provider status 429 but uses the plain message “Route calculation is temporarily unavailable. Try again later.” Google Navigation quota-class statuses retain their structured kinds and now offer another map or later retry in ordinary language. Alternative navigation HTTP 429 retains kind `alternative_429` with matching plain recovery wording. Layout, controls, accepted order and trip completion behavior are unchanged.

## Tests and verification

Added five focused regressions: an actual mocked planning HTTP 429 retains diagnostic fields while showing plain wording; both Google quota enums and alternative HTTP 429 retain diagnostic identity without technical UI wording; unresolved discovery quota cannot become a road-only retry; and complete-choice recovery works at 320 pixels with normal and doubled text. The UI regressions verify no automatic retry during a thirty-second wait, one road flight while pending, the disabled busy action, successful return to Start trip, unchanged candidates and exactly one interpretation call across recovery.

Recorded the failing pre-fix UI/message run. After implementation, the new tests plus existing automatic route-refresh and recommendation recovery tests passed (fourteen total). A controlled mutation put quota back into the blocklist and the UI regression failed; the original fixed file was restored. Independent read-only review found no actionable issue in the retry gates/state guards/copy mappings. Nine distribution/runner guard checks pass.

Full Flutter analysis is clean (41.3 seconds). The complete suite passes **650 tests with one existing skip** in 2 minutes 52 seconds; no test was removed or newly skipped. The new signed test artifact is being completed separately. No live route, provider request, new Cloud deployment/quota change or phone install/reset is claimed by these mocked checks. Unlike D74 server configuration, this installed UI behavior needs an APK update.

## Test delivery

The build helper uses minimum test version code 100005 and version name `0.1.0-navigation-test.3`, raising the code further if a connected test app already has an equal/newer version. It retains the existing `dev.wayday.wayday.publictest` identity, permanent certificate, test gateway, source-target flags, package/version/label checks and minified Navigation access verification before replacing the stable Android Studio APK. Previous versioned test APKs remain available. Password entry stays local and is not saved in chat or source.

After verified build delivery, use Android Studio's existing Wayday Test configuration to update the separate test app in place, or install the verified APK as an update. Do not uninstall it or clear data. The regular Wayday package remains separate. The saved recommendation draft is retained and its road-only retry can be exercised after updating. Actual device upgrade, draft recovery and successful live routing need separate verification; no simulated test result establishes them.

## Verified signed APK delivery

The owner entered the existing keystore password locally. The outer signing window ended before its completion status/log was written, while Gradle continued compiling. A clean wrapper exit is **not claimed**. The resulting signed release artifact was checked independently before replacing the stable Android Studio binary; no new signing prompt or restriction workaround was used.

Verified package `dev.wayday.wayday.publictest`, label **Wayday Test**, version code **100005**, version name **`0.1.0-navigation-test.3`**, **138,947,231 bytes**. SHA-256: **`0cc88caf0b55603c00b44df137659655b8b43686c0469ebffb85e4b882e40adf`**. Whole-APK signature verification matches the existing registered permanent release certificate. ZIP integrity passes. The API-24 minimum, target 36, test Firebase identity, test gateway, public/test/navigation-target feature configuration and bundled core license are retained. All three AOT libraries contain the new plain planning/Google/alternative availability messages and existing target-cache code; the old technical planning-quota message is absent. Source hashes match the files tested before the build. The R8 Navigation access check passed against the actual APK/mapping.

Copied the verified artifact to ignored versioned `wayday-navigation-test-100005.apk` and the stable `wayday-navigation-test.apk` alias. Prior versioned 100003/100004 APKs remain available. The existing Android Studio Wayday Test configuration still targets that stable prebuilt binary; it does not use the generic project release output. Detailed ignored evidence includes `apk-verified.json`, `signature.txt`, `navigation-reflection.json`, `source-checks.json`, test/analysis/mutation logs and the original partial build log. The existing native-access/Cupertino font-family warnings are not suppressed. No dependency or SDK change was made.

The agent did not install/uninstall/reset either app, run a personal-phone fixture or dispatch a live provider request. The regular package still reports version 100005 with unchanged November 2 04:31:20 update time; the test package reported version 100004 before this build. The owner's next explicit Android Studio Run updates only Wayday Test. Actual upgrade/draft recovery/road retry success remains a separate phone check, and no Cloud quota/gateway change occurred in this D75 slice.
