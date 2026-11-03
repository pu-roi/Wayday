---
name: Wayday mobile
description: A calm Android errand interface with one light Cornflower theme, compact lists, and focused editing.
colors:
  canvas: "#FBFBF8"
  mist: "#DBE3E9"
  cornflower: "#6AA6DA"
  action-ink: "#102D44"
  white: "#FFFFFF"
  link-blue: "#285C86"
  selected-blue: "#E5F0F9"
  text-light: "#1D2C38"
  text-muted-light: "#5A6C7B"
  outline-light: "#DEE7ED"
  field-light: "#F0F5F8"
  website-canvas: "#fbfbf8"
  website-ink: "#102d44"
  website-blue: "#285c86"
  website-muted: "#526779"
  website-line: "#d4dfe6"
  website-pale: "#e5f0f9"
  website-cornflower: "#6aa6da"
  website-white: "#ffffff"
  website-dark-support: "#bfd0dd"
  website-hero-surface: "#edf3f5"
typography:
  headline: { fontFamily: Figtree, fontSize: "32px", fontWeight: 600, lineHeight: 1.25, letterSpacing: "-1px" }
  title: { fontFamily: Figtree, fontSize: "21px", fontWeight: 600, lineHeight: 1.27, letterSpacing: "-0.35px" }
  section: { fontFamily: Figtree, fontSize: "16px", fontWeight: 600, lineHeight: 1.5, letterSpacing: "0.15px" }
  body-large: { fontFamily: Figtree, fontSize: "16px", fontWeight: 400, lineHeight: 1.5, letterSpacing: "0.5px" }
  body: { fontFamily: Figtree, fontSize: "14px", fontWeight: 400, lineHeight: 1.4, letterSpacing: "0.25px" }
  row-title: { fontFamily: Figtree, fontSize: "14px", fontWeight: 600, lineHeight: 1.4, letterSpacing: "0.25px" }
  detail: { fontFamily: Figtree, fontSize: "12px", fontWeight: 400, lineHeight: 1.33, letterSpacing: "0.4px" }
  label: { fontFamily: Figtree, fontSize: "14px", fontWeight: 600, lineHeight: 1.43, letterSpacing: "0.1px" }
  button: { fontFamily: Figtree, fontSize: "16px", fontWeight: 600 }
  website-display: { fontFamily: "Figtree, Arial, sans-serif", fontSize: "clamp(60px, 6.6vw, 96px)", fontWeight: 650, lineHeight: 0.99, letterSpacing: "-0.04em" }
  website-headline: { fontFamily: "Figtree, Arial, sans-serif", fontSize: "clamp(42px, 5vw, 72px)", fontWeight: 550, lineHeight: 1.06, letterSpacing: "-0.035em" }
  website-title: { fontFamily: "Figtree, Arial, sans-serif", fontSize: "clamp(34px, 3.7vw, 52px)", fontWeight: 550, lineHeight: 1.08, letterSpacing: "-0.035em" }
  website-body: { fontFamily: "Figtree, Arial, sans-serif", fontSize: "16px", fontWeight: 400, lineHeight: 1.65 }
  website-button: { fontFamily: "Figtree, Arial, sans-serif", fontSize: "16px", fontWeight: 600 }
  website-nav: { fontFamily: "Figtree, Arial, sans-serif", fontSize: "14px", fontWeight: 550 }
rounded:
  field: "14px"
  button: "18px"
  card: "24px"
  sheet: "28px"
  website-panel: "12px"
  website-step: "16px"
  website-phone: "40px"
  website-menu: "10px"
  website-circle: "50%"
spacing:
  tight: "2px"
  related: "4px"
  compact: "6px"
  small: "8px"
  medium: "12px"
  row-gap: "14px"
  regular: "16px"
  page: "20px"
  section: "24px"
  section-large: "28px"
  spacious: "32px"
  website-small: "12px"
  website-related: "16px"
  website-regular: "24px"
  website-stack-gap: "28px"
  website-composition-gap: "40px"
  website-panel-inset: "64px"
  website-chapter-compact: "90px"
  website-chapter-wide: "120px"
components:
  button-primary: { backgroundColor: "{colors.cornflower}", textColor: "{colors.action-ink}", typography: "{typography.button}", rounded: "{rounded.button}", height: "56px" }
  button-text: { textColor: "{colors.link-blue}", typography: "{typography.label}", height: "48px" }
  input: { backgroundColor: "{colors.field-light}", textColor: "{colors.text-light}", rounded: "{rounded.field}", padding: "16px" }
  section-surface: { backgroundColor: "{colors.white}", textColor: "{colors.text-light}", rounded: "{rounded.card}" }
  errand-row: { textColor: "{colors.text-light}", typography: "{typography.row-title}", padding: "8px 20px" }
  number-badge: { backgroundColor: "{colors.selected-blue}", textColor: "{colors.link-blue}", size: "24px" }
  trip-settings: { textColor: "{colors.link-blue}", padding: "14px" }
  navigation: { backgroundColor: "{colors.canvas}", height: "76px" }
  time-field: { backgroundColor: "{colors.field-light}", textColor: "{colors.text-light}", typography: "{typography.headline}", rounded: "{rounded.field}", padding: "16px" }
  feedback: { backgroundColor: "{colors.selected-blue}", textColor: "{colors.link-blue}", typography: "{typography.body}", rounded: "{rounded.button}" }
  website-button-primary: { backgroundColor: "{colors.website-ink}", textColor: "{colors.website-white}", typography: "{typography.website-button}", rounded: "{rounded.website-panel}", padding: "16px 24px" }
  website-button-small: { backgroundColor: "{colors.website-ink}", textColor: "{colors.website-white}", rounded: "{rounded.website-panel}", padding: "10px 18px" }
  website-text-link: { textColor: "{colors.website-blue}" }
  website-errand-slip: { backgroundColor: "{colors.website-white}", textColor: "{colors.website-ink}", rounded: "{rounded.website-panel}", padding: "17px 20px", width: "250px" }
  website-step: { backgroundColor: "{colors.website-canvas}", textColor: "{colors.website-ink}", rounded: "{rounded.website-step}", padding: "64px" }
  website-phone: { backgroundColor: "{colors.website-canvas}", textColor: "{colors.website-ink}", rounded: "{rounded.website-phone}" }
  website-menu: { backgroundColor: "{colors.website-canvas}", textColor: "{colors.website-ink}", rounded: "{rounded.website-menu}", padding: "10px 14px" }
  website-faq: { textColor: "{colors.website-ink}" }
---

# Design System: Wayday mobile

## Recurring, Settings, and credits — D78

Recurring keeps the 64-unit toolbar and large page heading, followed by Material Errands and Trips tabs. Errands is initially selected; the selection, independent scrolling, and disclosures persist while the shell remains mounted. Hidden tab content is excluded from focus and semantics. The New recurring list toolbar action belongs only to Errands. Existing lists, independent Add to Today copies, trip reuse, and deletion keep their behavior. Empty states share the 21-unit title role, one 14-unit muted explanation, and aligned 24-unit text insets; no introductory tagline repeats the explanation.

Settings matches Profile's page heading and outlined placeholder: Settings are not available yet. Keep the supplied branding, concise About text, and credits entry. The obsolete offline Pasig/Ortigas preview, package loader, assets, and preparation tools are retired; shared online maps retain their renderer and platform gate.

