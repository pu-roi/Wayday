# Standalone planning stall investigation

Date: 2026-10-31, Asia/Manila. Investigation only; no runtime repair or personal-phone installation.

## Report

The owner reported an indefinite Building your day screen with Finding suitable places along your trip. Reconnecting the phone to the computer appeared to let it work. The owner confirmed fully closing and reopening Wayday from its phone icon, rather than merely disconnecting an active IDE session. The intended runtime remains phone plus internet without a reachable laptop.

## Observations

- The planning code uses Google HTTPS endpoints and native phone bridges. No laptop HTTP endpoint, localhost backend or ADB reverse dependency was found in this feature. INTERNET permission exists in the main Android manifest as well as debug/profile manifests.
- Read-only checks on the connected phone found validated internet access, no ADB reverse mapping, no selected Android debug app and no Android wait-for-debugger setting.
- Read-only Dart VM inspection found the main and Drift worker isolates running, no breakpoints, and pause-on-start/exit/unhandled-exception flags false. This observes the connected session; it does not establish their earlier disconnected state.
- The inspected controller initially retained a cancelled/unfinished discovery state after route refinement, with no active recommendation flight or recorded failure. A later read found an active controller with a completed RefinedPlan in recommendations. No new plan or provider request was triggered by the investigation tools.
- Available safe provider diagnostics did not show an access, quota, network or timeout failure. A native crash in the shared buffer belonged to another application, not Wayday. No raw logs, errands, coordinates, provider credentials or complete VM objects were saved as evidence.

## Reproduced presentation and wait gaps

Two mocked diagnostic probes ran from an ignored file at `apps/mobile/.dart_tool/planning_stall_probe_test.dart`, through the project Flutter wrapper. Both passed as demonstrations of current behavior; they are not tests asserting that this behavior is desirable.

1. A never-completing road preflight leaves the controller calculating with Finding suitable places along your trip after two simulated minutes. The initial budgeting/storage/provider-capacity waits are outside the 12-second road HTTP and 15-second Places caller timeouts. The screen does not identify which preparation wait is pending.
2. A completed calculation changes the controller to recommendations but awaits recommendation-draft saving before notifying the UI. A blocked save can leave listeners displaying the previous calculation spinner after two simulated minutes. The discovery error path similarly awaits saving before its final notification, potentially delaying display of a real error.

Source locations at investigation time: `recommendation_preparation.dart` initial progress/preflight around lines 277–301, failure/save ordering around lines 434–437, and `planning_controller.dart` completed-result/save/notification ordering around lines 1105–1127. Draft writes are serial Drift operations; accounting reads/writes and native identity checks are separate asynchronous boundaries.

The probes used mock interpretation/roads/storage and no Gemini or Google requests. Log: ignored `.tools/standalone-stall-probes.log`, two passed. No new full-suite or APK-build claim is made because application source was not changed.

## Conclusion and remaining evidence

The app is not designed to require the computer, and the inspected implementation does not contain such a server dependency. Current debugger state and observed internet access do not explain the original disconnected freeze. The two reproduced gaps explain how the UI can remain on a spinner without revealing the stalled boundary, but do not prove which boundary stalled on the owner's phone or why reconnection correlated with recovery.

A focused repair should bound preparation/storage/native-identity waits, expose safe operation names and elapsed time locally, and notify completed/error presentation independently of pending draft persistence while keeping save failures explicit. Preserve coalescing, accounting before dispatch, late-response guards, all selected places and the prohibition on automatic paid retries. Do not assume a timeout cancels underlying work or makes a save successful.

Standalone reproduction must capture the last operation before the wait while the phone is unplugged, with a fresh app-icon launch and working internet. A disconnected pass and a connected pass are separate verification cases. Do not change Cloud quotas, loosen keys, switch providers, erase the phone, or use the personal-phone test harness to diagnose this spinner. Debug and release credential policies remain unchanged; changing build mode alone is not a verified fix.

No personal data, settings, credentials, Cloud configuration or application code was changed. Temporary local VM forwarding was removed after each query; the ignored VM connection URI file was removed after inspection. Findings are recorded as investigation, not a completed bug fix.
