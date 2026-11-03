# Your trip provider switching: restricted destination investigation

Date: 2026-11-02 (Asia/Manila).

The owner subsequently approved a different, qualification-first same-Place-ID UI Kit repair plan. See [D72 qualification results](trip-switch-ui-kit-qualification-2026-11-02.md). The manual-picker proposal below remains historical and unapproved; it must not be implemented as a substitute for the approved plan.

## Owner report and requested correction

The owner opened Your trip > Map & navigation in the signed public-test app and found OpenStreetMap disabled. They explicitly clarified that switching must work for the already planned trip. This supersedes treating the disabled row as a sufficient user outcome. It does not authorize silently substituting a business branch, changing errand order/progress, misrepresenting data provenance or ignoring the separate requirement to obtain approval for interface changes beyond the original selector/recovery/map controls.

## Confirmed cause

`alternativeDestinationIssue` in `apps/mobile/lib/features/planning/domain/navigation_models.dart` rejects standard Google Places SDK references, separately rejects currently unqualified UI Kit routing export, and rejects expired/missing coordinates. The provider sheet disables its row when that function returns an issue. `TripSession` also checks before alternative preparation. The reported explanation exactly matches the standard SDK branch. Automatic recommendations use that SDK, so the current alternative cannot cover many ordinary accepted trips. This is a product coverage gap, not evidence that the test gateway or Geoapify route call failed. No request is dispatched while the row is disabled.

The prior test build and deployment therefore do not establish the owner's intended unrestricted switching. UI Kit is a separate source with separate permissions and must not be relabelled as standard SDK content or assumed to permit every third-party export.

## Official documentation checked

Checked on 2026-11-02:

- [Google Maps Platform Service Specific Terms](https://cloud.google.com/maps-platform/terms/maps-service-terms), sections 14.1–14.3: standard Places content can be used without a map but cannot be used with a non-Google map. Temporary coordinate caching permission is distinct from permission to display/use that content on another map.
- The same terms, sections 15.1–15.4: UI Kit has an explicit exception for non-Google maps, plus independent attribution/export/caching conditions. That exception is not permission to relabel existing standard SDK recommendations as UI Kit results.
- [Places SDK for Android policies](https://developers.google.com/maps/documentation/places/android-sdk/policies): standard SDK results displayed on a map require a Google map.

On that evidence, simply deleting the eligibility check or changing the `provider` string does not establish a valid integration. An automatic name lookup or coordinate reverse lookup seeded with the restricted result would also violate the original exact-destination/no-substitution contract and is not proposed as a repair.

## Concrete repair awaiting interface approval

Subsequent owner-requested [application and developer research](map-switching-application-research-2026-11-02.md) identified the existing-Place-ID UI Kit display path as an additional avenue. The manual-selection proposal below is therefore an option, not the only possible remedy, and has not been approved. Map-display permission and Geoapify navigation export still require separate qualification. Do not add this picker flow merely because it was proposed here.

Reuse the existing location picker only inside Your trip when a requested switch has restricted remaining stops. Keep the current toolbar, errand panel, Whole trip, Done, Back and Finish layouts. Eligible trips retain direct switching.

1. Selecting OpenStreetMap starts explicit preparation instead of leaving a permanently disabled choice.
2. For each restricted remaining navigation target, ask the user to independently select the intended destination using a manual pin or Other sources. Reuse the existing picker styling; do not prefill a MapLibre marker/camera/search from restricted Google coordinates, addresses or display names. User-owned errand labels can identify which task needs a destination.
3. Do not silently pick another branch. The user must choose the intended branch/entrance; independent provider coordinates can differ, so do not claim an automatic exact-coordinate conversion. Cancel returns to the current trip without changes.
4. Keep independent, provider-scoped navigation targets separate from the original Google references, task identities, completed progress and accepted stop order. Preserve every existing errand even when consecutive errands share a stop. Validate each independent target and provenance before routing. A failed search, cancelled picker, invalid result or failed persistence must not enable an unsafe route or partially switch the navigator.
5. Prepare and validate Geoapify routing, persist the independent targets plus provider choice through guarded current-run writes, then use the existing serialized navigator switch. Preserve concurrent completion writes and finished-trip guards. Persist only independently permitted location data; do not copy restricted Google coordinates into new JSON.
6. Switching back to Google keeps original references where valid; expired references require the existing explicit recovery. Restart must restore alternative targets independently without a Google lookup merely to obtain coordinates for the alternative. Route geometry/instructions remain transient.

Example: for the owner's haircut errand, selecting OpenStreetMap opens the existing picker for that errand. The owner selects the same barber/entrance from an independent source, confirms it, and Wayday switches without changing Done states or the other errands. If the owner cancels, the trip continues with Google. No planning screens or recommendation engine changes are proposed.

This is a concrete proposal, not an implemented or approved interaction. The owner's earlier explicit no-additional-interface-change requirement requires an answer before dependent runtime edits. If the owner requires an entirely seamless switch with no additional selection for existing Google-only destinations, a broader independently sourced destination/recommendation design or explicit provider permission is required; do not promise that a UI-only patch can deliver it.

## Verification needed after approval

Use mocked services for restricted/mixed/eligible targets, cancellation at each picker, repeated taps, stale callbacks, failed route/storage writes, shared stops, completed tasks, restart and finished-trip races. Verify no Google SDK fields reach Geoapify or MapLibre. Run Flutter analysis and the complete suite after implementation, then build a higher-version signed public-test update with the Navigation/R8, signature and private-value checks. Never uninstall/reset the owner's production or test application to apply the update. Live provider/App Check, GPS/voice and physical navigation qualification remain separate.

No runtime code, provider safeguard, UI layout, installed app, Cloud configuration or accounting record was changed by this investigation.
