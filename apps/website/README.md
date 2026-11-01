# Wayday marketing website

Static single-page website for the Android app. Source is kept in this repository; GitHub Pages serves the built files and GitHub Releases hosts qualified APKs. The page is informational, not a browser version of Wayday.

## Develop and verify

Use Node.js 24 or newer:

```sh
npm ci
npm run dev
npm test
npm run build
npx playwright install chromium
npm run test:browser
npm audit --audit-level=high
```

The default URL includes `/Wayday/`. Set `WAYDAY_BASE_PATH=/` for a different hosting root. Production output is `dist/`, which is generated and ignored. A local `vite preview` is for verification, not production hosting.

## Content and release information

The owner's supplied website prompt governs product content and distribution requirements. The subsequent reference-led redesign request below supersedes its restrained-motion direction. The page uses the original supplied route-W PNG, copied without visual alteration, and the app's Figtree font with its SIL OFL notice. The HTML phone is explicitly labelled illustrative and is not an actual screenshot, provider result, route or live demo. No approved app screenshots were supplied for public marketing use.

`src/release.ts` is the typed validation boundary. `src/release-data.json` defaults to `{"qualified": false}`. CI populates it at build time from a qualified release's `wayday-release.json`; the browser does not call GitHub or app providers. A release needs an explicit qualification flag, version, date, positive size, SHA-256 checksum, compatibility description and approved repository APK/release URLs. Missing or invalid data keeps downloads unavailable.

All essential content and ordinary anchors are present in HTML. JavaScript enhances navigation, motion and release presentation. Lenis and GSAP use one ticker. Reduced motion can change while the page is open. No accounts, analytics, database or online app-provider requests are added to the website.

## Redesign plan — reference-led scroll storytelling

**Status: implemented and browser-verified on 2026-11-01.** After rejecting the small-movement treatment, the owner approved the fresh rebuild below. The page structure, styles and motion system were replaced; original assets, release validation and GitHub Pages configuration were retained. The opening was presented in a working preview at desktop and 638 px before the lower chapter animations were added. The previous source remains in an ignored local recovery archive. Browser evidence does not establish physical-phone performance. See [verification evidence](../../docs/wayday/evidence/website-rebuild-2026-11-01.md).

### Audience, purpose and direction

The visitor is a prospective Android tester learning what Wayday does and whether they can install it. The primary action is reaching the honest download state. Preserve the full product story, installation guidance, limitations, privacy information and release validation.

Use the theme **errands coming together**: scattered thoughts become an organized day, with the person retaining the final say. Retain the original logo, Figtree, warm off-white, navy and Cornflower blue. Replace the existing composition, spacing, product presentation and motion system rather than adding more effects to the discarded layout. Use large editorial typography, fewer stronger compositions, contrasting light/dark chapters and generous space around a central product visual.

Both references were opened and scrolled in the actual browser:

