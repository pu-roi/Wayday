# Alternative navigation phone-test preparation

Date: 2026-11-02 (Asia/Manila). This records preparation and the owner's subsequent test-deployment authorization. Deployment and physical qualification results are recorded separately below when established.

## Approved continuation

After reviewing the separate `navigation-test` address, test-only identity, 250-credit shared rolling reservation limit, unchanged production traffic and existing Cloud/provider cost exposure, the owner explicitly authorized proceeding so the test app can be run from Android Studio. This authorizes the reviewed image upload/test revision and signed test APK preparation. It does not authorize a production traffic cutover, main merge/publication, account upgrade, credential/IAM restriction changes or personal-app replacement/reset. Do not ask for the same deployment approval again.

The local machine initially had no installed/authenticated Google Cloud CLI. Official CLI 591.0.0 was extracted under ignored `.tools/cloud-sdk/` after validating the Windows archive SHA-256 `109de903a875d840f839342af4eab77dcfe622417437d302208a73b48832da4c` against Google's published checksum. No system PATH change or new service-account key was needed. The owner completed Google sign-in and entered the release-keystore password in a separate local secure prompt. The signed APK is now independently verified as recorded below. Signing and Google authentication secrets must not be sent in chat, printed in logs or saved by the helper.

## Verified signed phone-test artifact

The signed APK is `0.1.0-navigation-test.1` / **100003**, package **`dev.wayday.wayday.publictest`**, label **Wayday Test**, 138,832,543 bytes. SHA-256: `e83107c7c333c1f0575aabf138d6cb37549b01860349605c779ed29da2b9c13e`. Versioned and stable copies are in ignored `.tools/alternative-navigation-phone/`; Android Studio's **Wayday Test** configuration points to the stable `wayday-navigation-test.apk` copy.

The build window exited before the helper recorded completion, leaving its Flutter log without a successful process-exit record. The cause of that window exit is not established. Do not claim a clean CLI exit from this run. The final signed APK had already been produced, so it was independently checked before exposing the IDE alias: valid whole-APK signature with the registered permanent certificate; exact test package/version/label; non-debuggable API 24+/target 36 manifest; valid ZIP entries; expected test gateway and all public configuration values embedded; all four configured private provider values absent in UTF-8/UTF-16LE; actual DEX/R8 mapping Navigation access check passed; exact MapLibre Navigation MIT notice present. The R8 mapping ID is `234dfa1b71ca26e8a7c40323a7322da8fe9996b63ffdfdcf6ea01e963dcba550`. No signing password was requested again for these read-only checks. Verification metadata is in ignored `verification.json` / `build-status.json`, and the final stable copy's hash was read back after copying.

The maintained build helper now performs the same Navigation access guard before publishing its alias on future complete runs. Six configuration-only tests pass. The existing complete feature verification remains in [implementation evidence](alternative-navigation-implementation-2026-11-02.md); no Flutter application runtime code changed during phone-test preparation.

A final read-only package inventory before exposing the verified APK still found only the production `dev.wayday.wayday` package: version **100005 / 0.1.0-rc.3**, last update **2026-11-02 04:31:20 Manila**. The separate public-test package was absent. No APK was installed by the agent, and no production application data or accounting was read or reset. The artifact is ready for the owner to select **Wayday Test**, select the connected phone and press **Run** in Android Studio. That first sideloaded run and live provider/GPS/voice qualification remain separate, pending actions.

## Verified test gateway deployment

