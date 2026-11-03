# Same-Place-ID UI Kit switching qualification

Date: 2026-11-02 (Asia/Manila).

Subsequent owner direction: D73 explicitly authorizes completing the separate test-build integration without a Google Support response prerequisite. The resolver, switching integration and signed version-100004 APK are recorded in [D73 implementation evidence](trip-target-switching-test-build-2026-11-03.md). The initial qualification findings below remain historical evidence; technical implementation does not establish a provider-permission conclusion.

## Technical probe continuation — 2026-11-03

The owner subsequently asked to try the integration. A bounded technical test is permitted without claiming that HTTP/SDK success establishes data-use permission. The first slice exercises one UI Kit load using Google's [public Sydney-office sample Place ID](https://developers.google.com/maps/documentation/javascript/examples/place-details). It makes no place-name search, uses no personal data and sends no coordinates to Geoapify. This tests actual SDK lookup behavior before changing the trip navigator.

Added an explicitly opted-in integration probe and disposable-emulator runner guard. The probe verifies the exact requested/returned ID, coordinate validity and acquisition metadata, displays the loaded native UI Kit component, and preserves the original disposable accounting. A durable pending marker prevents rebuilds from silently authorizing another call. The runner includes only the existing restricted native SDK key, requires an emulator identity and retains the personal-package block and `--no-uninstall` cleanup protection. Three runner safety tests pass; initial full Flutter analysis is clean. A second redundant analysis launch was cancelled after the first result was confirmed; local Flutter startup was unusually slow, so no live request was claimed from tooling progress.

Before execution, read-only ADB inventory found no connected physical device and only `dev.wayday.wayday.maptest` on the disposable emulator. Its prior Dart accounting file was absent. Restored the original US$2 allocation with US$0.782 already reserved, using the preserved recovery record, and read back the exact result. This is recovery of the original allocation, not a new or refilled allowance. The probe requires that floor before dispatch and reserves an additional conservative US$0.02 for its single SDK operation. Actual invoice charges remain separate.

**The live existing-ID probe passed.** Its clean runner exit was zero: debug build 175.7 seconds, disposable install 4.7 seconds, test result one passed in about fifteen seconds. Exactly one explicit UI Kit loader operation was dispatched. The returned ID equalled the requested public sample ID; latitude/longitude were numeric, finite and within geographic bounds, and the callback reported the requested revision, resolved status and an acquisition timestamp. The native component was shown after loading and then disposed. These assertions do not establish pixel-level attribution/layout quality or every Philippine business's coverage. Raw returned coordinates, names and addresses were not printed or persisted by the probe.

Read-back confirms the durable probe marker is passed and the original disposable accounting is **US$0.802 reserved of US$2**: the restored US$0.782 recovery reservation plus US$0.02 for this dispatched SDK load. This is a conservative application estimate, not a billing invoice. The pending/passed marker and accounting remain on the emulator; no retry/reset occurred. Evidence is in ignored `live-probe.log`, `disposable-budget-before.json` and `disposable-after-probe.json`. The restricted key worked for this sample without credential/IAM/billing changes. No Geoapify route, Google route, Gemini request or private/personal-app operation was dispatched.

This resolves the first live SDK lookup question for one public sample. It does not implement the Your trip resolver/cache/selector changes or prove map switching, live GPS/voice, third-party routing permission or an outage fallback. Full Flutter analysis passed; the complete Flutter regression suite passed with 626 tests and one existing skip, without live flags. Three runner safety tests passed and `git diff --check` found no whitespace errors. The host recovery record now retains US$0.802 as the minimum reservation before another rehearsal, preventing restoration of the older lower floor. The original findings below describe the earlier qualification snapshot.

## Outcome

**The full integration qualification gate has not passed.** The installed SDK exposes the required UI Kit public API, and the subsequent November 3 probe above confirms one live same-ID callback with valid coordinates. Current documentation supports non-Google map display and limited coordinate caching. Applicable permission to submit UI Kit coordinates to Geoapify for calculated routes and live navigation remains unestablished. This is an unresolved permission question, not a finding that the Android API is incompatible or that all UI Kit navigation is prohibited.

The owner's implementation plan explicitly requires stopping production integration when routing permission or Android compatibility is unresolved. The later explicit technical trial above is separate from that integration gate. No trip resolver, coordinate-cache change, selector unlock, production UI card or replacement phone APK was implemented. Existing eligible-source alternative navigation remains as previously implemented; the reported Google-destination switching gap is not fixed by the isolated lookup.

## Confirmed owner constraints

- The owner explicitly approved implementing the repair plan, retaining existing Place IDs, branch identity, errand order and progress. No repeated business-name search, automatic branch substitution or manual repinning is authorized.
- A compact attributed Google UI Kit component inside the alternative map area is approved only if the supported integration requires it. This is not approval to rearrange the surrounding trip interface or to treat an invisible component as a permission workaround.
- The owner confirmed the Google Cloud billing address country is **Philippines**. The non-EEA terms are therefore the baseline for this qualification. EEA-specific guidance cannot be used to establish an exception for this account. App coverage, device location and Cloud Run region do not themselves determine billing jurisdiction.

## Installed artifact and static checks

Inspected the dependency already present in the local Gradle cache, without changing versions or downloading another library:

`com.google.android.libraries.places:places:6.0.2`

Artifact SHA-256: `0f4a70d1ed872a7974fd72af21f03f86d696bcba16e7648d785d1ef77d63c0f7`.

Extracted the published `classes.jar` into ignored `.tools/trip-switch-qualification/` and inspected its public API with the existing JDK's `javap`. Five assertions passed:

| Check | Installed public API |
| --- | --- |
| Existing-ID loading | `PlaceDetailsCompactFragment.loadWithPlaceId(String)` |
| Listener registration | `PlaceDetailsCompactFragment.setPlaceLoadListener(PlaceLoadListener)` |
| Returned place object | `PlaceLoadListener.onSuccess(Place)` |
| Returned identity | `Place.getId()` |
| Returned coordinates | `Place.getLocation()` returns `LatLng` |

The compact fragment also exposes creation overloads accepting content, orientation and theme. This agrees with the current Wayday native bridge, which creates the fragment, loads an existing Place ID and handles ID/location in its loaded callback. At this initial static-check stage, a live same-ID assertion and native runtime fixture remained unqualified. The November 3 continuation above subsequently verifies one sample's returned ID, coordinates and revision, while broader failure handling and component layout qualification remain outstanding.

The archive does not contain optional `aar-metadata.properties` at the inspected standard path. An initial inspection incorrectly assumed that optional entry existed and stopped with `KeyError`. The corrected inspection records its absence and independently checks all five public API signatures. No minimum-SDK compatibility claim was inferred from the absent metadata. No reverse engineering of implementation or source extraction was performed; this checks public API declarations only.

Ignored static evidence: `artifact-api-inspection.json`, `places-6.0.2-classes.jar` and three `.javap.txt` outputs. The initial November 2 static inspection used zero live requests/device actions. The subsequent November 3 emulator/UI Kit operation is recorded separately above; no Geoapify route, App Check attestation or physical-phone verification is claimed.

## Official source findings

Sources were fetched on the qualification date:

1. [Android Place Details UI Kit](https://developers.google.com/maps/documentation/places/android-sdk/place-details-ui-kit) describes existing-ID loading, compact/full UI and loaded-place callbacks. Calls to the loader are separately billable; do not place them in an uncontrolled lifecycle/rebuild loop.
2. [Android attribution policies](https://developers.google.com/maps/documentation/places/android-sdk/policies) show a UI Kit component on a non-Google map and require visible, unaltered attribution with Google content distinguished from other content. The docs do not establish that an attribution label alone can replace a rendered UI Kit integration in this proposed use.
3. [Non-EEA service-specific terms](https://cloud.google.com/maps-platform/terms/maps-service-terms), sections 15.1–15.4, permit UI Kit with non-Google maps and coordinate caching for up to thirty consecutive calendar days. Section 15.3 retains responsibility for compliance with export, caching, derived-content and attribution restrictions when third-party products are involved.
4. [General Maps Platform terms](https://cloud.google.com/maps-platform/terms), section 3.2.3, contain the general export/derived-content restrictions. UI Kit's explicit non-Google-map exception alone does not answer the narrower server-routing export question to the standard required by the owner's plan.

Searches focused on official developer documentation, current terms and the official issue tracker for UI Kit with third-party routing, routing engines, Geoapify and navigation. The material found establishes the display path; it does not explicitly resolve the proposed UI Kit-coordinate transfer to Geoapify. Some search results discuss expanded EEA navigation rights, but the owner's Philippines billing confirmation prevents treating those as an applicable answer. The prior app/developer examples likewise do not supply a provider-specific permission for this case.

No written Google clarification or negotiated account exception is present in the supplied evidence. Do not infer one from the owner's ability to enable an API, from another application's feature or from successful HTTP responses.

## Exact clarification needed to resume

The following is prepared for Google Maps Platform Support or the owner's Google representative. It has **not been sent**; no message to a third party is authorized by this task.

> Our Google Cloud billing address is in the Philippines. Wayday is an Android application using Places SDK 6.0.2. It obtains an accepted business Place ID through standard Places search. On an explicit navigation-provider switch, we propose loading that same ID through a visible, attributed Places UI Kit compact component and reading the returned place ID and latitude/longitude. We would retain the UI Kit coordinates in a private temporary cache for no more than thirty days, separately from standard Places SDK coordinates, and preserve all required Google attribution.
>
> May Wayday transmit only those UI Kit-returned latitude/longitude pairs to its authenticated gateway and Geoapify Routing API, solely to calculate an ordered route and provide live turn-by-turn guidance on a MapLibre/OpenFreeMap map? No standard Places response coordinates, Google route geometry, business metadata or Google navigation instructions would be transferred to Geoapify. The original accepted Place IDs and errand identities would remain unchanged.
>
> Please identify the applicable non-EEA permission or restriction and any required component visibility, attribution, caching, road-safety or third-party processing conditions. Does the permitted integration require UI Kit content to remain rendered for every waypoint, or only the active stop? Does an existing Place ID obtained through standard Places search affect the answer when coordinates are subsequently obtained through the rendered UI Kit component?

A response covering this exact use, or equivalent applicable official documentation, can resolve the permission gate. Any runtime test success cannot substitute for that evidence. Once it is resolved, continue with the approved same-ID runtime fixtures, isolated coordinate leases, guarded switch, full regression checks and higher-version public-test APK. Preserve both installed applications and existing accounting; do not re-request approval already granted for the defined repair.

## Changes and verification boundary

The November 2 qualification changed documentation only. The November 3 continuation adds a gated integration test, the emulator-only runner opt-in and runner guard tests; it builds/updates only the disposable `.maptest` app and restores/advances its original accounting as recorded above. Production application behavior, dependencies, map-source guards, accepted-trip JSON, personal/production phone apps, Cloud resources, credentials and quotas remain unchanged. No release APK or production publication is part of this technical probe. Any subsequent full switching implementation needs its own regression/build/live qualification.
