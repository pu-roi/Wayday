# Coordinated release repair — 2026-11-03

## Reproduced causes

Downloaded dev-102701: package dev.wayday.wayday, code 102701, 138111600 bytes, SHA-256 cf63789bfc1785e14b2d9742ff0d4e2651b17cda6df8e54b10ed171793e37abe, source 34965ebd1bf9da737f6d4f1007d48deee010f051. New branding/navigation remained local; the signed Wayday Test 100005 included those local changes.

Production interpretation HTTP 422 at 11:44–11:45 Manila matched the screenshot. Offline old-validator reproduction accepted d66-v1 and rejected errand-v2 before dispatch; current validation accepted both. Production image labels identified ba18b1f80094f9f36bc5c0c63465613c6d96c8ae. Health checked configuration only; qualification hashed only the legacy contract. Main lacked protection; PR 14 merged before checks finished. Its NDK ZIP installation subsequently failed while the main run passed.

Pages run 41516850482 succeeded. Local resolution returned only unreachable 185.199.111.153. TLS-preserving resolution to .108.153, .109.153 and .110.153 returned HTTP 200 and the correct script referencing dev-102701. Google/Cloudflare DoH returned all four addresses. No hosts override existed; the responsible network operator remains unconfirmed.

## Urgent production repair

Owner-approved removal of the public-cloud reviewer retained main-only branch policy. Workflow 41577924437 deployed current-main wayday-gateway-00008-jrn, but traffic remained pinned to 00005-swj. Source label, runtime, request settings, exact app allowlist, secret references and ledger document were verified against old production before explicit 100% promotion. Navigation-test remained on wayday-gateway-navuncap-6571a139. Health returned 200. No provider request, ledger reset, credential restriction change or phone operation occurred.

## Verification

Red runs reproduced absent health contract metadata, undifferentiated gateway rejection, stale qualification acceptance and missing client daily opt-out. Focused green runs passed. Additional source/delivery evidence follows when verified; fixtures and builds never establish physical upgrade or live-provider readiness.


## Combined release checkout verification

After the owner reported D78 complete, its source and evidence were integrated into the isolated codex/coordinated-releases checkout. The final combined Flutter run passed 678 tests with one existing skip; analysis was clean. The API/release suite passed 127 tests with seven existing foundation skips and the existing Starlette/httpx deprecation warning. The distribution-only set passed 43 checks. The actual public compilation profile passed its dedicated Flutter check with test identity disabled, shared navigation enabled and daily client ceilings disabled. A controlled restoration of the old test-identity gate made that check fail; the original fixed bytes were restored and the check passed. No provider calls were made.

The website's three unit checks, production build and fourteen Playwright checks passed, including narrow/enlarged layouts, reduced motion, direct hashes and history. The checked website source/assets match the integrated release scope. D78 separately records its actual native UI/debug-build evidence. Hosted release/native checks and signed candidate identity are recorded only after they finish.

The owner initially asked to wait for D78; no push or merge occurred during that pause. Original workspace changes and unrelated tooling remain intact. The release uses an isolated checkout and focused commits. D77 owns coordinated delivery; D78 owns the completed UI cleanup.

## Repository configuration and remaining qualification

Main now requires passing website, api, mobile, native and release-contract checks from the GitHub Actions app, an up-to-date PR, conversation resolution, and no administrator bypass, force push or deletion. The public-cloud reviewer pause was removed under explicit owner direction while preserving main-only environment policy. Existing test Firebase identity and navigation-test URL were added as non-secret release variables; private secrets, signing identity and provider restrictions were not changed.

Current public-release-qualification.json intentionally retains its previous physical evidence. It lacks the new shared release profile and both channel configuration fingerprints, so public publication must stop until owner-driven upgrade/Gemini/navigation checks are recorded. Signed verified candidates are retained for that review; builds and fixtures are not substitutes. After compatibility repair, an existing failed interpretation still requires explicit Retry Gemini; no journal was erased and no automatic provider retry was introduced.

Chrome automation could not establish the active URL confidently enough to enforce its access policy and stopped. No DNS setting was changed. Manual Chrome Secure DNS recovery and ordinary-hostname verification remain separate from successful Pages deployment. A direct GitHub Releases fallback is documented. No personal-phone installation/reset, new funds, billing activation, database migration or live paid provider request occurred in these checks.


Final review added two failure-heading regressions: gateway contract failures identify the Wayday service, and historical unclassified request rejection uses neutral wording. Both failed before the heading fix, then passed with the existing six layout/keyboard recovery checks (eight total). No automatic retry is triggered. Main delivery stays serialized; obsolete branch/PR verification runs may cancel when a new commit supersedes them.
