# Removing custom navigation testing limits

Date: 2026-11-03 (Asia/Manila).

## Owner authorization and diagnosed limits

The owner reported failures on both Google and alternative navigation, then explicitly approved removing both custom daily testing caps and implementing the reviewed plan. The regular app remains version 100005, last updated November 2 at 04:31:20; Wayday Test is version 100004, installed November 3 at 01:38:47. This task changes neither installation.

Google Service Usage read-back identifies consumer overrides of fifteen per day for `navigationsdk.googleapis.com/set_destination_requests` and `navigationsdk.googleapis.com/set_destination_with_route_token_requests`. Both provider default values are 43,200,000 per day, with existing 30,000 per-minute limits. Monitoring records a true `SetDestinationPerDayPerProject` exceeded event at November 3 01:41:32 Manila, matching the screenshot. The SDK documentation identifies the Set Destination quota as the relevant quota for requests without route tokens. Existing billing is enabled; this is not an app dollar-allocation failure.

The test gateway was configured for a 250-credit rolling Geoapify allowance. Read-back found two route reservations of 101 and 105 credits plus 33 search starts, totaling 239. The next route requires at least 101 reserved credits and is blocked before upstream dispatch. HTTP logs show a successful route at 01:44:01 and subsequent 429 responses starting at 01:44:44. This does not establish exhaustion of the owner's Geoapify Free account. The reservation includes the existing conservative distance buffer, not a measured provider invoice.

## Implementation and checks

Added `Settings.geoapify_testing_limits`, defaulting true. Only exact `WAYDAY_GEOAPIFY_TEST_LIMITS=false` disables custom daily enforcement. The existing alternative-navigation flag and authentication remain mandatory. Both Geoapify route and search handlers pass the configured enforcement mode into the shared ledger. Daily credit and 500-request gates are bypassed in that mode; shared 1.1-second spacing and minute checks remain. Other providers' limits are unaffected. The existing ledger document, route estimates and timestamp arrays remain compatible and are not reset.

Regression tests cover usage beyond both historical ceilings, unchanged prior records/Google spending, continued spacing/minute rejection, other-provider limits, authentication, zero legacy allocation in opted-in mode and default/invalid-value enforcement. The initial failing run reproduced missing opt-out behavior; forty-one focused tests passed after implementation. The complete backend suite passes **78 tests with seven existing database-dependent skips** and the existing FastAPI/Starlette deprecation warning. An initial run hit a Windows temp-directory permission problem; rerunning unchanged tests with a new ignored `--basetemp` path resolved it. A controlled mutation reintroduced the routing credit gate and the regression failed as expected; the correct source was restored.

Built a Linux/amd64 gateway image from source manifest `6571a13995f9d2e669e5b7d4d2ac794695b7103e0109e196c68f91626968f3cf`. A network-disabled container with fixture-only configuration returned configured health and rejected unauthenticated routing with 401, without provider or Firestore calls. The first smoke fixture omitted its required ledger-path setting and returned 503; the corrected fixture supplied a dummy ledger path, without changing runtime behavior or weakening readiness checks.

Independent review confirmed the cap-removal branches preserve authentication/accounting/spacing and noted that raw 24-hour timestamp arrays remain subject to Firestore's document-size capacity at extreme request volumes. The deployment retains the owner's existing Free provider plan and explicit retries; no claim of infinite request/storage capacity is made. Changing the shared ledger format or introducing automatic retries is outside this cap-removal change.

## Exact deployment and quota changes

- Project `wayday-513016`, region `asia-southeast1`, service `wayday-gateway`; existing Artifact Registry repository `wayday/gateway`.
- New test-only image/revision suffix `navuncap-6571a139`, zero production traffic, existing `navigation-test` tag and URL.
- Set `WAYDAY_GEOAPIFY_TEST_LIMITS=false` and legacy `WAYDAY_GEOAPIFY_DAILY_CREDITS=0`. Preserve every other environment setting, the test Firebase app allowlist, shared ledger path, runtime account, all four version-1 secret references, one-instance test maximum, CPU/memory, concurrency and timeout.
- Preserve production at 100% on `wayday-gateway-00005-swj`. No normal-release feature flag changes, new secret, IAM role, billing activation, plan upgrade or funds.
- Delete only the two reviewed daily consumer overrides whose current value remains fifteen. Retain before/after snapshots and operation results, then verify default effective quotas and the absence of overrides. Do not force changes or bypass permission failures.
- Compare accounting before/after without writing it. Health and missing-App-Check checks make no provider calls. The same installed test APK can retry afterward at the unchanged gateway URL.

## Verified deployment and quota removal

