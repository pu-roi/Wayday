---
name: wayday-ui
description: Design, refine, or review Wayday screens, interactions, visual components, and accessibility in Flutter or the HTML prototype. Use for UI/UX work; mobile state and platform behavior belong to wayday-mobile.
---

# Wayday UI

Read the root `AGENTS.md` for the current phase and authorized scope. A design request does not by itself authorize scaffolding the mobile application.

## Establish the reference

Read [Product requirements](../../../docs/wayday/README.md#product-requirements) for scope and the root [Design system](../../../DESIGN.md) for the current theme, shared components, and interaction rules. [Planning](../../../docs/wayday/PLANNING.md#task-specifications) distinguishes future selection-control and map work from implemented UI. For prototype-informed work, inspect [V2 notes](../../../docs/Asikaso-Prototype/V2-NOTES.md), relevant [screenshots](../../../docs/Asikaso-Prototype/docs/screenshots/v2), and the [historical design](../../../docs/Asikaso-Prototype/DESIGN.md). Current requirements and design take precedence over those references. Follow the nested prototype instructions before editing its files.

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

Check the primary action, edit/save/cancel behavior, empty and populated lists, long content, keyboard visibility, loading/failure states, and offline/stale-plan messages relevant to the change. Keep template drafts independent from today's copies. Load `wayday-mobile` when the change affects state, persistence, or platform behavior, and `wayday-planning` when it changes timing or omission semantics.

When runnable UI exists and the task authorizes verification, inspect representative screens at mobile sizes and larger text settings. Record what was actually rendered or tested. During foundation-only work, deliver the design reasoning or documentation change without inventing screenshots or claiming device validation.