Credits use 16-unit section headings, 14-unit body/link text, 24-unit section gaps, and labelled provider links with external-link icons. Online maps, Place search, Supporting datasets, and Fonts remain distinct. Complete NSI and Figtree notices expand inline, remain selectable, and preserve upstream wording. Display-only formatting removes Markdown heading markers and decorative rules and joins source line wraps into paragraphs; bundled originals remain unchanged. Asset loads persist across rebuilds and scrolling; failures offer explicit retry.

## Your trip provider options — D71

Retain the current trip layout and controls. Map & navigation is an additional three-dot-menu entry with the existing drag-handle, Figtree heading, content-sized scrolling sheet and selected checkmark treatment. Google/OpenStreetMap helper text explains the map/routing sources and any destination restriction. Supported alternative directions/ETA, voice, compass, follow/Recenter and attribution remain inside its map area. Existing status feedback handles explicit provider recovery; no mockup replaces surrounding components. Preserve D69 Done, Whole trip, Back and Finish, including narrow/enlarged-text behavior.

## Retained tab navigation — D70

Today, Recurring, Profile and Settings retain their loaded page state during the running session. Switching tabs preserves Today's map instance/camera, scroll, expanded sections and unfinished errand text. Leaving dismisses keyboard focus without clearing the draft; returning does not open the keyboard automatically. Re-selecting the current tab does not reset its position. Hidden branches are not interactive or exposed in accessibility traversal, and their Flutter animations are disabled. The bottom bar and rail retain the same labels/appearance and switch without replacing page content. Storage-error banners occupy a stable slot above the retained content. Map attribution and explicit failure/Retry remain unchanged; retention does not imply offline tiles or survival after process death.

## Planning screen hierarchy and completion — D69

Review errands groups the exact past-departure date/time and Change date/Change departure in one left-aligned notice. Use the theme's error foreground, a warning icon and subtle error-container fill. Preserve the separate amber unanswered-question treatment, validation and bounded feedback scrolling.

Your plan keeps compact numbered summaries and visible Change. Business names use the existing 16-unit semibold title role; locality and incoming travel use the 14-unit muted body role. Details expands inline beneath a quiet divider into Place, Visit timing and Business hours. Use 16-unit group headings, 8-unit heading-to-content spacing, and 6-unit gaps between related facts. Keep address, rating, recommendation reason, departure/wait/buffer, calculation age, current hours status, trip-day hours, validated visit compatibility and retrieval attribution available. Weekly hours remains a nested disclosure. Missing/stale/failed data and current versus planned hours retain their existing meanings.

Your trip replaces D64's checkbox/instruction with one current-errand title in the existing 21-unit title role and a check-icon Done button. Current errand/You have arrived uses the 14-unit supporting role. The flat white panel has a quiet top divider, 20-unit horizontal/16-unit vertical padding and no decorative shadow. Done uses the shared Cornflower 56-unit minimum-height geometry beside the title; it stacks full-width when inner width is below 320 units or scaled 14-unit text exceeds 18. Keep content-sized scrolling bounded to 32% of screen height, including short landscape layouts, leaving the map the remaining viewport. Saving… disables repeat taps. Completion persists before revealing another independent errand or advancing a shared stop; error recovery and the outlined Finish trip action are unchanged. Native navigation estimates, directions and attribution remain separate from this Flutter panel.

## Place information and stable map confirmation — D66

Choose a place keeps its content-sized sheet and fixed errand pager. Use actual business name, current-place/locality line, wrapping formatted address, trip-day hours and available travel comparison; suppress equal locality/address lines. Available Google rating/count is secondary text in alternatives and Details, without expanding compact main rows or adding rating cutoffs. Missing addresses/ratings are not invented and displaying rows does not fetch data.

Details and alternatives show a labelled Open now/Closed now indicator when fresh current hours support it; weekly fallback says Usually open/closed now. Pair wording with an icon and existing link/attention colors. Keep current status separate from planned-visit compatibility and future trip-day windows. Closed-at-visit and closes-before-completion warnings require an actually calculated visit. Missing, failed, stale and pin-only hours must not turn into a Closed label. Minute-boundary refresh is local and makes no provider request.

Keep the manual center pin and visible Confirm location action. Ordinary panning must not flash its disabled appearance after a valid candidate exists. Confirmation briefly processes while waiting for final idle coordinates, times out after three seconds, and asks for confirmation again after a superseding selection. Invalid/no selection and conflicting operations retain honest disabled/error states. Zoom readout changes are isolated from the picker layout and throttled; native map identity stays stable. Preserve labels, attribution, saved places, current-location consent, keyboard behavior and provider provenance.

Today's displayed date remains the plan date. Only empty/default forms without a chosen date, draft/editor or accepted trip follow Manila startup/resume/midnight. Clear and Finish restore the current default date. Do not silently move a populated plan or legacy date.

The latest focused review repair preserves existing layout, labels, Edit errand and Choose actual location. Required unanswered questions use a question-bubble icon, Needs your answer and semantic dark amber #7A4500; optional questions retain normal colors and Optional. Stored, resolved answers use a normal-color check-circle. Processing, unresolved results, failed saving and rules awaiting approval must remain distinguishable. Clearing a saved answer withdraws its resolution and restores its unanswered treatment after the user's edit; a nonempty draft does not apply a new answer. Let Wayday recommend saves an explicit choice directly, without inserting a generated sentence. Trip details retains its wording and disclosure behavior with a normal-blue route icon. See [the current planning contract](docs/wayday/PLANNING.md#current-trip-recovery-and-finishing--d65-current-contract). The subsequent D60 repair removes separate location-recheck and assessment recovery controls; users answer the existing question instead. Recommendation recovery retains real choices, identifies an unfinished trip, uses failure-specific actions and keeps manual search secondary. A service rejection must not be described as no matching businesses. Long recovery actions stack beneath text on narrow/enlarged layouts.

## Overview

The current logo is the owner's transparent navy-to-cyan route-W artwork in `wayday-logo-rmbg.png`, supplied on 2026-11-02. Use it without recoloring, distortion or an added white tile in the website header/footer and Flutter branding. Android launcher icons use the existing Canvas background and a padded adaptive foreground; legacy densities and browser icons derive from the same source. Run `./tools/update-branding.ps1` from the repository root to regenerate these assets. The logo does not change the application theme or semantic action colors.