The owner-approved preview is deployed at [the navigation-test gateway](https://navigation-test---wayday-gateway-553ek3bxxq-as.a.run.app), revision `wayday-gateway-navtest-f7377376`, in existing project `wayday-513016`, region `asia-southeast1`. Artifact Registry read-back from the completed image push identifies `asia-southeast1-docker.pkg.dev/wayday-513016/wayday/gateway@sha256:e95a6f00883e5fc70eb9003cd3a8794f3172a2523cf5112ae4fcfadf8791ac9f`. Reviewed local source/image guards passed before upload, and the live service resource version was rechecked before deployment.

Authenticated before/after service reads confirm **100% production traffic remains on `wayday-gateway-00005-swj`**. The test revision receives zero ordinary service traffic and is accessible through its explicit tag URL. Existing LATEST traffic became an explicit reference to the previously serving production revision, as documented by Google for `--no-traffic`. The preview allowlist contains only registered public-test Firebase app `1:793890374960:android:dbe21167436a082af974f5`; the production revision retains its original configuration.

Read-back confirms `WAYDAY_ALTERNATIVE_NAVIGATION=true`, `WAYDAY_GEOAPIFY_DAILY_CREDITS=250`, unchanged shared ledger path `accounting/public-preview`, unchanged runtime account `wayday-gateway@wayday-513016.iam.gserviceaccount.com`, and version **1** of each of the four reviewed provider secret references. Preview resources are zero minimum/one maximum instance, one CPU, 512 MiB, concurrency four and sixty-second timeout. The existing service-wide maximum of three is retained. No Secret Manager provider values were read, replaced or printed. Local configured private values were read only in memory for the APK exclusion scan and were not printed or copied into generated output. No IAM, billing, credential restriction, ledger document/counter, GitHub workflow, publication flag or production-app data was changed.

The local account could not impersonate the CI deployment service account because it lacks token-creation permission. No permission was added to work around this. The approved one-off deployment used the owner's authenticated account's existing Cloud permissions, while retaining the reviewed runtime identity. The main-only GitHub federation/environment remains unchanged. A first image-push attempt failed locally because Docker's credential helper lacked `CLOUDSDK_PYTHON`; setting that variable only in the deployment process fixed the tooling environment. The completed push and deployment logs are in ignored `.tools/navigation-phone-ide-reference/`.

Preview and production `GET /health` both returned HTTP 200 with `status=configured`, `version=1` and `providerCalls=false`. An unauthenticated POST to the preview's alternative route endpoint returned HTTP 401/access and `Cache-Control: no-store`. These checks made no provider or Firestore operation. They establish deployment/reachability/authentication rejection; actual sideloaded App Check, live Geoapify routing/accounting and physical GPS/TTS remain unqualified until a separate phone trial. The phone's production Wayday package has not been installed over, removed or reset.

## Observed state

- The phone is connected and authorized through ADB. Read-only package inventory reports `dev.wayday.wayday`; the separate `dev.wayday.wayday.publictest` package is absent. No installed application, data or provider ledger was changed.
- The production gateway's `GET /health` returned HTTP 200. A read-only `GET /v1/navigation/geoapify/route` returned HTTP 404, so merely running the new client against that deployed revision cannot exercise the new routing endpoint. Neither check called a paid provider operation.
- The existing full-app test configuration and permanent release certificate belong to the registered **Wayday Test** identity. A normal Android Studio debug Run does not use that registered release certificate. Do not ask the owner to uninstall the production package to resolve a signing conflict.

## Prepared local build helper

`apps/mobile/tool/build-navigation-test.ps1` builds the ordinary `lib/main.dart` application as **Wayday Test**, package `dev.wayday.wayday.publictest`, with both public-test and alternative-navigation flags enabled. Its initial version code is 100003, newer than the previous 100002 test app. It reads only the existing seven-field public test configuration, rejects private provider keys/production Firebase identity/production gateway, and accepts a reviewed isolated gateway origin explicitly.

The helper prompts for the existing release-keystore password locally without saving it, verifies the registered certificate before building, then verifies the output package and APK signature before copying it into ignored `.tools/alternative-navigation-phone/`. It does not install, uninstall, clear app data, deploy, publish or invoke a provider. `-PrepareOnly` validates/generates configuration without a signing prompt or build. All generated output must stay under the repository's ignored `.tools/` directory. Existing process environment is restored afterward.

Six local configuration tests passed: valid isolated preparation, private-key rejection, production identity rejection, production gateway rejection, HTTP rejection and the Android Studio prebuilt-release configuration. Fixtures use an explicitly non-live `.invalid` origin and make no network/device requests. The subsequent owner-signed live-configured APK is verified separately above.

After an isolated gateway origin has been read back and reviewed, the build command is:

```powershell
./apps/mobile/tool/build-navigation-test.ps1 -TestGatewayUrl '<reviewed test revision HTTPS origin>'
```

The owner enters the existing signing password in the local PowerShell prompt, never in chat. The resulting APK still requires verification before a separate, explicitly targeted phone installation. Leave the installed production Wayday package in place.

## Android Studio Run support

`apps/mobile/tool/configure-navigation-test-ide.ps1` writes the ignored `.idea/runConfigurations/Wayday_Test.xml` inside the mobile project. The build helper invokes it after package/signature verification and copies the verified APK to the stable `wayday-navigation-test.apk` path. A custom output directory is passed through to the Run configuration. The configuration uses `--release --no-pub --use-application-binary=<verified APK>` with `lib/main.dart`; it contains no credential values, private search configuration or build defines. The existing ordinary `main.dart` Run configuration is left intact.

This permits Android Studio's Run button to install and launch the registered release-signed **Wayday Test** application after preparation. Flutter reads the package from the prebuilt APK, rather than building the production identity from the project. Release mode has no hot reload or Dart breakpoints. Rebuild the signed test APK after source changes. Never choose the ordinary configuration or substitute the generic `app-release.apk` output for this test artifact.

The Run XML and its verified target APK are now ready locally. Android Studio window capture timed out; the subsequent text-only state exposed only window chrome. The configuration's XML and Flutter/plugin argument handling were checked, but the actual dropdown selection and device launch remain unverified. No UI clicks installed an app. Select **Wayday Test** and the connected phone, then Run; if the configuration is absent, reopen the mobile project to refresh the external configuration file. Do not select the ordinary `main.dart` configuration for this trial.

## Local gateway artifact

Built `services/api/Dockerfile.gateway` as `wayday-navigation-preview:local`, Linux/amd64, nonroot UID 10001. The local image/index digest is `sha256:e95a6f00883e5fc70eb9003cd3a8794f3172a2523cf5112ae4fcfadf8791ac9f`. The gateway input-file manifest SHA-256 is `f73773760b7c343d9322a12f74e3b2d00e79c7f504b9d89319db769e52a6bc20`; the working tree includes uncommitted gateway changes above base commit `da2c12bd2328d3a97d6f8373b271a8c118796cb8`, so that commit alone does not identify the built source. Per-file hashes, build output and artifact metadata are under ignored `.tools/navigation-phone-ide-reference/`. The initial local digest alone did not establish upload; the subsequent approved registry push/read-back is recorded separately above.

A temporary container ran with `--network none`, dummy public/provider settings and no credentials mounted. Internal-loopback health returned HTTP 200 with `providerCalls=false`, and POST to the alternative route endpoint without App Check proof returned HTTP 401/access. These checks qualify container startup and authentication rejection only; nonempty dummy keys do not establish provider validity. The temporary container was stopped and removed. No provider, Firestore, cloud deployment or phone action occurred.

## Concrete Cloud/configuration proposal for review

### Owner-supplied Geoapify quota evidence

The owner confirmed the **Free** plan and supplied a project statistics screenshot on 2026-11-02. It shows a **3,000-credit daily limit**, **131 total requests / 131 credits used**, and the selected UTC period **October 2–November 2, 2026**, across all API keys in the displayed project. The 131-credit figure is a selected-period total, not an exact daily usage reading. This supports the proposed small preview allocation; it does not independently audit other projects, concurrent consumers or live account availability at dispatch. Do not ask for an API key or infer a paid upgrade.

Geoapify's [official pricing](https://www.geoapify.com/pricing/) was checked on 2026-11-02 and lists 3,000 credits/day and up to five requests/second for Free. Keep existing request spacing and shared search/routing accounting. Retain the proposed **250-credit rolling shared reservation limit** for owner review; it is deliberately below the displayed provider limit and does not authorize spending, reset accounting or promise that every route consumes one credit.

| Item | Proposed test configuration |
| --- | --- |
| Project/region | Existing `wayday-513016`, `asia-southeast1` |
| Service | A new test-tagged revision of existing `wayday-gateway`; retain current production traffic allocation |
| Traffic tag | `navigation-test`; use the actual HTTPS URL returned by Cloud Run, not a guessed URL |
| Image | Existing Artifact Registry repository `wayday/gateway`, built from the reviewed gateway source including D71; record its exact source revision and image digest before deployment |
| Identity/secrets | Runtime `wayday-gateway@wayday-513016.iam.gserviceaccount.com`; existing deployment identity `wayday-deploy@wayday-513016.iam.gserviceaccount.com`. Reuse `wayday-gemini-api-key`, `wayday-routes-server-api-key`, `wayday-geoapify-api-key` and `wayday-locationiq-api-key` at the current reviewed versions, read back before deployment. No new role, secret value, key restriction, account or billing activation |
| App allowlist | Only registered test app `1:793890374960:android:dbe21167436a082af974f5` in the test revision; retain the production revision's existing allowlist |
| Navigation flag | `WAYDAY_ALTERNATIVE_NAVIGATION=true` in the test revision only |
| Geoapify allocation | Proposed conservative rolling test limit: 250 credits. Owner confirmed Free and supplied the 3,000/day and 131 selected-period usage evidence above. Preserve shared usage and handle live quota rejection explicitly; never reset the ledger |
| Ledger | Reuse existing nonpersonal shared accounting. Preserve Google spending records and Geoapify search/routing history; never copy/reset the private or disposable allocation |
| Scale | Preview revision: zero minimum, one maximum instance, one CPU, 512 MiB, concurrency four and sixty-second request timeout. The preview can run alongside the production revision and add infrastructure usage |
| Publication | No website/APK publication, production traffic cutover or automatic production feature enablement |

The 250-credit proposal is an application-side conservative shared Geoapify reservation limit, not funds, an exact invoice or an account-wide spending cap. Existing search usage counts toward it; requests can be refused if recent shared usage already reaches it. One illustrative trip with three remaining destinations reserves 103 routing credits per dispatch (three waypoint pairs plus the existing 100-credit distance buffer). A second such route would total 206 before search usage. Verify actual remaining account quota and other consumers before choosing/enabling any allocation. Google/Gemini/App Check/Cloud Run usage remains separate; no free balance or new funding is inferred.

At the original review, the local image was built but not pushed/deployed, and the machine lacked an authenticated Cloud CLI. The owner subsequently supplied Free-plan quota evidence, approved the preview and completed local authentication. The verified deployment above resolves those preparation prerequisites. The existing gateway workflow targets production on main and was not dispatched or changed for this preview. The user's D71 instruction requires deployment/configuration review separately from implementation; that review/approval is now recorded above.

Before mutation, read the live service configuration, current secret-version references, runtime identity and resolved production traffic targets. Push the reviewed local image to the existing Artifact Registry repository and record its returned registry digest. The proposed deployment uses `--no-traffic --tag=navigation-test`, the recorded image digest, unchanged current secrets and the test-only configuration above. Read back the resulting tag URL and verify that production still targets its previous revision(s), including when the previous traffic configuration referred to LATEST. Do not infer a successful deployment from a local image or a guessed URL. Validate preview health/authentication rejection before building the live-configured phone APK.

Google's [deploy reference](https://docs.cloud.google.com/sdk/gcloud/reference/run/deploy) and [traffic-tag guidance](https://docs.cloud.google.com/run/docs/rollouts-rollbacks-traffic-migration) were checked on 2026-11-02: a tagged revision can be exercised at its own URL without allocating production traffic. `--no-traffic` also resolves existing LATEST traffic to the previously serving revision, so compare resolved revision targets rather than merely comparing raw LATEST fields. This proposal does not change the existing production workflow or its protected main-only deployment path.

Rollback for the test preview removes only the `navigation-test` traffic tag after rechecking production targets; it neither resets shared accounting nor touches phone trip data. Keep the revision/image as evidence until cleanup is separately agreed. Requests to the tagged preview may incur Cloud Run, Artifact Registry, Secret Manager, Firestore, App Check and provider usage; existing free-tier availability is not assumed. No billing, paid-plan or funding change is proposed.

## Phone trial after approval and readiness

Install only the verified `dev.wayday.wayday.publictest` APK alongside Wayday. Create a small nonpersonal test trip in its independent storage using manually pinned or Other sources destinations. Standard Google Places SDK destinations remain restricted; UI Kit routing export remains separately unqualified. Exercise explicit provider choice, moving GPS/Recenter, voice availability, Whole trip, shared-stop Done, Back/restart recovery and Finish without opening or changing the production app's data. Provider calls are real during this user-operated phase; keep retries explicit and record actual usage and qualification separately.