The owner-authorized deployment completed successfully. Revision **`wayday-gateway-navuncap-6571a139`** is assigned only to the existing [navigation-test URL](https://navigation-test---wayday-gateway-553ek3bxxq-as.a.run.app). Registry digest: `asia-southeast1-docker.pkg.dev/wayday-513016/wayday/gateway@sha256:ce1c67cb3fa400248617e8b489872f038d01de2ec157417f418efc1fdab79228`. Read-back confirms `WAYDAY_GEOAPIFY_TEST_LIMITS=false`, legacy daily credits zero and the existing navigation flag true. All other environment values, test Firebase allowlist, shared ledger path, runtime account, four version-1 secret references, instance/resource settings, concurrency and timeout match the preceding test revision. The test tag still serves zero percent of production traffic; production remains **100% on `wayday-gateway-00005-swj`**.

Live preview health returned HTTP 200/configured with `providerCalls=false`; an unauthenticated route request returned HTTP 401/access and `Cache-Control: no-store`. Production health also returned 200. These checks made no routing, place, interpretation or Firestore reservation request. No actual provider-success or physical-navigation claim is inferred from authentication/health checks.

Both reviewed Google Navigation daily-fifteen consumer overrides were deleted through Service Usage without forcing safety checks or modifying IAM. Each deletion operation completed successfully. Independent read-back confirms **no consumer override** and effective/default **43,200,000 daily** for both Set Destination metrics. This restores the provider defaults, not unlimited requests or free usage. Per-minute limits, billing, native SDK key/restrictions and API enablement were not changed. Google's quota documentation says the new quota applies on the next route request; the installed app does not need a rebuild for this configuration change.

Read-only before/after Firestore comparison confirms recorded Google usage remains 28,740,000 micros, both existing Geoapify route reservations remain present, all prior shared search timestamps remain present and historical allocation metadata is unchanged. The agent made no ledger writes or resets. The private/disposable allocations were not accessed or changed by this deployment. Ignored `deployment-verified.json`, `cloud-verified.json`, before/after service/quota/ledger snapshots, operation results, source manifest, test/build/smoke logs and image metadata retain the exact local evidence. No secret value or access token was written to those logs.

The existing Wayday Test APK v100004 continues using the unchanged navigation-test URL. No APK rebuild, phone installation/reset, production traffic cutover, repository merge/push or public publication occurred. The next user-operated step is an explicit Resume guidance or provider selection; physical provider/GPS/voice testing remains separate.

## Rollback and boundaries

### Planning-cap correction after the owner's 02:22 screenshot

The initial execution removed Navigation SDK and gateway Geoapify caps but missed the separate Google Routes planning overrides. A new screenshot showed `Google routing quota is exhausted` on Your plan. The app produces that message for an HTTP 429 in its road-estimate adapter; this is separate from Google Navigation SDK route statuses. Read-only Service Usage showed 500 daily matrix elements and 100 daily Compute Routes requests. Monitoring matched the screenshot with `ComputeRouteMatrixCellsPerDay` exceeded at 2026-11-03 02:22:26.150443 Manila.

Under the owner's existing explicit instruction to remove all custom testing limits, deleted both Google Routes daily consumer overrides. Both operations completed successfully without forcing safety checks. Read-back confirms no consumer override and matching effective/default values (`9223372036854775807`, the service's unbounded-daily sentinel) for `routes.googleapis.com/compute_route_matrix_elements` and `routes.googleapis.com/compute_routes_requests`. Provider minute/element limits and ordinary billing remain unchanged. The agent made no live route request, ledger write, deployment, APK rebuild/install or personal-app operation. Exact rollback overrides are 500 matrix elements/day and 100 Compute Routes requests/day; restore only if requested, never by restoring the ledger.

Ignored `planning-quotas-before.json`, `planning-quota-operations.json`, `planning-quotas-after.json` and `planning-quotas-verified.json` record this correction. The owner's selected places/draft are unaffected; route/time confirmation requires the next explicit retry. Existing SDK/navigation versus planning error wording remains a separate presentation issue.

After the owner challenged the incomplete removal, audited every enabled relevant Google map service, including every quota-results page. Navigation SDK, Places API and Routes API now report no consumer quota overrides. Ignored `all-provider-cap-audit.json` records the results. This statement concerns custom Cloud overrides; provider defaults, short request safeguards, existing client search policies and private/disposable accounting remain separate. Source inspection also confirms the existing recommendation page disables Retry route update when the retained failure kind is `quota`. Removing a Cloud override does not itself change that already-rendered client state; this recovery-button defect needs a client fix rather than another quota change.

Rollback reassigns only the navigation-test tag to `wayday-gateway-navtest-f7377376`, retaining the production traffic target. Restore daily consumer overrides to fifteen using the recorded original metric/unit settings if explicitly requested. Never reset usage or restore an older ledger snapshot. Keep revision/image evidence for comparison.

Geoapify Free still has its own 3,000-credit/day allowance and provider rate limits. Google Navigation still has provider quotas and usage-based billing; restoring defaults does not make it free. No APK rebuild, phone harness, app reinstall/reset, live test route, repository merge or publication is required by this implementation. Existing technical UI error copy and camera recovery are separate work.

Official references: [Service Usage override deletion](https://docs.cloud.google.com/service-usage/docs/reference/rest/v1beta1/services.consumerQuotaMetrics.limits.consumerOverrides/delete), [Google Navigation route statuses](https://developers.google.com/maps/documentation/navigation/android-sdk/reference/com/google/android/libraries/navigation/Navigator.RouteStatus), [Geoapify Free plan](https://www.geoapify.com/pricing/).
