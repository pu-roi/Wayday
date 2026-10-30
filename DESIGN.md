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
rounded:
  field: "14px"
  button: "18px"
  card: "24px"
  sheet: "28px"
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
  regional-map: { backgroundColor: "{colors.field-light}", rounded: "{rounded.card}" }
  feedback: { backgroundColor: "{colors.selected-blue}", textColor: "{colors.link-blue}", typography: "{typography.body}", rounded: "{rounded.button}" }
---

# Design System: Wayday mobile

## Overview

Product context for design tools is maintained in [the README product requirements](README.md#product-requirements), including the product schema marker and platform/stack context. Supply README.md explicitly when a tool needs product context. See [the documentation index](README.md) for the remaining project documents.

**Creative North Star: "A clear day, in order"**

Wayday keeps everyday errands calm and easy to scan. Warm Canvas, white grouped surfaces, Cornflower actions, and compact Figtree text give the list a clear rhythm. This records the implemented Android Flutter shell, Today, and Recurring interface after the owner's approved system change on 2026-10-16: one light theme with no appearance controls.

The reusable character is quiet grouping, compact numbered rows, and details revealed in focused editors. Short list transitions preserve the consecutive-entry flow; optional notes stay inside the editor, and floating feedback clears after ordinary use. The Today-specific From/Errands/To composition remains in [the surface brief](.impeccable/surfaces/mobile-today.md); it is not a required composition for every future screen.

The token source is [the Flutter theme](apps/mobile/lib/app/theme.dart). Reused patterns live in [the shared errand list](apps/mobile/lib/features/errands/presentation/errand_list.dart), [focused editor](apps/mobile/lib/features/errands/presentation/errand_editor.dart), and [section surface](apps/mobile/lib/core/widgets/section_surface.dart). [Product scope](README.md#product-requirements) and [decisions](docs/wayday/DECISIONS.md) retain product authority. [Historical Asikaso design](docs/Asikaso-Prototype/DESIGN.md) remains preserved reference evidence.

**Key Characteristics:**

- One light Canvas/Cornflower theme with readable dark text.
- Compact shared errand rows and simple Anytime-default quick add.
- Quiet outlined groups, focused editors, and familiar Material states.
- Numeric time entry and a shared regional map with explicit manual-label semantics.
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
- **White:** enclosing groups, modal sheets, and regional map roads.
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

Today shows an online map directly below trip settings, extending to the edges of the same surface. A and Z mark confirmed From and To locations; numbered markers correspond to errands. Places without coordinates remain in the list, and no route is drawn. The map starts at a Philippines overview when no locations are confirmed, fits confirmed places, and shows loading and retry states. Its Cornflower information button opens Wayday's credits page, without an always-visible credit label; this differs from the OpenStreetMap Foundation's attribution safe-harbour guidance. The separate offline Pasig/Ortigas preview remains in Settings, with its source details and bundled notices on the credits page.

### Navigation and editing

[The shell](apps/mobile/lib/app/wayday_app.dart) has labeled Today, Recurring, and Settings destinations; the selected icon sits within a pale-blue indicator. Shared pushed editors keep native Back and visible Save actions. Recurring supports named lists, direct item editing, independent group drafts, deletion with Undo, and manual copying to Today. Repeat controls expand within the group editor and describe metadata only. [Settings](apps/mobile/lib/app/settings_view.dart) explains local Android storage, the in-memory browser preview, and unavailable planning features; it has no appearance or example-reset controls.

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
