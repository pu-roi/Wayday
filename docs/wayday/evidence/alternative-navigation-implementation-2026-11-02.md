# Alternative navigation in Your trip — D71 implementation evidence

Date: 2026-11-02 (Asia/Manila).

## Authorized scope and implementation

The owner approved the supplied Alternative navigation in Your trip plan. Work is confined to navigation in the last trip step, the existing gateway's additive routing operation and supporting documentation/tests. Existing toolbar, Whole trip, D69 Done, shared-stop task identities, Back and Finish remain. Illustrative visualizations were not copied into the interface. Today/Recurring retention, branding and other pre-existing working-tree changes were preserved.

Implemented components:

- A Map & navigation entry and existing-style content-sized sheet, Google default, current-trip-only accepted JSON metadata and structured recovery choices. Legacy records default to Google; no table migration or reusable-template provider preference.
- Provider-neutral coordinates, geometry, maneuver/progress and appearance contracts, with Google conversions retained at its adapter. Existing Google navigation accounting and mode gates remain.
- A MapLibre/OpenFreeMap viewport, validated transient Geoapify legs, explicit provider attribution, manual-source moving position, follow/pan/Recenter, compass, directions/ETA and device TTS controls. The alternative map's surrounding trip interface remains shared with Google.
- A Kotlin navigation-core 5.0.0 bridge with API-24 floor/current compile and target settings, excluded generic renderer and existing strict OpenGL 13.7.1 renderer. Only one active leg is submitted. Provider maneuver anchors satisfy the core's intersection requirements without inventing roads, lane availability or instructions. Each leg replaces callback generation; old-leg/session events are rejected.
- Explicit switch sequencing (prepare, guarded save, stop, attach), serialized completion/provider operations, monotonic completion and finished-run guards. Failed old-navigator cleanup restores metadata when the current run still exists. Pausing stops native speech/location; no background tracking/history is added.
- Coalesced off-route recalculation with a fifteen-second dispatch floor and explicit retry after failure. GPS samples, pan, camera and ordinary progress do not issue route requests. No periodic faster-route polling or planning matrix.
- An App Check-authenticated allowlisted gateway operation, bounded/validated inputs and GeoJSON conversion, fixed provider endpoint and disabled defaults. Geoapify rolling credit records are separate from Google dollar estimates and share search request/quota safeguards. No provider response or location is written to its ledger.

Standard Places SDK destinations are blocked before alternative routing. Places UI Kit retains distinct provenance and its non-Google display permission; third-party routing export remains separately unqualified in this implementation and is explained in the sheet. Eligible manual/device/other-source coordinates are reused exactly, without business search, branch substitution or order optimization. The server may snap routing geometry to accessible roads; destination markers retain the accepted coordinates.

## Verification and investigations

The initial compatibility gate passed: released artifact metadata declares minCompileSdk 35; Wayday retains compile/target 36 and minSdk 24. Kotlin compiled without a platform or renderer upgrade, a minified public-fixture release built, and repeated core creation/disposal passed on a disposable `.maptest` emulator. The artifact's Kotlin/runtime dependency updates resolved with the existing project plugin settings.

A synthetic movement replay exposed that navigation-core's progress processor dereferences the intersection list despite its model declaring it optional. The adapter now supplies each provider maneuver location as a progress anchor, without fabricated lane/road attributes. Replaying the real core then processed movement from approximately 154.769 metres remaining to within its arrival zone, using one leg and two provider instructions. The first synthetic fixture had an arbitrary 140-metre estimate, so its distance assertion was corrected to the actual supplied geometry rather than replacing geometry or weakening the runtime checks.

The first release attempt encountered a generated integration-test plugin registration mismatch after concurrent Flutter commands. A sequential retry with `--no-pub` retained that registry because Flutter deliberately skips regeneration in that mode. The normal sequential release build regenerated the registry, excluded the dev plugin and passed. Subsequent Flutter build/test commands remain sequential. Existing Google Navigation reflection access passed its compiled DEX/mapping check.

Confirmed local checks:

- Flutter analysis: no issues.
- Complete Flutter suite: 626 passed, one existing skip. This includes Google navigation/session/view, progress/Finish, shared stops, current-trip storage, switching both ways, repeated taps, failed writes, old-stop failure recovery, pause/late preparation, stale session rejection, routing validation, reroute coalescing/spacing and explicit failure recovery.
- API suite: 72 passed, seven existing skips, with one existing Starlette/httpx deprecation warning. The initial full API attempt hit the workstation's protected default pytest temporary directory; the rerun used an isolated workspace base directory, without changing or skipping tests.
- Inspected rendered provider sheets at 320 logical pixels and 100%/200% text with real Figtree/Material fonts. Existing trip regression layouts also cover 390/320/768 widths and short landscape, retaining the actual D69 Done control.
- The guarded disposable native core fixture passed initialization and synthetic movement. No personal-phone harness, paid provider request or real GPS fix was used by that fixture.

The final combined disposable native runner passed all three checks: real-core synthetic movement; the existing Google-driver fixture for Done/shared stops/Back/Finish; and the actual alternative MapLibre viewport with synthetic position changes, pan/Recenter, Whole trip and retained shared-stop completion. Its local blank style makes no tile/provider requests. The native capture was inspected: surrounding controls are preserved and route/markers/attribution/map controls render. This does not qualify the live OpenFreeMap service or physical GPS.

The final minified Android release built successfully with the alternative feature explicitly included, disposable signing and non-live fixture configuration (132.4 MB). The final APK passed the existing Navigation reflection check and contains the complete MIT core notice verbatim. A release-runtime dependency inspection resolved the strict OpenGL 13.7.1 renderer and excluded the generic renderer. Defaults in maintained configuration remain disabled; the fixture define is not a deployment or public-enable decision. Logs, local fixture APKs, temporary signing material and captures remain ignored under `.tools/navigation-core-reference/`; they are not downloadable development releases.

## Configuration and remaining qualification

Alternative routing remains disabled in the app and gateway defaults. The concrete Cloud Run/build flags, existing secret/IAM reuse, rolling quota allocation and conservative credit-buffer review are documented in [Distribution](../DISTRIBUTION.md#alternative-navigation-configuration-review--d71-not-deployed). No deployment, merge, push, publication, live quota allocation, billing activation, key/restriction change or personal-phone installation/reset occurred.

Compilation and fixtures do not qualify live Geoapify routing/credits, attested production access, real road maneuver quality, moving physical GPS, device TTS language support, unplugged physical-phone behavior or a real provider outage. Those checks remain separately recorded work before enabling the feature. Automatic planning/recommendations remain Google-backed; gateway/App Check outages remain shared failures. Offline maps/routing, bicycle guidance qualification, heavy-truck restrictions and background tracking are outside this version.

Primary implementation references: [core 5.0.0 release](https://github.com/maplibre/maplibre-navigation-android/releases/tag/5.0.0), [published artifact](https://repo.maven.apache.org/maven2/org/maplibre/navigation/navigation-core-android/5.0.0/navigation-core-android-5.0.0.aar), [tagged navigation source](https://github.com/maplibre/maplibre-navigation-android/tree/5.0.0/maplibre-navigation-core/src), [Geoapify routing/geometry/instruction/credit reference](https://apidocs.geoapify.com/docs/routing/) and [Google service-specific terms](https://cloud.google.com/maps-platform/terms/maps-service-terms).
