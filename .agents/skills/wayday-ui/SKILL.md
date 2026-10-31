---
name: wayday-ui
description: Design, refine, or review Wayday screens, interactions, visual components, and accessibility in Flutter or the HTML prototype. Use for UI/UX work; mobile state and platform behavior belong to wayday-mobile.
---

# Wayday UI

Read the root `AGENTS.md` for the current phase and authorized scope. A design request does not by itself authorize scaffolding the mobile application.

## Establish the reference

Read [Product requirements](../../../README.md#product-requirements) for scope and the root [Design system](../../../DESIGN.md) for the current theme, shared components, and interaction rules. Follow the owner's latest task instructions to distinguish requested work from later product goals. For prototype-informed work, inspect [V2 notes](../../../docs/Asikaso-Prototype/V2-NOTES.md), relevant [screenshots](../../../docs/Asikaso-Prototype/docs/screenshots/v2), and the [historical design](../../../docs/Asikaso-Prototype/DESIGN.md). Current requirements and design take precedence over those references. Follow the nested prototype instructions before editing its files.

Treat historical references as provisional. Identify which interaction or visual problem the requested change solves before copying an old screen. Preserve the historical baseline unless its modification is requested.

## Shape the experience

- Keep From/Errands/To as the Today composition, not a mandatory layout for every screen. The map-plus-timeline result remains planned. Prefer compact shared numbered errands and focused property editing over nested long forms.
- Keep natural-language input editable and expose uncertain place/time suggestions without claiming AI understanding. Preserve confirmed fields when the note title changes.
- Use the implemented light Canvas/Cornflower theme and semantic colors from the root Design system and Flutter theme. Reuse shared controls and patterns; do not add appearance controls or a separate color system for errand categories. Map styles can vary independently of the app theme.
- Follow the planned selection patterns when that implementation is authorized: visible short choices, predictable selection sheets for longer choices, and numeric monthly-day entry. Preserve drafts, selected values, keyboard behavior, and accessibility; do not treat planned replacements as already implemented.
- Label arrival deadlines and completion deadlines distinctly. Separate required errands, optional omissions, unknown hours, stale estimates, and unavailable routing without exposing solver jargon.
- Keep map attribution and essential controls visible when sheets, keyboards, or system insets appear. Include a readable stop list when a map or downloaded coverage is unavailable.
- Retain the five current transportation choices from the product document. Do not label a sedan/truck route as clearance-verified before the underlying capability is validated.
- Make text scaling, long Filipino/Taglish labels, touch targets, semantic labels, focus, contrast, and reduced motion part of the design. Do not communicate feasibility or selection through color alone.

## Review the affected flow

For the current focused planning repair, preserve the review layout, labels, Edit errand and Choose actual location. Required unanswered questions use a question bubble, #7A4500 attention and Needs your answer; optional questions keep Optional and normal colors. A stored, resolved answer uses a normal-color check-circle. Clearing an applied answer restores its unanswered state; typing or closing alone cannot mark it resolved. Let Wayday recommend applies a direct choice without generated answer text. Keep the Trip details route icon in normal blue. The manual picker is restored to MapLibre/center-pin interaction; custom SDK/Routes content remains Google-backed with separate provenance.

Check the primary action, edit/save/cancel behavior, empty and populated lists, long content, keyboard visibility, loading/failure states, and offline/stale-plan messages relevant to the change. Keep template drafts independent from today's copies. Load `wayday-mobile` when the change affects state, persistence, or platform behavior, and `wayday-planning` when it changes timing or omission semantics.

When runnable UI exists and the task authorizes verification, inspect representative screens at mobile sizes and larger text settings. Record what was actually rendered or tested. During foundation-only work, deliver the design reasoning or documentation change without inventing screenshots or claiming device validation.


D60 removes the separate Recheck location needs with Gemini action and assessment retry/credit controls. The existing question/answer sheet owns missing meaning and correction. Recommendation failures use a concise recovery view with retained choices, unfinished-route wording, appropriate retry behavior and secondary manual search. Do not label a provider rejection as an empty search or replace the automatic experience with a mandatory manual-selection wizard. Keep long actions below row text when enlarged text would consume the row width.

D61 combines recommendations, schedule and route preview in Your plan. Keep visible Change on every row even during failure. Alternatives use a supporting sheet; several choices require one Update plan before Start trip. Start trip and Save for reuse are separate, and saved trips live under Recurring. Keep arrival versus visit/departure distinct, disclose extra detail and let the inline map yield page scrolling. Use the current theme, accessible action targets and enlarged-text layouts; no extra schedule-acceptance wizard.
