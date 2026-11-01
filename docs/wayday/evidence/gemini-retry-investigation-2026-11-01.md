# Gemini retry rejection investigation — 2026-11-01

The owner reported that Plan my day showed Understanding needs a retry, and confirmed that Retry Gemini briefly displayed loading before returning to an error. This investigation includes a focused runtime repair. It does not authorize personal-phone installation or a new presentation allowance.

## Findings

Read-only inspection of the connected personal application's interpretation journal found one failed entry labelled unavailable and three earlier completed entries. The old native bridge collapsed HTTP failures other than access/quota into unavailable, discarded the HTTP status, and omitted the saved failure category from status lookup. Flutter then replaced the saved cause with a generic previous-failure explanation. The existing button/controller path correctly passed explicit retry through to the interpreter; mocked entry checks passed before changes.

The owner separately approved one nonpersonal diagnostic request and then one verification request. Both used the configured model, Gemini 3.1 Flash-Lite, existing credential and bounded generateContent endpoint, without tools, automatic retries, phone installation, journal seeding or personal task text. No further live requests were sent.

| Controlled request | Result |
| --- | --- |
| Original D66 format, three public sample errands | HTTP 400, INVALID_ARGUMENT, Request contains an invalid argument, 0.94 seconds |
| Reduced venue-type schema, same sample/model/credential | HTTP 200, STOP, 2.45 seconds; 1,176 input and 654 output tokens |

The original output schema repeated 230 enum values in total, including the venue-type allowlist in four nested array positions. The corrected schema retains 38 enum values and sends the venue-type allowlist once in the instruction. Array limits, supported types, preferred/acceptable consistency and string limits remain locally validated. Google's [structured-output documentation](https://ai.google.dev/gemini-api/docs/structured-output) identifies nested constraints and large enums as possible HTTP 400 causes. The comparison supports the request-format repair; Google's generic error did not identify a particular bad field or a documented enum threshold. The previous personal-phone HTTP status cannot be recovered from its old unavailable entry.

The HTTP 200 response exposed a second issue: all three optional search hints listed preferred venue types separately from acceptable fallback types, violating the existing subset rule. Strict hint validation correctly rejected them, but previously discarded the whole interpretation. Invalid optional hints now become absent, retaining the separately validated query/category/items and existing bounded search behavior. No invalid hint is used, expanded, or repaired into invented metadata. Task IDs, location questions/intent, source constraints, timing and dependencies retain their existing validation. Live model interpretation quality remains unqualified.

## Implementation

- Preserve the exact original D66 interpretation and clarification builders as historical lookup paths. Matching completed answers still reuse without generation; pending, failed, corrupt and recovery outcomes still require explicit retry after the transport change. A local comparison verified the frozen interpretation body against the request exported before editing.
- Use a smaller provider schema for new interpretation and clarification requests. Do not change the model, endpoint, credential, request/output bounds, no-tools boundary or in-flight coalescing.
- Keep strict PlaceSearchIntent validation. At the optional-hint boundary, omit invalid hints while validating the remaining interpretation/clarification normally. Regression cases cover inconsistent types, unsupported types, excessive variants, malformed hints and invalid core fields.
- Persist only stable HTTP status codes in the existing journal failure field, expose saved failure codes, and map them to bounded local explanations. No provider error text, credential, user input or full URL is logged or shown. Access, quota, request rejection, missing model and other provider responses remain distinct. Old generic records remain readable.

## Verification and limits

Focused mocked checks and offline replay of the approved public response pass. Red/green regressions demonstrated both the lost error explanation and whole-answer rejection caused by optional hints. Ordinary tests make no provider requests. The live verification response was replayed through the actual Gemini envelope and Interpretation parsers without another network call.

Final Flutter analysis passed with no issues. The final full suite completed with 569 passes, one intentional skip and eight failures. The eight failure identities match the recorded D66 baseline exactly: one online-picker case, three regional-map cases, two saved-place/Profile cases and two Today manual-location cases. Focused checks and the recorded-response replay passed. No existing test was skipped, removed or weakened. The ARM64 debug APK build passed in 276.3 seconds, including native bridge compilation, at apps/mobile/build/app/outputs/flutter-apk/app-debug.apk. A separate read-only model review found no actionable correctness/privacy regressions; it did not independently rerun tests or perform native/live qualification.

No native harness was run on the personal phone. Its installed application, database, credentials and journals remain unchanged. A rebuilt APK is not an installed update or physical-phone verification. Failed historical requests still need the owner's explicit Retry Gemini action after updating; ordinary reopening must not spend to replace them.

Private local artifacts remain ignored under .tools/gemini-investigation/: request exports, once-only dispatch markers, sanitized summaries, the nonpersonal response and offline replay fixture. These contain no credential. HTTP 400 is not assumed to be free, and token reporting is not a measured billing reconciliation. This work makes no Google Places, Routes or Navigation requests and changes no accounting allocation, quota, billing or key restriction.
