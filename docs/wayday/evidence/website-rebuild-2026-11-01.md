# Wayday website rebuild — 2026-11-01

## Authorization and implementation

The owner rejected the small-movement website, supplied Pyzhevsky and Spyker as references, delegated the visual choices and approved the fresh rebuild plan. Both references were opened and scrolled in the actual browser. Spyker reported some media playback failures, so its continuous video behavior was not fully qualified.

The new site follows the approved errands-coming-together concept. It replaces the old markup composition, styles and motion system with a dominant phone/notes opening, dark alternating feature chapters, layered planning stages, rotating reuse motif and complete practical information. The supplied logo and Figtree font were retained without alteration. Product visuals are explicitly illustrative; no actual screenshots were approved for public use.

The opening was presented in a working browser preview at desktop and 638 px before lower chapter animations were added. It uses a reversible 18-degree tilt to straight, scale from 0.8 to 1.15, substantial horizontal/vertical note travel and an emerging closing statement. Lower chapters use distinct broad reveals, lateral entrances, step stacking and a scroll-linked reuse rotation. Lenis and GSAP share one ticker; media/lifecycle cleanup and runtime reduced-motion changes remain supported.

The phone's compact end position was adjusted to avoid its caption. Incoming reuse notes are clipped within their illustration rather than creating page overflow. Responsive rules are separate from base styles. Footer links have 44 px minimum target heights, and the no-JavaScript fallback exposes mobile navigation. Short viewports use ordinary opening flow instead of sticky choreography.

## Verification

- Production TypeScript/Vite build passed under `/Wayday/`.
- Three release validation unit tests passed.
- Fourteen Chromium browser tests passed: readable production/assets and navigation at 320, 360, 390, 638, 768, 1024 and 1440 px; direct hashes, browser history, keyboard menu/Escape/focus, Back to Top; substantial opening scale/rotation/note displacement and reversal at 638/1440 px; broad lower reveal/reuse rotation; runtime reduced motion; 844×390 landscape; no-JavaScript navigation; and qualified/incomplete release metadata.
- The lower-chapter/no-JavaScript tests initially failed before those behaviors were implemented. A later run identified narrow-screen overflow from incoming reuse notes; the implementation was corrected and the complete suite passed without skipped or weakened checks.
- Strengthening anchor checks to measure the final section position exposed an inherited offset error: Lenis 1.3.27 applied CSS scroll padding/margins in addition to the helper's manual header offset. The helper now uses a numeric destination, and native CSS anchors use the actual header plus 20 px once. The strengthened suite verifies final section arrival and return to scroll position zero across all seven widths.
- axe-core 4.11.0 found zero violations for the WCAG A/AA tag set through WCAG 2.2 at 1440×900, 390×844 and 638×900 with reduced motion. The test asset came from the npm registry and its SHA-512 integrity was verified. This is automated evidence, not a claim of complete manual accessibility certification.
- npm audit found zero vulnerabilities. The static design detector returned no findings. The pre-existing file-specific HTML typography ignore remains; actual CSS hierarchy and rendered typography were independently reviewed.
- Desktop, phone and 638 px full-page reduced-motion screenshots were inspected. Motion-on browser inspection covered the opening, note reveal and step stacking. An ignored local recording shows forward/reverse opening motion and a lower note transition at 638 px. Stills and numeric transforms are not presented as measured animation performance.
- Independent visual review first requested a documentation correction, which was scored resolved. After the anchor correction, refreshed desktop/phone/638 px captures received a full ship disposition with no material fixes. This is visual/navigation review evidence, not a physical-device performance claim.
- Byte comparisons against the local pre-rebuild archive confirm `src/release.ts`, default release data, Vite subpath configuration, original logo and font are unchanged.

Local screenshots and recording are ignored review artifacts in `.impeccable/review/`; generated website output remains ignored. The original website source is recoverable from the ignored `.tools/website-before-reference-rebuild.zip` archive.

## Boundaries and remaining qualification

The default release state remains unqualified and the website says Download coming soon. No public deployment, billing change, account creation or app-provider call occurred. No Android, gateway or CI source was changed by this rebuild. Existing unrelated working-tree changes were preserved.

Physical-phone performance, touch interaction on a physical device and a manual screen-reader audit remain unverified. Public release qualification and Cloud deployment remain separately gated by D67. Browser layout/automation checks do not establish app-provider or physical-phone readiness.