- [Pyzhevsky](https://pyzhevsky.estate/): the opening split composition expands into a dominant architectural image; sticky layers and successive full-frame scenes carry the story. The narrow preview initially showed its rotate-device message, so desktop inspection was necessary.
- [Spyker](https://spykercars.com/): a full-width product film leads into alternating large detail imagery, staged text and contrasting sections. Some media reported playback failures during inspection, so continuous playback was not fully verified.

Adapt their visual scale, sequencing and relationship to scrolling to Wayday. Do not copy their imagery, branding, wording or exact layouts. The proposed rotations and errand-card choreography below are Wayday-specific design choices, not claims that both references use those exact effects.

### Page and motion sequence

| Area | New composition | Planned behavior |
| --- | --- | --- |
| Navigation and opening | Compact sticky navigation; a large headline, prominent phone illustration and scattered errand notes form one composition. Android/development status and download action remain immediately clear. | A short masked headline entrance and an obvious phone arrival establish motion on load. The phone starts tilted approximately 18 degrees and smaller than its final size. No loading screen or mandatory animation wait. |
| Errands come together | A bounded scroll scene transforms the opening composition into an organized list. Label the phone and example errands illustrative. | As scrolling advances, the phone straightens and grows roughly from 80% to 115%; loose notes travel substantial distances and rotate into an ordered stack. Reverse scrolling reverses the scene. Desktop travel is approximately 180–260 px, adjusted to the available space. |
| Understand and review | A large editable-note illustration sits opposite concise English/Filipino/Taglish interpretation copy. | The note opens through a broad reveal and rotates into position; text lines reveal in a short sequence. It is an illustration, with no generated result or browser interaction implied. |
| Places and your plan | Alternate large visual and text compositions explaining suitable places, estimates, business-hour uncertainty and explicit choices. | Use a different entrance for each major composition: a scale/reveal for the plan illustration, then a lateral entrance for alternatives. Keep the movement large enough to read as a transition rather than background drift. No fabricated businesses, route geometry or travel times. |
| How it works | Four readable stages: add, clarify, review, complete. | Step panels rise into a bounded layered stack with visible tilt-to-straight motion. Each step must remain readable before the next overlaps it. Do not trap wheel/touch input or force snapping. |
| Familiar days | An open composition for recurring lists, reusable trips and saved places. | A large circular reuse-arrow motif turns with scrolling while reusable errand notes slide into place. The official logo stays unchanged. Explain that repeat settings are not automatic scheduling. |
| Requirements, download and FAQ | Clear editorial content, a prominent Android release panel, straightforward installation instructions and native FAQ disclosures. | Heading entrances provide continuity, then content settles. Keep release metadata, links and installation instructions stable while visitors read and act. Coming-soon, qualified and invalid-metadata states retain their existing contract. |
| Privacy and close | Plain privacy information followed by a large closing invitation and Wayday wordmark. | A final broad reveal and restrained depth transition finish the sequence. Keep footer links and Back to Top accessible. |

The implemented opening uses an 18-degree tilt, 80% to 115% scale, 115/105/90 px compact horizontal note travel and 200/230/180 px desktop travel, combined with up to 160 px vertical movement. Strong movement is verified at 638 px and 1440 px. At viewport heights of 650 px or less, the opening uses ordinary flow and its short entrance instead of a sticky scroll scene; lower-page transitions remain available. Reduced motion removes the choreography and stacking. Landscape orientation is never required.

### Implementation order and review points

1. Replace the page structure and styles with the new composition while keeping every required content section and the typed release boundary. Verify the static page, mobile menu, anchors and unavailable-download state before adding motion.
2. Build the opening scene completely using Lenis and a GSAP timeline. Review a real scrolling preview or short recording at desktop and 638 px before extending the visual language across the page. The checkpoint must demonstrate scale, rotation and large travel, not just passing transform assertions or a still screenshot.
3. Complete the feature transitions, four steps, reuse illustration and closing scene. Keep each sequence distinct and make rapid scrolling, reverse scrolling and direct section links work.
4. Finish responsive behavior, reduced motion, keyboard navigation, all release states and production-subpath verification. Update website design documentation and verification evidence to describe the final implementation.

The implementation lives in `index.html`, `src/style.css`, `src/responsive.css`, `src/motion.ts`, navigation/lifecycle portions of `src/main.ts`, and focused browser tests. `src/release.ts`, the build-time metadata contract, GitHub Pages base handling, logo and font match their pre-rebuild source. Android, gateway, Cloud configuration and release publication were outside this redesign.

### Verification and limits

- Inspect actual forward and reverse scroll sequences at 360/390, 638, 768, 1024 and 1440 px, plus a short landscape viewport. Verify readable text, no horizontal overflow or clipped controls, and natural touch scrolling. Mobile behavior must be designed rather than inferred from desktop.
- Record the opening scene and at least one lower-page transition. Browser checks should verify substantial movement, changing scale/rotation, reversal, successful anchor arrival and a usable static fallback. Numeric transforms alone do not establish visual quality or smoothness.
- Keep one animation ticker and scoped cleanup on resizing, reduced-motion changes and page lifecycle events. Avoid heavy full-screen filters, continuous decorative loops and autoplay media dependencies. Profile the resulting page before making performance claims; desktop browser checks do not establish low-end Android performance.
- With reduced motion, remove spatial choreography and sticky stacking, present all content in ordinary flow, and move anchors immediately. With JavaScript unavailable, essential content and normal links remain usable.
- Run the existing release unit tests, production build and browser suite; preserve keyboard focus, menu Escape, header offsets, hashes/history, Back to Top, real assets and qualified/missing download metadata checks.
- Keep public APK downloads unavailable until release qualification passes. The redesign does not authorize deployment, account creation, billing or live app-provider calls.

The `WAYDAY_PAGES_ENABLED` repository variable controls deployment. APK publication has a separate qualification gate; enabling the website alone does not enable app downloads. See [distribution setup](../../docs/wayday/DISTRIBUTION.md).

## Third-party assets

- The supplied Wayday logo remains the owner's brand asset; this work assigns it no new licence.
- Figtree: SIL OFL 1.1, included at `public/assets/OFL.txt`.
- Lenis: MIT licence, included at `public/assets/LENIS-LICENSE.txt`.
- GSAP/ScrollTrigger: [GSAP standard licence](https://gsap.com/standard-license/); the package is not represented as MIT-licensed.

No open-source licence is assigned to the project's original work.
