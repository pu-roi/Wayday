# Recurring, Settings, and credits cleanup — D78

Date: 2026-11-03, Asia/Manila.

## Owner direction and implementation

The owner requested consistent hierarchy, typography, alignment, and spacing on Recurring and Settings, removal of the nonworking offline Pasig/Ortigas preview, and readable map credits. During planning, the owner selected separate Errands and Trips tabs, Errands as the initial tab, complete retirement of the preview and leftover code, and expandable full license notices. This is a refinement of the existing Canvas/Cornflower/Figtree interface.

Recurring now separates recurring lists from saved trips. Its selected inner tab, independent scroll positions, and disclosures survive tab changes during the running session. Hidden content is excluded from focus and semantics. Trips loads saved records only when first opened, retains explicit failure/retry behavior, and preserves reuse and confirmed deletion. Errands retains creation, focused editing, independent Add to Today copies, and existing deletion/Undo behavior. Empty states use matching title/body roles without repeated introductory descriptions. Save confirmations point to Recurring → Trips.

Settings uses the existing large page title and Profile-style outlined placeholder with the exact text “Settings are not available yet.” Branding and the concurrent D77 build-identity display remain intact. About text distinguishes local storage and online services without claiming that already implemented planning/saved trips are future features.

The preview's Dart renderer/native wrapper, package loader/providers, asset registrations/placeholders, package-generation code/style/notices, and preview-only tests were removed. The mixed legacy test's online-picker failure, cancellation, and manual-label saving scenario was retained as `online_picker_recovery_test.dart`. Shared Android map capability detection moved to `map_platform.dart`. Existing online maps, alternative navigation, MapLibre patch, and OpenGL configuration were preserved. The protected native harness defaults to the online-pin fixture and retains its personal-package guard and no-uninstall behavior. Historical evidence and geographic source caches were not removed.

## Credits source investigation

The previous page concatenated provider names and exposed URLs, rendered the NSI asset's `## BSD 3-Clause` heading literally, displayed decorative font-license rules, and retained source line wraps instead of readable paragraphs. No character-encoding corruption was found in the inspected bundled notice sources.

The page now groups Online maps, Place search, Supporting datasets, and Fonts with shared 16-unit section and 14-unit body/link roles. Provider credits remain visible and labelled links use the existing URL launcher. Complete selectable NSI and Figtree notices expand inline. Display-only normalization removes heading markers and decorative rules and joins wrapped prose; copyright, numbered clauses, disclaimers, punctuation, and substantive words are retained. The upstream notice assets were not changed. Notice loads survive rebuilds/scrolling and failures require explicit retry. Enlarged-text page titles wrap.

## Verification

- The initial Recurring/Settings regression checks failed on the missing tabs and placeholder before implementation, then passed after the change.
- The full Flutter suite passed with 677 tests and one existing skip. No new skips or suppressions were introduced. Retired preview/package tests were removed because their functionality was explicitly removed; online-picker recovery coverage was preserved.
- Focused tests cover empty/populated tabs, independent Today copies, retained scroll/disclosures, trip reuse entry, cancelled/confirmed deletion, lazy loading, explicit retry, page-title/placeholder consistency, complete notice wording, asset failure/retry, disclosure reuse, and source-link success/failure.
- Host-rendered captures cover 320 × 740, 390 × 844, 1024 × 900, 390 × 844 at 2× text, and 844 × 390 landscape. The final visual pass verifies complete license content rather than a loading snapshot, and fixes enlarged-text credits-title truncation.
- `flutter analyze --no-pub` passed with no issues.
- The guarded `test-map.ps1` runner passed `integration_test/ui_cleanup_test.dart` on the disposable API 37 x86_64 `Wayday_Clarification_Test` emulator. It exercised the real shell, retained inner-tab selection, Settings placeholder, nested credits navigation, and complete expanded notice. Five Flutter-surface captures were saved and inspected. The fixture uses memory repositories and disables online-map rendering; it performs no provider requests.
- An ordinary ARM64 debug APK build passed. The final source rebuild passed in 134.7 seconds. ZIP inspection found no retired preview assets; bundled branding and both notice assets match their source bytes.

Ignored local verification artifacts are under `.tools/ui-cleanup-*.log` and `.impeccable/review/ui-cleanup/`. Native captures are `native-errands.png`, `native-trips.png`, `native-settings.png`, `native-credits.png`, and `native-license.png`; host captures use the viewport name as their prefix.

## Final build artifact

The ordinary debug build targeted Android ARM64 and was copied to the ignored `.tools/ui-cleanup-artifacts/wayday-ui-cleanup-debug-arm64.apk`. Its size is 231906971 bytes and SHA-256 is `086af5a1896ecb2833f0883a1a9ae99e676e2588dd6e4e895dec68ad6a03dae3`. Native plugin libraries in the ZIP include arm64-v8a, armeabi-v7a, and x86_64; this was not a release-signing or distribution qualification. `.tools/ui-cleanup-artifacts/artifact.json` records the asset inspection and artifact metadata. This APK was not installed on the personal phone.

The final full-suite rerun initially exposed capture-fixture timing when capture mode was off. The layout fixture now reads the actual bundled notice files through an injected synchronous asset bundle; it retains the complete-content assertion. Production asynchronous loading/error/retry checks remain separate and unchanged. No test was skipped or weakened to fix that fixture.

A later full-suite run also reproduced an existing timing-sensitive reverse-geocoding fixture: its fake adapter returned the same completed old-address future to a queued request for a different pin. The test now holds a separate completer for the old request and clears the fake's shared pending response before completing it, allowing the newer request to receive its own response. The assertions rejecting Old road and preserving the newer coordinates remain unchanged. The location-file and layout checks passed together after this fixture-only correction. The final full suite then passed 678 tests with one existing skip, and final analysis reported no issues. Production location behavior was not changed. The preceding failure log is retained locally as `.tools/ui-cleanup-flutter-tests-before-fixture-fix.log`.

## Boundaries and limitations

The native fixture verifies Flutter rendering and interaction on an emulator, not live maps, provider coverage, physical-phone performance, or TalkBack. The first native Settings surface capture preceded logo decoding; host captures verify the unchanged bundled branding. After the completed fixture, the emulator home screen showed a System UI not-responding dialog; this was separate from the passing app test. The task-owned emulator was shut down without a wipe or snapshot save.

No personal-phone installation/reset, paid request, deployment, publication, schema migration, credential change, or allowance reset was performed by this cleanup. Concurrent release/version work was preserved. D78 was chosen because D77 is owned by that separate coordinated-release change.