Product context for design tools is maintained in [the README product requirements](README.md#product-requirements), including the product schema marker and platform/stack context. Supply README.md explicitly when a tool needs product context. See [the documentation index](README.md) for the remaining project documents.

**Creative North Star: "A clear day, in order"**

Wayday keeps everyday errands calm and easy to scan. Warm Canvas, white grouped surfaces, Cornflower actions, and compact Figtree text give the list a clear rhythm. This records the implemented Android Flutter shell, Today, and Recurring interface after the owner's approved system change on 2026-10-16: one light theme with no appearance controls.

The reusable character is quiet grouping, compact numbered rows, and details revealed in focused editors. Short list transitions preserve the consecutive-entry flow; optional notes stay inside the editor, and floating feedback clears after ordinary use. The Today-specific From/Errands/To composition remains in [the surface brief](.impeccable/surfaces/mobile-today.md); it is not a required composition for every future screen.

The token source is [the Flutter theme](apps/mobile/lib/app/theme.dart). Reused patterns live in [the shared errand list](apps/mobile/lib/features/errands/presentation/errand_list.dart), [focused editor](apps/mobile/lib/features/errands/presentation/errand_editor.dart), and [section surface](apps/mobile/lib/core/widgets/section_surface.dart). [Product scope](README.md#product-requirements) and [decisions](docs/wayday/DECISIONS.md) retain product authority. [Historical Asikaso design](docs/Asikaso-Prototype/DESIGN.md) remains preserved reference evidence.

**Key Characteristics:**

- One light Canvas/Cornflower theme with readable dark text.
- Compact shared errand rows and simple Anytime-default quick add.
- Quiet outlined groups, focused editors, and familiar Material states.
- Numeric time entry and shared online maps with explicit location confirmation.
- Visible labels, content-driven sizing, and scrollable forms.
- State-preserving disclosure, reduced-motion support, and transient in-app feedback.

## Colors

Warm Canvas and white surfaces carry a restrained blue palette. Frontmatter lists authored, reused colors; unspecified Material roles, including errors and interaction overlays, remain generated from the Cornflower seed.

### Primary

- **Cornflower:** primary filled actions and the Material seed, paired with dark `action-ink` content.
- **Readable blue:** `link-blue` supplies text actions, meaningful blue icons, focused field strokes and floating labels, selected container content, and snackbar content.
- **Pale blue:** `selected-blue` supplies numbered badges and the selected navigation indicator. The trip footer uses this color at 45% opacity over white.

### Neutral

- **Canvas:** scaffold, app bars, and bottom navigation.
- **White:** enclosing groups and modal sheets.
- **Text and supporting text:** `text-light` and `text-muted-light` establish hierarchy across the single light theme.
- **Quiet outline:** `outline-light` frames groups and divides related sections.
- **Field fill:** `field-light` separates text entry and map loading/unavailable surfaces.
- **Mist:** regional building/road surfaces use quiet related tones from the authored map style.

**The Readable Blue Rule.** Use `link-blue` for action text, icons, focus strokes, and focused floating labels; use Cornflower with `action-ink` for filled primary actions.

## Typography

**Display and body font:** bundled Figtree, licensed under SIL OFL 1.1; no runtime font request. Material icons come from the Flutter SDK.

Figtree is direct and friendly. The frontmatter expresses unscaled Flutter logical sizes as portable `px` strings, not physical pixels. Text follows platform scaling. Line heights and tracking include inherited Material 3 values where the app does not override them.

| Role | Use |
| --- | --- |
| `headline` | Today and Recurring titles; numeric hour/minute entry |
| `title` | Sheet headings, group names, and editor title fields |
| `section` | Section labels and endpoint values |
| `body-large` | Explanations and empty-state support |
| `body` | Date, descriptions, and supporting text |
| `row-title` | Semibold compact errand title |
| `detail` | Timing, endpoint labels, trip labels, and preview notes |
| `label` | Trip values and text actions |
| `button` | Filled action text |

Numbered badges and navigation labels use Material `labelMedium` with semibold weight. Standard controls retain Material typography where unspecified. Row titles wrap and determine row height.

**The Hierarchy Before Decoration Rule.** Establish hierarchy through type role, weight, spacing, and secondary text color; keep the compact list free of competing display treatments.

## Layout

Screens center one content column capped at 560 logical pixels. Today and Recurring use 20-unit horizontal page padding; editors, Settings, map entry, and sheets generally use 24. Today's anchored primary action caps at 520 and sits in a bottom SafeArea above shell navigation. Today and Recurring use a 64-unit toolbar; app-bar titles have a 24-unit inset.

Small gaps join related text, medium gaps separate controls, and larger gaps separate sections. Shared rows use 20-unit horizontal and 8-unit vertical padding, a 24-unit number badge, and a 14-unit badge-to-title gap. Forms and main content scroll; the composer remains open for consecutive entries.

The trip footer uses three equal columns. Its source switches to stacked label/value rows when available width is below 320 logical pixels or scaled 14-unit text exceeds 17. The shell switches from its 76-unit bottom NavigationBar to a labeled NavigationRail at 840 logical pixels. These are source-defined adaptations; wide-device behavior and the footer's large-text stack have not been established by native captures.

Buttons and icon buttons have theme minimum targets of 48 units; the primary button minimum height is 56. Preserve visible labels, app-bar tooltips, safe areas, and keyboard bottom insets. Generated native captures are local evidence in the ignored `.impeccable/review/` directory and are not published with this repository. Native review evidence covers a physical API 36 Android phone at 720 × 1640: Today (`.impeccable/review/native-v3-today.png`), Recurring (`.impeccable/review/native-v3-recurring.png`), collapsed groups (`.impeccable/review/native-v3-collapsed.png`), notes (`.impeccable/review/native-v3-notes.png`), consecutive entry (`.impeccable/review/native-v3-continuous.png`), feedback (`.impeccable/review/native-v3-feedback.png`), and dismissed feedback (`.impeccable/review/native-v3-feedback-dismissed.png`). The notes editor (`.impeccable/review/native-v3-notes-large.png`) and Recurring (`.impeccable/review/native-v3-recurring-large.png`) also have captures at 1.3 text scale after restart; the scale was restored to 1.0. Final focused-label recaptures of the composer (`.impeccable/review/native-v3-composer.png`) and Notes (`.impeccable/review/native-v3-notes-focused.png`) establish the readable-blue role. Earlier time-sheet (`.impeccable/review/native-time.png`) and map-preview (`.impeccable/review/native-map.png`) captures cover unchanged patterns. TalkBack, predictive Back, and frame-rate performance remain unverified.

## Elevation & Depth

Custom page surfaces are flat. Outlines, filled fields, selected tints, and spacing carry structure. App bars disable scrolled-under elevation and surface tint; navigation also disables surface tint. Floating snackbars use Material elevation 1. There is no authored custom shadow; native sheets, menus, chips, and Material interaction overlays retain framework behavior where unspecified. Shared motion is recorded with the affected components below and in the sidecar.

**The Quiet Surface Rule.** Separate resting content with tone, spacing, and subtle outlines; keep the shared errand containers free of custom shadows.

## Shapes

Fields, primary actions, enclosing groups, and sheet tops use the frontmatter radius hierarchy. Shared groups clip their interactive children. Sheets round their top corners; numbered badges are circles. The grouped trip footer inherits the enclosing route surface's clipped lower corners rather than creating three independent tiles. Quiet one-unit outlines frame and divide content.

## Components

### Buttons

FilledButton is the Cornflower anchor with dark content and zero authored elevation. Filled and outlined actions share a 56-unit minimum height, 18-unit radius, Figtree 16 semibold label and 20-by-12 horizontal/vertical padding. Outlined labels use readable blue. Stacked primary/secondary actions share available width and page insets; longer labels and larger text may increase height rather than clip. Compact text/toolbar actions retain 48-unit targets. Preserve native pressed, hovered, focused and disabled states. Today disables **Plan my day** when empty; enabled entry starts cache-first understanding directly.

### Cards / Containers

The shared white outlined surface groups related content in Today, Recurring, and group editing. Individual errands remain compact rows. Today contains editable From/To endpoints with labeled **Map** buttons, a collapsible list, and the grouped Leave/Home by/Travel footer. Initially it shows up to five user errands, with **Show all** for longer lists. Recurring group headers toggle their contents while retaining the group name and repeat description; expanded content contains editable rows and **Add to Today**. Rows with nonempty notes show a readable-blue note icon (16 units) with the semantic label **Has notes**; the note body stays out of the compact list.

### Inputs / Fields

Fields have a quiet fill, no resting stroke, and a readable-blue focus stroke (1.5 units). Floating labels use readable blue when focused, supporting text when resting, and the generated error role for errors. The errand title accepts one to three lines. Quick add reveals one field and **Done adding**; submit adds an Anytime errand, clears the field, and keeps its state and keyboard focus for another entry. The composer follows the growing list to remain visible. Tapping a row opens the shared draft editor. Save validates and commits; system Back discards the draft. Delete and clear actions expose Undo where implemented.

### Errand details

The focused editor keeps the errand name, Notes, Where, a compact When summary, and If there’s time visible. When opens the shared single-choice sheet, followed by numeric time entry when needed; a separate clock row displays and edits the selected time. A state-preserving More details disclosure uses an inline header and subtle divider, followed by expanded visit-duration and prerequisite controls. Its summary identifies entered details and unavailable prerequisite references; its chevron rotates with the disclosure and honors reduced motion. After expansion, the editor scrolls the last control into view when necessary; a manual drag cancels a pending automatic adjustment. Dependency selection excludes the current errand and prevents new cycles. These choices are saved as local input; automatic planning is not implemented.

### Errand notes

The focused editor contains a labeled **Notes (optional)** multiline field directly after the errand name, with a four-line minimum that grows with its content. It uses the shared field treatment and scrollable form. Notes are plain text, can be cleared, and save with the errand draft. Recurring copies carry notes independently into Today; neither later edit rewrites the other. Notes persist with Today and Recurring on Android; the browser preview remains in memory. Interactive shopping checklists are not implemented.

### List motion and disclosure

[Shared motion](apps/mobile/lib/core/widgets/motion.dart) uses a short entry duration (260 ms), a shorter exit duration (180 ms), and `easeOutCubic`. Rows combine size and fade transitions for insertion/removal. Today, saved-group contents, repeat details, and the composer use state-preserving size disclosure; disclosure reverses with `easeInCubic`. Chevron rotation uses the shared entry duration and curve. Disclosure can reverse during a transition, and collapsed contents leave focus and semantics traversal. The platform's Remove animations preference makes these spatial transitions immediate. These are source-defined behaviors, not a measured frame-rate claim.

### In-app feedback

[Shared feedback](apps/mobile/lib/core/widgets/feedback.dart) uses a floating Material snackbar: pale-blue fill, readable-blue text and Undo, a status or advisory icon (20 units), the shared button radius, side insets (20 units), bottom inset (12 units), and Material elevation 1. Status icons are excluded from semantics because the message carries the information. A new message replaces the current one. Ordinary messages expire after four seconds; Undo messages expire after six seconds under ordinary navigation. When accessible navigation is requested, actionable messages persist. Entry and dismissal use the shared motion durations. These messages are in-app confirmations; Android reminders and system notifications remain unimplemented.

### Time entry

[The time sheet](apps/mobile/lib/core/widgets/time_entry_sheet.dart) uses two centered numeric fields, AM/PM segments, and action chips for 8:00 AM, 12:00 PM, and 6:00 PM. Hour accepts 1–12 and minute accepts 00–59. The sheet scrolls and adds keyboard insets. Chips and segments retain Material shape and state behavior. **Save time** commits; dismissal cancels.

### Place entry

Profile provides an outlined Saved places entry leading to a local list. Selecting a place opens a focused editor for its name and map location; saving commits the draft, Back discards it, and deletion requires confirmation. Existing errands and endpoints retain their selected place details. Loading failures offer retry and unavailable storage is distinguished from an empty list.

[The place screen](apps/mobile/lib/core/widgets/place_picker.dart) opens one map-based picker for endpoints, errands and saved-place location editing. A persistent search field stays above the map with the keyboard initially closed. Focusing search displays a scrollable panel of saved places and online results. Search waits for a 600 ms typing pause and at least two characters, runs one request at a time and retains only the latest queued query. Choosing a result closes search and centers its location beneath the pin. Moving the map changes a draft point, and one Confirm location action commits it. Initial map positioning never selects a point automatically. Back closes search before cancelling the picker. Name-only entry is explicit and retains no invented coordinates. Attribution is accessible from the map and search results, and failures retain saved-place and manual entry.

Today shows an online map directly below trip settings, extending to the edges of the same surface. A and Z mark confirmed From and To locations; numbered markers correspond to errands. Places without coordinates remain in the list, and no route is drawn. The map starts at a Philippines overview when no locations are confirmed, fits confirmed places, and shows loading and retry states. Its Cornflower information button opens Wayday's credits page, without an always-visible credit label; this differs from the OpenStreetMap Foundation's attribution safe-harbour guidance. The offline Pasig/Ortigas preview has been retired. Settings retains credits for the online map, search providers, supporting datasets, and bundled font.

### Navigation and editing

[The shell](apps/mobile/lib/app/wayday_app.dart) has labeled Today, Recurring, Profile, and Settings destinations; the selected icon sits within a pale-blue indicator. Shared pushed editors keep native Back and visible Save actions. Recurring supports named lists, direct item editing, independent group drafts, deletion with Undo, and manual copying to Today. Repeat controls expand within the group editor and describe metadata only. [Settings](apps/mobile/lib/app/settings_view.dart) uses the shared page heading, the Profile-style unavailable-settings placeholder, concise storage/online-service information, and the credits entry. It has no appearance, offline-preview, or example-reset controls.

### Selection controls

[Shared selection controls](apps/mobile/lib/core/widgets/selection_controls.dart) use the existing Cornflower theme. The four timing choices appear in a selection sheet, while repeat frequencies appear as labeled radio rows. Group labels use the section type role with an 8-unit gap; rows use 12-unit horizontal padding, a 14-unit corner radius, a minimum 48-unit height, and wrapping labels. Selection combines a checked radio, pale-blue container, and readable-blue content. State is not conveyed by color alone. Radio groups support Tab, arrow keys, and Space through Material's shared group semantics.

Weekday entry opens the same scrollable single-choice sheet with a visible title, current selection, and seven weekday rows. Sheet headings use the title role, with a 16-unit gap before choices and actions. The sheet retains the 24-unit content inset and safe-area handling. Choices stay pending until **Done**; **Cancel**, Back, a swipe, or tapping outside discard them. Text drafts remain intact, the sheet opens without a text keyboard, and dismissal returns focus to the invoking day control. Remove animations makes its entry and exit transitions immediate.

Monthly repeat uses a labeled numeric **Day of month** field accepting 1–31. Save validates the field even when Repeat is collapsed, opens the section, and focuses invalid input. Changing frequency discards invalid monthly text; switching a monthly day above 7 to a weekday pattern retains the existing Saturday default. Timing changes, repeat changes, and weekday selection update editor drafts; the outer **Save** or **Save list** commits them. Repeat remains metadata and never adds errands automatically.

The synthetic harness in [selection component tests](apps/mobile/test/selection_controls_test.dart) supplies a small preview without adding production sample data or a gallery route. With `WAYDAY_CAPTURE=1`, it loads bundled Figtree/Material icons and writes the rendered preview to the ignored `.impeccable/review/selection-controls.png` path. Widget checks cover selection, dismissal, keyboard focus, large text, and reduced motion; Android walkthrough evidence belongs in Progress.

### Planned map refinements

Real map refinements remain future product work. See the product requirements in [README](README.md#product-requirements) and decisions D19–D20. Current implementation priorities come from the owner's latest instructions.

- The real map uses a custom Wayday style with readable street/city/landmark labels. Selected errand stops stay prominent; candidate categories, clustering, and zoom-dependent labels reflect the same filtered results as the search list.
- Map-style selection applies only to the map. Keep app chrome light Cornflower, attribution visible, offline coverage honest, and manual-pin/no-results paths usable.
- Extend the existing Material 3 theme as repeated patterns emerge; do not introduce a second broad UI kit without a demonstrated gap.

### Documentation previews

The sidecar's self-contained HTML/CSS snippets translate native shapes and grouping for the design panel only. Flutter is the runtime authority; preview focus and interaction CSS approximates Material states. Derived tonal ramps are documentation swatches, not extra app tokens or alternate palettes.

## Do's and Don'ts

### Do:

- **Do** read semantic colors and typography from the single Flutter theme.
- **Do** reuse compact numbered rows, Anytime-default quick add, and focused editing across Today and Recurring.
- **Do** let titles wrap, trip properties stack, and forms scroll with larger text and keyboard insets.
- **Do** preserve Material states, visible labels, tooltips, and system Back.
- **Do** preserve composer state and focus during consecutive entry, and honor Remove animations for shared spatial transitions.
- **Do** keep optional notes in the focused editor and indicate their presence compactly in rows.
- **Do** replace stale feedback, expire ordinary messages, and preserve accessible Undo actions.
- **Do** distinguish regional map exploration, manual labels, confirmed pins and calculated routes, and retain honest unavailable-feature copy.
- **Do** preserve historical Asikaso references and attribution.

### Don't:

- **Don't** reintroduce palette selectors, device-following appearance, or dark-mode controls in this MVP.
- **Don't** use Cornflower as small action text on white; use the readable link role.
- **Don't** turn each compact errand row into a permanent form or separate card.
- **Don't** present illustrative map geometry as geographic data, search results, or a calculated route.
- **Don't** imply unverified persistence for a new feature or claim that repeat metadata schedules automatic additions. Today/Recurring restart persistence is verified on Android.
- **Don't** treat native screenshots as verification of TalkBack, predictive Back, or performance.


## Shared place search (2026-10-29)

Today endpoint rows and the errand editor's Where section keep their location labels compact. Do not show a provider-credit line in either section; the owner requested credits in Settings. Clear resets errands, both endpoints and trip settings; the current date remains selected, and Undo restores the previous plan.

Google and Other sources share the original picker controls and Figtree/Cornflower vocabulary. Keep the title, Close search, and rounded pale query field fixed above the content. The source choices are compact text actions; the active source uses stronger weight and an underline, without a filled selection block. The active origin, Near me / Use my location, and Search this area stay in the search content. Saved-place rows, ambiguous suggestions and failure/retry controls are shared between source groups. The Places heading and automatic-correction explanation and original-text action are omitted to make more room for results. The search interpreter still applies its aliases and corrections while retaining the typed text.

Keep the same controls while typing. Do not replace them with a Search options menu or remove the fallback actions when the keyboard appears. Use name only remains a full icon/title/subtitle row, followed by the separate Back to map action. Other sources uses lazy, scrolling white result rows with Google-like title/address typography, padding and dividers. A neutral chevron selects the row; straight-line distance labels and provider credits remain visible. Google uses content-sized controls above its native list and full fallback rows below; on constrained viewports the controls and fallback regions scroll, reserving a 180-unit native results viewport on normal panels and 45 percent on panels of 400 units or less. Their height limits are ceilings, not reserved blank space.

Google retains standard native cards, their order, attribution and required controls. Position the SDK's Google Maps attribution at the bottom of the native results component, above Wayday's name-only/map fallback region; do not replace or hide it. Supported theme overrides use regular-weight sixteen-unit place names, fourteen-unit muted addresses, Figtree, flat white surfaces, quiet outlines and Cornflower actions. The Google SDK retains its own card structure and external Maps control, so the rows are visually similar rather than identical; no Google results or distance labels are manufactured. The native CardView style explicitly uses a white background, including in Android system dark mode. Font resources still come from the existing licensed bundled asset.

The native host keeps its key and tree position through IME, text-scale, status and layout changes. These changes must not rebind a search request. Source switching preserves the query, origin and draft; selecting a record still leads to Your label and Confirm location. Verification and remaining device limitations are recorded in Progress.

Within an open picker, switching sources restores each group's loaded results, status, frozen updates and scroll position immediately. Google remains mounted while hidden, with native focus/accessibility excluded, rather than rebuilding its fragment. Results remain until search closes; switching does not refresh them after a timer. A compact refresh icon beside the source choices has the tooltip and accessibility label **Refresh results**. It deliberately refreshes the selected source group, respects quotas and keeps existing rows visible while loading. Failed searches retain their explicit Retry search action. Query, category and explicit origin changes start a new results context. Keyboard visibility does not end the session.


## Plan my day preparation and itinerary — D47

Use the same Flutter theme, Figtree text, compact rows and focused editors as Today. Preparation opens loading directly, then Review errands with explicit model proposals and conditional actual-location correction (D48–D49). Place discovery retains standard visible Google UI Kit components and explicit Other sources. Never replace native Google cards with invented branch names or remove their attribution. Recommendations offer a change-place action; Your day combines a Google route map with numbered arrival/service/departure rows and separate optional omissions. Required information and updated traffic validation gate acceptance.

Back moves to the preceding preparation state while retaining the draft; Close returns to Today. Returning through constraint review invalidates route estimates before acceptance. Calendar selection and existing numeric time sheets resolve past departures explicitly. Use native map interaction only to select/recenter a stop, with a readable timeline fallback and attribution outside overlays. Saved itinerary progress uses explicit independent checkboxes; arrival alone does not complete errands. The trip screen embeds guidance and exposes Stop/Back without deleting progress. Reduced motion and text scaling follow the existing theme and shared controls; no new decorative motion or color system is introduced.

The current Impeccable brief includes a dated correction for its historical sample/memory/illustrative-map assumptions. No active Impeccable tool execution is claimed. Physical-device large-text/TalkBack and live navigation checks remain distinct from fixture rendering.


## Direct preparation entry — D48

The owner removed the introductory Plan my day page. Tapping the existing primary action immediately shows the existing loading treatment while saved understanding is checked or Gemini processes current input. No preliminary Continue action or artificial delay is added. A matching completed result proceeds to Review errands. Back/Close during understanding exits to Today while bounded in-flight work can finish and save its answer. Back from Review exits to Today, and re-entry restores matching interpretation rather than showing the removed introduction.

On actual failure, show a concise explanation, Check saved understanding and an explicitly labelled Retry Gemini (uses a request) action. Existing completed answers are reused even on retry; pending/failed outcomes require explicit retry before dispatch. Keep proposal approval explicit and preserve the existing app theme, scrollable content, touch targets and source-data cancellation semantics. D49 replaces ambiguous per-errand checkboxes with named suggestion actions.


## Compact interpretation review — D49

Review errands has one short explanation, an expandable Trip details summary, and a single outlined group of compact numbered errands. Each errand shows its existing timing, visit length and optional status. Tap the row to reveal notes, interpreted search/items, existing prerequisites and Edit errand. Show only applicable differences between the user’s draft and the effective model proposal, using readable Current and Suggested values. Use suggestion explicitly selects those differences; Keep current declines or reverses selection. Neither action completes an errand or sends a model request. Selection remains reversible after returning from discovery.

Do not repeat unchanged/protected timing, priority or duration as suggestions, expose internal timing enum names, or place a Review action on the Review errands page itself. Other preparation stages retain the existing return-to-review action. Missing private locations and unanswered questions remain visible outside collapsed details. Extra errands expose their proposed details and explicit Add/Remove actions. Truck’s distinct light-pickup confirmation remains required. Trip details initially expand when endpoint correction or light-pickup confirmation is needed.

Next: find suitable places stays anchored below the scrolling review content, capped with the same 560-unit content column. Errors appear directly above it in a bounded scrollable live region. Expansion respects Remove animations; long labels and enlarged text wrap. The updated review was rendered with the bundled Figtree and Material icons at 390 × 844, 320 × 740 with 2× text, and 768 × 1024. These are synthetic Flutter captures; they do not establish native TalkBack or live-service behavior. Impeccable context and its distill/craft guidance were used for this focused refinement; historical no-tool statements above describe earlier work.

### Discoverable trip editing — D56

Use the review list's existing typography throughout this section: 14-unit `bodyMedium` for the section heading, field labels and field values, semibold only for the heading; 12-unit `bodySmall` for the trip summary and supporting hints. Edit/Hide retains the shared 14-unit action style. Do not enlarge field values to `bodyLarge` or shrink their persistent labels to `bodySmall`. Place the pencil beside the value so long labels can use the field's full content width and the two time controls remain aligned.

Review's Trip details uses the shared outlined white surface and a readable-blue Edit label with a disclosure chevron. Expanded details show labeled, pale filled date, departure, finish-time, From and To controls. Every entire field opens its existing editor; a trailing pencil communicates editing without relying on color alone. The date includes its year, and location values remain separate from their persistent From/To labels. Missing coordinates retain Choose a map location; confirmed points do not repeat Location ready.

Departure and finish time share a row when the inner width is at least 320 units and scaled 14-unit text is no larger than 17; otherwise they stack. Enlarged text also removes the header's redundant Edit/Hide word while keeping the disclosure icon and native expansion semantics. Values wrap without ellipses, fields have at least 64-unit height, and Material ink/focus states and labeled button semantics remain available. The component listens to the expansion controller so restored disclosure state and its header agree. Existing picker, cancellation, validation, persistence and light-pickup confirmation behavior is retained. Verification is recorded separately in Progress.


### Location questions and recommendation cues — D50

A generic model-generated location question does not replace current place state. Existing usable points remain selected. Unattached business/activity rows show Place recommendations next and continue to discovery. Missing private meeting points expose Choose actual location; expired selected references also require confirmation. Shared domain policy controls both visible questions and Next validation, including existing cached answers. Mixed or non-location clarification questions remain explicit. No additional model request is made merely to apply this correction.


### Validation feedback after editing — D51

Preparation errors describe the input that was checked. Saving a new date/time or changing the preparation model clears the old local warning; cancelling an edit leaves it visible. The next forward action validates current values again. Do not leave a past-departure message under a corrected future departure or automatically rewrite the user’s trip date.


### Immediate order preview and departure recovery — D52

Choosing or declining an ordering suggestion immediately updates the numbered review rows using the same projection as forward validation. Keep the baseline for reversal and preserve explicit user fields. A genuinely expired departure expands trip details initially and displays its exact date/time with Change date and Change departure. Next is disabled while it is past or dependency rules are invalid. Keep feedback scrollable within a bounded region at enlarged text sizes; the primary action remains anchored. Refresh clock-dependent feedback on resume without provider work.

Confirmed review date/time edits are retained locally for the matching Today source, independently of Today and the accepted itinerary. Close/reopen restores them; cancellation does not save. Storage failures remain visible with Retry saving trip settings. Replanning keeps its own supplied context. There is no silent movement of appointments, automatic date rollover or extra Gemini generation for this restoration.

### Review field recovery — D53

Use the existing review feedback area for actionable conflicts, naming the errand and offering its editor. Keep Next visible but disabled while a deterministic blocking issue remains. Preserve compact rows and bound/scroll long feedback at large text. Do not introduce another confirmation page or automatic appointment changes. Review editing exposes supported field changes; source-errand removal remains in Today.

### Understanding recovery — D55

Use one short state heading and relevant explanation. Distinguish a missing answer, interrupted processing, connectivity, configuration and a Google provider quota. Check saved understanding is a full-width read-only action, paired with an equally wide Retry Gemini action. Explain the possible request cost once beneath the controls. Do not show obsolete local attempt-count limits.

## Clarification answer sheets — D57

A question opens a focused modal sheet, not the errand editor. Reuse the 560-unit content bound, existing sheet shape, Figtree roles and shared action metrics. Show the errand title, one question, an English/Filipino/Taglish answer field and Use answer. Keep text concise; use context-specific quick actions. Processing shows Understanding your answer, prevents duplicate submission and permits Close. Keyboard insets and scrolling keep actions reachable at narrow widths and enlarged text; disable discretionary sheet transitions under reduced motion.

A successfully saved answer becomes a compact editable summary beneath its errand. Keep the visible 15-minute estimate and estimate label unchanged. Optional preferences never block the next step. Proposed rules stay in expanded details with explicit approval. Unknown essential points expose the existing picker and Plan the other errands. Deferral previews affected tasks, keeps reasons visible and provides Include in this plan; an empty active plan explains that an errand must be included. Drafts stay separate from applied results, and saved-result checks/save retries do not spend generation requests.


## Route-aware recommendations — D58

After Review errands, Build recommendations automatically discovers flexible places and compares the whole trip. Replace the discovery search form with Recommended places: one shared Google map, a compact trip summary, numbered rows and an anchored Next: see my day action. Keep the existing 560-unit content bound, Cornflower/Figtree theme and shared action metrics. Monochrome category icons supplement numbered stop identity. Rows show errand, actual provider name, available locality, incoming travel time/distance and one concise recommendation reason. Selecting a row or marker synchronizes the same stop; expanding reveals full address, available category, approximate extra travel, unknown availability, calculation time and Change place. Shared visits retain individual errands.

The map can collapse, particularly at short heights and enlarged text. Keep a visible Map action and readable list fallback. Google attribution remains visible when the map is collapsed, and provider credits retain their links/emphasis. Traffic now is a separate map control for supported motorized modes, not a claim about future traffic. Panning, zooming, selecting a marker and scrolling never search or recalculate. A and B identify endpoints; numbered stop markers match list numbering.

Change place opens an alternatives page with Previous/Next errand controls, preserved selections, approximate comparisons where road data exists and a separate Search for a place action. Manual selection uses Choose place, saved places and Choose on map in the existing picker. Planning requires a map location and omits Use name only; other picker contexts retain their existing role. Back returns through the prior view without discarding choices. Close saves matching draft choices; a storage failure stays explicit. Phone location is an explicit foreground action and does not replace the planned start until Confirm location.

Use transient Places SDK names/addresses for recommendation presentation, separately from durable user errand labels and provider IDs. Never invent a place name, landmark, distance or road estimate. Source/context-bound drafts restore navigation and choices after restart while estimates are rebuilt. Check narrow screens, long Filipino/Taglish content, keyboard insets, text scaling, focus, semantics and reduced motion. Synthetic captures and the isolated Android fixture run do not establish live coverage or physical-phone/TalkBack readiness.

## Combined trip review — D61

Your plan combines a compact trip summary, numbered errand/place rows with visible Change, arrival/visit/incoming travel information, one route preview and important notices. Details disclose address, departure, waiting, buffer, reasons and calculation age. Multi-edit state replaces Start trip with Update plan; unavailable data never looks current. Recovery retains all editing controls. Alternatives are a supporting sheet with secondary manual search. The inline map yields vertical scrolling and an expanded interactive map retains attribution. Preserve Canvas/Cornflower, Figtree, theme target sizes, reduced motion and enlarged-text reflow. Start trip opens navigation; Save for reuse creates a separately named Recurring entry.

## Clearer alternatives and route updates — D62

D62 supersedes D61's manual Update plan interaction and the redundant trip-summary/Trip details block on Your plan. Keep Trip details on Review errands. Replacements save and automatically refresh roads and timing after a 500 ms debounce. Your plan stays visible with Updating route, enabled Change controls and disabled Start trip. Move changed markers immediately, hide outdated route/times, and replace geometry/order/schedule together. Failed updates retain edits with Retry route update; never display stale estimates as confirmed.

The alternatives sheet fits short content and has a maximum of 90% of usable height. The heading, Close and Errand 3 of 3 · Groceries pager stay visible; results and actions scroll. Retain Previous/Next arrows and per-errand scroll/list state. Mark Current place with a checkmark and selection semantics. Show actual business/locality and available approximate comparisons. Where unavailable, explain once above the list that route/schedule update after selection.

After the rows, Show more suggestions appends up to three unique choices. Choose a specific place is a separate outlined action with the explanation: Search by name or address, use a saved place, or choose on the map. Put attribution after these controls. Avoid a nested Scaffold, forced 90% sheet height or a bottom-anchored action separated by empty space. Keep 48-unit controls, wrapping, keyboard/safe-area handling and reduced motion. Cancelled manual selection returns to the same sheet; dismissal returns to the underlying plan. Loading/error/exhaustion states retain selectable rows and distinguish failed searches from no additional suggestions.

## Business hours in disclosed places — D63

Preserve compact Your plan rows. Display reported trip-day hours only inside Details and Choose a place. Details offers Weekly hours, retrieval date/time attributed to Google Maps, and expected visit compatibility only when a fresh route actually validates that stop. Checked means Wayday retrieved the data, not that the business confirmed it at that moment. Alternatives show the date's hours; retain the recalculation explanation for branches without candidate-specific timing. Main plan feedback identifies blocking closing conflicts and keeps Change available.

Distinguish Hours not provided by Google Maps, Business hours could not be checked, Business hours need refreshing, and hours unavailable for this trip date. Failed/stale checks offer an explicit retry. A dropped pin without a Google business ID states that business hours are unavailable for that pin. Keep unknown hours visible as unknown; never label them closed. Retain an unsuitable current selection with its hours rather than silently removing it. Future regular-week fallback says Usual hours and discloses special-date uncertainty. Remove the blanket opening-hours warning and keep the five-minute buffer explanation separate. Hours do not prove stock, membership access, order readiness or appointment capacity. Preserve wrapping, existing typography/actions, provider attribution, nested Back and enlarged-text scrolling.

## Compact sequential guidance — D64

Your trip gives the map the remaining viewport and keeps a compact current-errand panel below. The owner clarified that only one active errand and one checkbox may be shown, including at shared stops. Use Mark this errand when done, the current task title and its checkbox. Save before revealing the next task; completing one of several errands at a location does not advance guidance prematurely. Do not repeat the place label or permanently display the explanatory paragraph. Final destination and Finish trip appear after all remaining errands are completed.

Keep native Google maneuver instructions, ETA/distance, compass, Recenter and attribution unobscured. Whole trip is a toolbar text action, changing to a labelled/tooled route icon on narrow or enlarged-text toolbars. It fits the remaining road geometry and waypoints; Recenter restores location following. The options menu contains View plan and Navigation info. Back stops guidance and returns to saved progress. The information sheet explains manual completion and the distinction between live navigation travel estimates and the errand schedule. Keep normal 48-unit targets, wrapping and bounded scrolling for long task labels. The map stays stable through state changes; GPS recovery does not repeatedly reset manual panning.

Wayday's panel remains in the light Canvas/Cornflower theme; navigation uses automatic day/night lighting. Modernize the activity NormalTheme with existing Material Components and apply supported SDK dialog colors. Preserve Google's terms content, links and acceptance. No custom imitation of Google navigation controls or terms is introduced. Synthetic UI captures and mocked Android interaction are separate from actual GPS, native camera/route rendering and physical TalkBack qualification.

## Current-trip recovery and Finish — D65

Place a compact Current trip surface below Today's date and above its editor, with the shared route icon, progress such as 1 of 3 errands completed, and Resume trip. Resume opens the existing current-trip summary. Remove the bottom View saved plan shortcut. A fully checked errand list is not a finished journey; retain recovery until Finish is confirmed. No automatic reusable entry or completed-history section appears. Keep the Cornflower/Canvas/Figtree system, compact spacing, 48-unit actions and wrapping at enlarged text.

Back/View plan preserves progress. Finish trip, available after all assigned errands are done in the summary and navigation's final-destination state, opens Finish trip and clear Today? with Cancel and Finish and clear Today. Explain that all Today errands, locations and trip settings reset, including work added or left out of the trip; reusable trips, recurring lists and saved places remain. Use a scrollable accessible dialog for long/large text. Clear the recovery section and return to Today only after storage commits. Failed cleanup shows Retry finishing trip; changed Today requires a renewed confirmation. Finishing is distinct from stopping guidance or Save for reuse.

The Finish trip action uses a full-width outlined button with the shared 56-unit minimum height and flag icon, including its retry/processing states. The owner requested a visible button boundary because the former text-only action was easy to miss. Keep the confirmation and cleanup behavior unchanged.

## Website extension — implemented 2026-11-01

This extension records the static marketing website in [apps/website](apps/website/README.md). All `website-*` frontmatter entries belong to this surface; existing unprefixed tokens and the preceding mobile design remain unchanged. Website CSS pixels and responsive clamps do not replace Flutter logical sizes. [README.md](README.md#product-requirements) remains the product authority.

### Overview

**Creative North Star: "Errands coming together"**

The website gives everyday errands a large, editorial expression: loose notes converge on a phone, then alternate light and navy chapters make understanding, choices, an estimated plan and familiar routines tangible. The original route-W PNG, bundled Figtree and Cornflower connect it to Wayday while the larger typography and expressive motion belong to the marketing surface.

The website presents a reviewable day under the user's control. Its product diagrams are labelled illustrations with sample errands, not screenshots, real business results, calculated routes or an interactive browser app. Requirements, release status, installation guidance, FAQ and privacy remain readable content after their headings enter.

**Key Characteristics:**

- Large editorial headlines with a dominant phone and scattered errand notes.
- Warm off-white, navy chapters, Cornflower emphasis and pale-blue staging.
- Reversible, scroll-driven scale, rotation, convergence and reveals.
- Four layered steps and a turning reuse motif, with ordinary-flow fallbacks.
- Stable practical content, native FAQ disclosures and an honest unavailable download state.

### Colors

The namespaced palette follows the website's own CSS properties. `website-ink` is both text on light surfaces and the navy feature-chapter background; `website-blue` is the readable link, focus and download-chapter color. Cornflower emphasizes headings and illustrated actions. Canvas and white carry the page, panels and notes; pale blue carries the steps/reuse/closing surfaces. `website-muted` supports light-surface copy; `website-dark-support` supports copy on navy. The quiet line divides practical content, and the cool hero surface sets the opening apart. These website supporting colors intentionally differ from the mobile supporting tokens.

### Typography

One locally bundled variable Figtree font (weights 300–900, Arial/sans-serif fallback, swap display) carries the entire surface. The desktop display, chapter headline, feature title, body, action and navigation roles are in frontmatter. Headings use balanced wrapping and tight tracking; paragraphs generally use a 1.65 line height. Hero support is larger (18 px, 1.55 line height); feature text caps at 440 px and FAQ answers at 740 px.

Responsive type is authored rather than uniformly scaled. At 960 px and below, the opening becomes a stacked composition with a `clamp(46px, 7.5vw, 70px)` headline and 1.01 line height. At 420 px and below the headline is 47 px. Feature titles become `clamp(34px, 6.8vw, 44px)` below 700 px, with a 36 px narrow feature-heading override. Small illustrative UI text belongs only inside labelled diagrams; it is not the site body scale.

### Layout

The main shell caps at 1240 px with 56 px side margins; responsive side margins become 40 px below 1100 px, 32 px below 960 px and 20 px below 420 px. The sticky header is 80 px tall, reducing to 76 px below 960 px. Its labelled Menu control replaces the desktop links at that breakpoint; open navigation is a vertical panel below the header. Essential anchors also work without JavaScript.

The opening uses two columns within a 1600 px stage and stacks below 960 px, including at the reviewed 638 px width. Later feature, reuse and practical-content pairs stack below 700 px. Alternating visual/copy order, full-width color changes, generous chapter padding and fine dividers create rhythm. Step panels start with number/copy/art columns, becoming number/copy with the art beneath below 700 px. This is a marketing composition, separate from the mobile app's 560-unit content column.

With motion enabled, the hero occupies `calc(200svh - var(--header-height))`; its sticky stage occupies `calc(100svh - var(--header-height))`, subject to authored minimum heights. This adds a bounded scroll interval rather than controlling wheel or touch progress. At heights of 650 px or less the hero returns to ordinary flow. Reduced motion removes sticky opening/step staging and spatial choreography. Base HTML remains readable when JavaScript is unavailable; touch scrolling stays native.

### Elevation & Depth

Broad flat color fields establish the chapter hierarchy. Soft shadows distinguish the illustrated phone (`16px 30px 45px -24px #102d4450`), floating notes (`0 16px 38px -20px #102d4450`) and Back to top control (`0 8px 16px #102d4420`). They are illustration/control depth, not a replacement for the mobile app's flat shared surfaces. The Cornflower sheet behind the note illustration is a separately rotated material plane, not a general card-shadow rule.

### Shapes

Website panels, notes and actions share the namespaced panel radius; steps have a slightly wider radius, and the phone has its own enclosing silhouette with an 8 px navy border. Circular number marks, an oval hero field, a choice orbit and a reuse arrow provide diagram geometry. The supplied logo remains unchanged. Slightly rotated illustration layers are specific to these compositions and do not rotate reading text or practical controls throughout the page.

### Components

- **Actions and navigation:** navy filled anchors with white labels, 56 px minimum height, 16-by-24 px vertical/horizontal padding and a 28 px icon gap. Hover changes to readable blue and lifts 2 px over 0.2 seconds. The header variant uses 46 px minimum height and 10-by-18 px padding; compact hero actions use 48 px minimum height. Text links retain a 48 px minimum height. Focus is a visible 3 px blue outline with 6 px offset; download-chapter links use white focus. The menu and footer links have at least 44 px targets; Back to top is a 48 px circle.
- **Opening phone and notes:** the desktop phone enclosure is 310 by 540 px, reducing to 285 by 520, 250 by 456 and 235 by 438 at the authored breakpoints. Its inner scene starts at -18 degrees and 0.8 scale. The arrival wrapper separately enters from 100 px below at 0.65 scale over one second. Scroll straightens the inner phone to 0 degrees and 1.15 scale; compact scenes move it up 24 px, while wide scenes move it left by 18% of viewport width. Three notes travel horizontally by 115/-105/90 px in compact layouts or 200/-230/180 px in wide layouts, with vertical convergence, before fading into the phone. Reverse scrolling reverses this sequence. The illustration caption remains explicit.
- **Feature diagrams:** the editable-note illustration broadly reveals from 160 px below at 0.72 scale and -14 degrees to its authored 4-degree tilt. Alternatives enter laterally from alternating directions and retain a distinct confirmed choice. The concept-plan panel grows and reveals from below. None of these diagrams supplies live AI, business or route data.
- **Four steps:** numbered panels use Canvas, pale blue, Cornflower and navy in order. At a minimum width of 360 px and height of 700 px, motion-enabled panels stick at header plus 32/48/64/80 px. Their entrances move up 120 px and straighten from alternating 5-degree tilts. Reduced motion and short viewports keep the sequence in ordinary flow.
- **Reuse and close:** the reuse wheel turns from -60 to 120 degrees across its section while notes slide in from either side. The closing wordmark rises, straightens and grows. These are scroll-linked compositions, not continuous decorative loops. Lenis and GSAP share one ticker; media/lifecycle cleanup removes the enhancement when appropriate.
- **Release and FAQ:** the blue release chapter presents the unavailable action as a non-link with `aria-disabled="true"` and a development status. Validated build-time release metadata may replace it with an APK anchor and disclosed details only after qualification. Native `details`/`summary` elements provide FAQs. Installation instructions, limitations, privacy and footer links settle into ordinary reading flow.

### Do's and Don'ts

**The Website Illustration Rule.** Keep product diagrams visibly labelled and separate from real application screenshots, provider results and computed itineraries.

**The Website Motion Fallback Rule.** Every chapter remains understandable in ordinary document flow; reduced motion removes spatial choreography, sticky stacking and smooth anchor travel.

**The Website Release Honesty Rule.** Preserve the unavailable download state until qualified release metadata passes the existing validation boundary.

- **Do** retain the original route-W logo, local Figtree, namespaced palette and distinct light/navy chapter rhythm.
- **Do** preserve readable content, keyboard focus, native disclosures, natural scrolling and explicit Android/development status.
- **Don't** apply marketing display sizes, illustration shadows or scroll choreography to the mobile app's compact operating interface.
- **Don't** imply stock, appointments, route accuracy, complete offline planning or physical-phone readiness through illustrative diagrams.

Sources: [website styles](apps/website/src/style.css), [responsive behavior](apps/website/src/responsive.css), [motion scenes](apps/website/src/motion.ts), [lifecycle and navigation](apps/website/src/main.ts) and [page markup](apps/website/index.html). [Rebuild evidence](docs/wayday/evidence/website-rebuild-2026-11-01.md) records release tests, browser checks, production build and accessibility scans separately from application/provider/device qualification. Reviewed full-page captures use reduced motion to expose all content; they do not establish the animated sequence or device performance. Public downloads remain disabled.
