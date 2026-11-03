# Account-free trip sharing implementation

The owner approved replacing the loopback sample with real trip sharing and delivering a new official development preview through the website. This approval includes the real planned route, read-only browser and Android recipient views, optional owner location, optional return location from one paired Android recipient, and sharing that continues after explicit consent while the phone is locked. Phone verification remains separate from source and fixture checks.

## Interface and source identity

Your plan keeps a Share icon beside Close and retains Start trip and Save for reuse. Your trip exposes Share beside Whole trip; the tooltip changes to Manage sharing for an active share. A shared themed sheet previews the exact uploaded fields and route before creating the link. Management provides link resharing, recipient invitation/removal, a read-only viewer, independent location controls and End sharing.

The recipient website uses the existing logo, bundled Figtree, Canvas, Cornflower, numbered compact errands and a map-first responsive layout. It is served by the gateway, while Download app points to the existing Pages download section. Google Maps JavaScript renders the original Google route. There is no synthetic route or straight-line fallback. A map failure preserves the itinerary and offers Retry.

Sharing retains a separate two-hour encrypted route snapshot; accepted itinerary JSON and Drift remain authoritative for local task progress. The snapshot preserves exact coordinate order, including repeated boundary points; oversized routes fail explicitly rather than being simplified. Binding checks task order, titles, stop coordinates and endpoints. A navigation provider switch or reroute does not replace the shared original geometry. A replaced itinerary ends the old share. Only successfully committed local Done actions publish progress.

## Sharing contract v1

`POST /v1/shares` accepts an operation UUID, separate owner/viewer random capabilities and a version-1 snapshot. The only snapshot fields are source identity, ordered route coordinates, one row per errand (ID, title, displayed place and coordinates), generic start/destination labels and completed errand IDs. Notes and saved-place labels are excluded. The operation UUID and exact request identity support explicit idempotent retry after an uncertain create response.

`GET /v1/shares/{id}` accepts a Bearer capability. `POST /v1/shares/{id}/events` accepts revision-checked progress, end, invitation, recipient removal and broadcast events. Position writes instead bind the broadcast revision. `POST /v1/shares/{id}/pair` exchanges a five-minute single-use invitation for one independently generated recipient credential. Every native write also requires allowlisted App Check. Viewer credentials cannot mutate a session. Recipient location appears only in an owner-authenticated response.

Firestore holds credential digests, the latest position per broadcaster and temporary session metadata. The snapshot is encoded as JSON inside the document because Firestore does not allow directly nested coordinate arrays. Exact coordinates are restored at the API boundary. `deleteAfter` is the TTL field; every request independently enforces the fixed two-hour expiry. No TTL deletion timing is treated as an access guarantee. End clears the snapshot and location values immediately. Existing accounting documents and provider contracts remain independent.

Capabilities stay in URL fragments and authorization headers; the viewer HTML and link preview contain no itinerary. API responses are no-store. Access logs remain disabled. Same-origin requests avoid a new public CORS policy. Sharing has bounded minute burst guards and no daily usage allowance. Errors do not expose request bodies or provider details.

## Android lifecycle

Native capability and snapshot state uses Android Keystore AES-GCM and atomic files under `noBackupFilesDir`. Cold and warm verified HTTPS links open a separate read-only Flutter screen and do not import into Today. The official and test gateway associations each name the matching package and permanent signing certificate.

A visible consent action and runtime location/notification permission precede the location foreground service. Its persistent notification includes Stop sharing. Navigation and standalone sharing coordinate location ownership: Google provides raw fixes through the existing navigator, alternative guidance publishes its raw device feed, and standalone sharing acquires location only after navigation releases ownership. No second navigator or voice session is started. Service restarts and force-stop do not silently resume broadcasting.

Only fresh positions are sent, at least fifteen seconds apart. The server retains only the latest fix and hides fixes older than forty-five seconds. Approximate fixes are labelled. Stop takes effect locally before remote revocation completes; failed revocation remains pending and has an explicit recovery action. Late position requests cannot revive a stopped broadcast revision. Progress updates retain the latest committed state for explicit recovery after network loss.

## Configuration changes actually performed

On 2026-11-03, the existing authenticated Cloud project `wayday-513016` was inspected. Production and navigation-test were on revisions `wayday-gateway-pub-d3c2979ce904` and `wayday-gateway-test-d3c2979ce904` before this work. The Maps JavaScript service was enabled and a dedicated key named Wayday shared trip browser was created. It is restricted to Maps JavaScript and the exact production/test/candidate sharing origins; existing Android credentials were not broadened. Key values are excluded from this evidence.

A TTL policy on `tripShares.deleteAfter` was requested. This does not change accounting collections or reset their contents. The browser configuration is supplied separately to the deployment workflow. No account, billing activation, additional funds, phone installation or live Gemini request was performed by these configuration steps.

## Executed verification and pending work

The first sharing service/HTTP regression run passed 45 tests, including Firestore serialization, role separation, malformed JSON, pairing replay, stale positions, progress, idempotency and expiry. A broader pre-integration gateway run passed 106 tests. Six Playwright fixture-browser cases passed at 320, 390 and 1200 pixels, covering itinerary rendering, download/app affordances, unavailable/expiring links and pairing instructions. These browser checks used synthetic itineraries and intentionally unavailable Maps configuration; they do not establish live basemap readiness.

Eight Flutter repository tests passed after adding offline-revocation and uncertain-pairing recovery cases. Subsequent integration changes, native compilation, full source checks, live Maps rendering, hosted checks, signed APK verification and deployment still require completion. These results must be updated with actual outputs before distribution. Two-phone, physical notification/permission, locked-screen, minimized-app and official upgrade verification remain pending until actually exercised. The original public physical qualification record is historical and unchanged.

The isolated main-based sharing tree subsequently passed all 187 Python API/distribution tests with seven existing environment-dependent skips. Its Flutter analysis reported no issues. A real restricted Google Maps JavaScript basemap was rendered in two synthetic browser checks; the final capture at zoom 16 showed streets, all four fixture markers and Google attribution, with no page error or map failure. These checks loaded the browser map only and did not calculate a real user route or call Gemini, Places or Routes.

A disposable live Firestore round-trip then verified exact coordinate serialization, progress updates, end-time snapshot clearing and absence of raw capability values in stored documents. The synthetic document was deleted after the check. Website dependency audit reported no vulnerabilities; the pinned gateway dependency audit reported no known vulnerabilities. Current hosted/main publication and physical verification remain separate work.

The isolated main-based Flutter suite passed 693 tests with one existing skip. Thirteen sharing-enabled repository and widget checks passed, including both toolbar affordances at 390 units and at 320 units with double-size text. The current public release-profile fixture also passed. Android Kotlin compilation and `lintDebug` completed successfully without relaxing lint settings; local ignored `local.properties` paths were escaped correctly for this check. Hosted release compilation and the permanent signed APKs remain separate gates.

The final lifecycle review accounts for [Google's independent location listener lifecycle](https://developers.google.com/maps/documentation/navigation/android-sdk/events): startup/provider preparation reserves GPS ownership in a handoff state with both the standalone sharing feed and Google listener detached. The selected navigation feed attaches only after guidance becomes active. A regression check reproduces the former early attachment and verifies the corrected ownership sequence. This avoids starting Google's independent location updates while alternative navigation is still preparing or stopping.
