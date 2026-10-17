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
  map-preview: { rounded: "{rounded.card}" }
  feedback: { backgroundColor: "{colors.selected-blue}", textColor: "{colors.link-blue}", typography: "{typography.body}", rounded: "{rounded.button}" }
---

# Design System: Wayday mobile

## Overview

**Creative North Star: "A clear day, in order"**

Wayday keeps everyday errands calm and easy to scan. Warm Canvas, white grouped surfaces, Cornflower actions, and compact Figtree text give the list a clear rhythm. This records the implemented upright-portrait Android Flutter shell, Today, Recurring, read-only sample Profile, Settings, place search, full-map confirmation, and manual day review on 2026-10-17. The light theme and visual tokens established on 2026-10-16 remain unchanged, with no appearance controls.

The reusable character is quiet grouping, compact numbered rows, and details revealed in focused editors. Short list transitions preserve the consecutive-entry flow; optional notes stay inside the editor, and floating feedback clears after ordinary use. The Today-specific From/Errands/To composition, manual review sequence, and search-to-map flow remain in [their](.impeccable/surfaces/mobile-today.md) [surface](.impeccable/surfaces/mobile-review.md) [briefs](.impeccable/surfaces/mobile-places.md); they are not required compositions for every future screen.

The token source is [the Flutter theme](apps/mobile/lib/app/theme.dart). Reused patterns live in [the shared errand list](apps/mobile/lib/features/errands/presentation/errand_list.dart), [focused editor](apps/mobile/lib/features/errands/presentation/errand_editor.dart), and [section surface](apps/mobile/lib/core/widgets/section_surface.dart). [Product scope](docs/wayday/PRODUCT.md) and [decisions](docs/wayday/DECISIONS.md) retain product authority. [Historical Asikaso design](docs/Asikaso-Prototype/DESIGN.md) remains preserved reference evidence.

**Key Characteristics:**

- One light Canvas/Cornflower theme with readable dark text.
- Compact shared errand rows and simple Anytime-default quick add.
- Quiet outlined groups, focused editors, and familiar Material states.
- Numeric time entry, real map pins, and an editable manual visit sequence.
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
- **White:** enclosing groups, modal sheets, and map pin labels and outlines.
- **Text and supporting text:** `text-light` and `text-muted-light` establish hierarchy across the single light theme.
- **Quiet outline:** `outline-light` frames groups and divides related sections.
- **Field fill:** `field-light` separates text entry.
- **Mist:** retained as an incumbent theme primitive; the real basemap owns its geographic styling and does not inherit the former illustration's blocks.

**The Readable Blue Rule.** Use `link-blue` for action text, icons, focus strokes, and focused floating labels; use Cornflower with `action-ink` for filled primary actions.

## Typography

**Display and body font:** bundled Figtree, licensed under SIL OFL 1.1; no runtime font request. Material icons come from the Flutter SDK.

MapLibre's provider-rendered pin labels request Noto Sans Regular from the external map style. This is map content, not an additional app font or typography role.

Figtree is direct and friendly. The frontmatter expresses unscaled Flutter logical sizes as portable `px` strings, not physical pixels. Text follows platform scaling. Line heights and tracking include inherited Material 3 values where the app does not override them.

| Role | Use |
| --- | --- |
| `headline` | Today, Recurring, Profile, and Settings titles; numeric hour/minute entry |
| `title` | Sheet headings, group names, and editor title fields |
| `section` | Section labels and endpoint values |
| `body-large` | Larger explanatory text |
| `body` | Date, descriptions, compact Today empty prompt, and supporting text |
| `row-title` | Semibold compact errand title |
| `detail` | Timing, endpoint labels, trip labels, and map status |
| `label` | Trip values and text actions |
| `button` | Filled action text |

Numbered badges and navigation labels use Material `labelMedium` with semibold weight. Standard controls retain Material typography where unspecified. Row titles wrap and determine row height.

**The Hierarchy Before Decoration Rule.** Establish hierarchy through type role, weight, spacing, and secondary text color; keep the compact list free of competing display treatments.

## Layout

Most screens center one content column capped at 560 logical pixels. Today, Recurring, and place search use 20-unit horizontal page padding; editors, Profile, Settings, and sheets generally use 24. Full-map confirmation uses the available width, with 20-unit confirmation insets. Profile's scrollable column uses 16-unit top and 32-unit bottom padding. Today's anchored primary action caps at 520 and sits in a bottom SafeArea above shell navigation. All four shell destinations use a 64-unit toolbar; app-bar titles have a 24-unit inset. Android is locked to upright portrait through both startup orientation and the activity manifest; landscape captures from earlier passes are historical evidence, not a current supported layout.

Small gaps join related text, medium gaps separate controls, and larger gaps separate sections. Shared rows use 20-unit horizontal and 8-unit vertical padding, a 24-unit number badge, and a 14-unit badge-to-title gap. Forms and main content scroll; the composer remains open for consecutive entries.

The trip footer uses three equal columns. Its source switches to stacked label/value rows when available width is below 320 logical pixels or scaled 14-unit text exceeds 17. The shell switches from its 76-unit bottom NavigationBar to a labeled NavigationRail at 840 logical pixels; this retained width adaptation does not enable Android landscape. Profile has earlier native emulator evidence at larger text; the footer's large-text stack remains a source-defined adaptation without a native capture.

Buttons and icon buttons have theme minimum targets of 48 units; the primary button minimum height is 56. Preserve visible labels, app-bar tooltips, safe areas, and keyboard bottom insets. Generated native captures are local evidence in the ignored `.impeccable/review/` directory and are not published with this repository. Native review evidence covers a physical API 36 Android phone at 720 × 1640: Today (`.impeccable/review/native-v3-today.png`), Recurring (`.impeccable/review/native-v3-recurring.png`), collapsed groups (`.impeccable/review/native-v3-collapsed.png`), notes (`.impeccable/review/native-v3-notes.png`), consecutive entry (`.impeccable/review/native-v3-continuous.png`), feedback (`.impeccable/review/native-v3-feedback.png`), and dismissed feedback (`.impeccable/review/native-v3-feedback-dismissed.png`). The notes editor (`.impeccable/review/native-v3-notes-large.png`) and Recurring (`.impeccable/review/native-v3-recurring-large.png`) also have captures at 1.3 text scale after restart; the scale was restored to 1.0. Final focused-label recaptures of the composer (`.impeccable/review/native-v3-composer.png`) and Notes (`.impeccable/review/native-v3-notes-focused.png`) establish the readable-blue role. The earlier time-sheet capture (`.impeccable/review/native-time.png`) covers an unchanged pattern. The historical illustrated-map capture (`.impeccable/review/native-map.png`) is superseded by the native map evidence below. TalkBack, predictive Back, and frame-rate performance remain unverified.

## Elevation & Depth

Custom page surfaces are flat. Outlines, filled fields, selected tints, and spacing carry structure. App bars disable scrolled-under elevation and surface tint; navigation also disables surface tint. Floating snackbars use Material elevation 1. There is no authored custom shadow; native sheets, menus, chips, and Material interaction overlays retain framework behavior where unspecified. Shared motion is recorded with the affected components below and in the sidecar.

**The Quiet Surface Rule.** Separate resting content with tone, spacing, and subtle outlines; keep the shared errand containers free of custom shadows.

## Shapes

Fields, primary actions, enclosing groups, and sheet tops use the frontmatter radius hierarchy. Shared groups clip their interactive children. Sheets round their top corners; numbered badges are circles. The grouped trip footer inherits the enclosing route surface's clipped lower corners rather than creating three independent tiles. Quiet one-unit outlines frame and divide content.

## Components

### Buttons

FilledButton is the Cornflower anchor with dark content, zero authored elevation, and the frontmatter minimum height and radius. Text and icon buttons use readable blue or supporting-text roles. Preserve native pressed, hovered, focused, and disabled states. Today disables **Plan my day** when empty; the enabled action opens **Review your day**. Review uses **Find your way** as its placeholder action for both pinned and incomplete drafts. It currently saves locally with existing guards; it does not start a trip, tracking or route calculation.

### Cards / Containers

The shared white outlined surface groups related content in Today, Recurring, and group editing. Individual errands remain compact rows. Today contains editable From/To endpoints with labeled **Map** buttons, a collapsible list, and the grouped Leave/Home by/Travel footer. A populated list shows up to five errands, with **Show all** for longer lists. Recurring groups start collapsed; their headers toggle contents while retaining the group name and repeat description; expanded content contains editable rows and **Add to Today**. Rows with nonempty notes show a readable-blue note icon (16 units) with the semantic label **Has notes**; the note body stays out of the compact list.

New workspaces begin with an empty day; existing saved work is preserved. The inline Today prompt uses supporting-color `body` text, left-aligned within 20-unit horizontal and 8/4-unit top/bottom padding. Clear appears as a labeled action with Undo when errands exist. Today and Settings expose no example-day loading action.

### Inputs / Fields

Fields have a quiet fill, no resting stroke, and a readable-blue focus stroke (1.5 units). Floating labels use readable blue when focused, supporting text when resting, and the generated error role for errors. The errand title accepts one to three lines. Quick add reveals one field and **Done adding**; submit adds an Anytime errand, clears the field, and keeps its state and keyboard focus for another entry. The composer follows the growing list to remain visible. Tapping a row opens the shared draft editor. Save validates and commits; system Back discards the draft. Delete and clear actions expose Undo where implemented.

### Errand notes

The focused editor contains a labeled **Notes (optional)** multiline field with a four-line minimum that grows with its content. It uses the shared field treatment and scrollable form. Notes are plain text, can be cleared, and save with the errand draft. Recurring copies carry notes independently into Today; neither later edit rewrites the other. Committed errands, notes, recurring lists, and saved places persist in the local Drift/SQLite workspace. Editor drafts require Save; notes do not implement interactive shopping checklists.

### List motion and disclosure

[Shared motion](apps/mobile/lib/core/widgets/motion.dart) uses a short entry duration (260 ms), a shorter exit duration (180 ms), and `easeOutCubic`. Rows combine size and fade transitions for insertion/removal. Today, saved-group contents, repeat details, and the composer use state-preserving size disclosure; disclosure reverses with `easeInCubic`. Chevron rotation uses the shared entry duration and curve. Disclosure can reverse during a transition, and collapsed contents leave focus and semantics traversal. The platform's Remove animations preference makes these spatial transitions immediate. These are source-defined behaviors, not a measured frame-rate claim.

### In-app feedback

[Shared feedback](apps/mobile/lib/core/widgets/feedback.dart) uses a floating Material snackbar: pale-blue fill, readable-blue text and Undo, a status or advisory icon (20 units), the shared button radius, side insets (20 units), bottom inset (12 units), and Material elevation 1. Status icons are excluded from semantics because the message carries the information. A new message replaces the current one. Ordinary messages expire after four seconds; Undo messages expire after six seconds under ordinary navigation. When accessible navigation is requested, actionable messages persist. Entry and dismissal use the shared motion durations. These messages are in-app confirmations; Android reminders and system notifications remain unimplemented.

### Time entry

[The time sheet](apps/mobile/lib/core/widgets/time_entry_sheet.dart) uses two centered numeric fields, AM/PM segments, and action chips for 8:00 AM, 12:00 PM, and 6:00 PM. Hour accepts 1–12 and minute accepts 00–59. The sheet scrolls and adds keyboard insets. Chips and segments retain Material shape and state behavior. **Save time** commits; dismissal cancels.

### Place entry

[The place screen](apps/mobile/lib/features/places/presentation/place_picker.dart) is a pushed search page shared by endpoints and errand locations; the former shared path is a compatibility export. **Search places or landmarks** uses the shared filled-field treatment above a scrollable list of saved places and catalog results. Compact Material result rows show names, addresses or an explicit missing-address qualifier, with quiet dividers. Search starts after two characters with a 350 ms debounce; requests have a five-second bound and stale results are ignored. Loading, no matches in the pilot area, unavailable search and **Retry search** are explicit. **Choose on map** remains available below the list. A result opens the full-map confirmation screen with its mapped name and position; a saved place with coordinates can return directly. Saved names without coordinates visibly need a pin.

The pin screen puts geography above a compact, scrollable confirmation area capped at 26% of screen height, followed by a safe-area **Confirm location** action and optional **Save to my places** icon. Coordinates are supporting, read-only text. No custom-name or coordinate-entry form is exposed. Moving the map beneath the fixed pin looks up the mapped place. A unique containing area, or otherwise a unique mapped point within 10 metres, supplies the title. Ambiguous/nearby results appear as quiet place buttons for explicit choice. Unknown selections remain **Dropped pin**. No match verifies an entrance. Save to my places explicitly persists a reusable local place separately from returning the selected location.

**Use my location** requests a single foreground fix only after a tap, including the search-page control that opens the map. The whole UI wait is bounded to 12 seconds. **Cancel location**, touching the map, leaving the screen, or a newer attempt abandons the pending result. Busy, accuracy, denial/service/timeout and cancellation feedback keep manual selection available. No location history or streaming is implied.

Catalog results come from an explicitly configured local development API and real imported OSM data, not generated examples. Verified local PostgreSQL/PostGIS now supplies 13,033 records by default; file snapshot mode remains an explicit development option. M2-03 runtime checks are complete. This backend change does not alter the visual system. Pilot coverage remains incomplete, and hours and entrances remain unverified. This records a search interface, not NLP changes, branch recommendations or completion of M2.

### Map surfaces

[The shared map](apps/mobile/lib/features/maps/presentation/place_map.dart) uses provider geography, readable-blue circular itinerary pins, white pin outlines and labels, and visible OpenFreeMap/OpenMapTiles/OpenStreetMap credits. Native attribution remains available on the interactive map. The full-map chooser expands into available height and overlays a fixed readable-blue center pin; the review overview retains its 200-unit height. These are local surface dimensions, not a new shared spacing scale. The overview ignores pointer input so its parent itinerary can scroll; **Explore map** opens the interactive full map with native Back. Map content has its own pan/zoom behavior, with rotation and tilt disabled. Android uses TextureView composition to retain Flutter overlays; camera refocusing follows explicit focus changes. There are no route lines, arrival times, checked-hours claims, or recommendation badges.

Loading shows a quiet status strip over the map. After 15 seconds without initialization, or a map update error, **Map unavailable or slow** and **Retry** keep failure explicit. Saved places and a return to search remain available; manual map selection does not depend on the catalog, but uncached map tiles still require connectivity. The style is selected through `WAYDAY_MAP_STYLE`, defaulting to the public Liberty style; public tiles have no availability guarantee. Basemap colors, fonts and geography are external content, not new Wayday primitives. The documentation panel must not fabricate an interactive map or substitute decorative roads for native map evidence.

Current native emulator captures are `.impeccable/review/native-m2-search-phone.png`, `native-m2-pin-phone.png`, `native-m2-pin-large-text.png`, and `native-m2-portrait-lock.png` in that directory. They show the PLP search, loaded real tiles, full-map confirmation, 1.3 text scale and retained portrait under device rotation. Manual map selection and simulated GPS/cancellation were exercised. These checks do not establish physical GPS accuracy, TalkBack or frame-rate performance.

### Manual day review

[The review](apps/mobile/lib/features/review/presentation/day_review_view.dart) uses one 560-unit column with 20-unit side insets, a compact date/travel/count line, stop-map overview, visible limits on unchecked travel times and hours, and a vertical departure/numbered-visits/destination sequence. It keeps the established Figtree hierarchy and quiet dividing line; review badges are 28-unit circles within a 40-unit spine. Visit titles and place labels wrap. Each stop exposes its place, timing rule, visit duration with an **assumed** qualifier where applicable, required/optional status, and any missing-pin message. Departure and final deadline are constraints, not arrival predictions.

Titles open the focused details editor; place rows open the shared chooser. A 48-unit drag handle reorders visits, while **Options** offers **Move earlier**, **Move later**, priority changes, and **Edit details** as a tap alternative. Prerequisite conflicts are explained without silently removing stops. Native ReorderableListView and pushed pages retain framework behavior; do not infer new custom motion tokens or verified reduced-motion drag behavior from the shell's shared transitions.

The safe-area confirmation action stays outside the scrolling itinerary. Back cancels this independent review draft. Confirmation saves the reviewed order and fields into Today locally; the action is labeled **Find your way**, including when missing pins leave it as a draft. If Today changed while review was open, a visible message and **Reload Today** prevent a stale overwrite. This slice records manual review, not optimized scheduling, route calculation or an active trip. Full M2 catalog coverage and M3 recommendations remain separate gates.

Inspected API 36 Android emulator evidence includes `.impeccable/review/native-m2-final-{review,review-bottom,options,picker,large-text,landscape}.png`: real map data, letter/number pins, readable credits, focused labels, stop details and the anchored confirmation action. Final captures cover 1080 × 2400 portrait, 1.3 text scale and a scrolled 2400 × 1080 landscape list after the overview pointer fix. A cold restart retained the confirmed order and selected pins. Temporary test errands were removed and device display settings restored after verification. Physical GPS accuracy, TalkBack, predictive Back, provider outage and frame-rate performance remain unverified.

### Navigation and editing

[The shell](apps/mobile/lib/app/wayday_app.dart) has labeled Today, Recurring, Profile, and Settings destinations; the selected icon sits within a pale-blue indicator. [Module transitions](apps/mobile/lib/core/widgets/module_transition.dart), including Today's **Add from a recurring list**, keep shell navigation stationary while content enters with the shared 260 ms duration and 180 ms reverse duration. A horizontal slide starts at 0.025 of the content width and uses `easeOutCubic`; opacity follows an interval from 0.15 to 1 with the same curve. Remove animations returns the destination immediately with zero transition duration. This describes the implementation, not measured frame-rate performance.

Shared pushed editors keep native Back and visible Save actions. Recurring supports named lists, direct item editing, independent group drafts, deletion with Undo, and manual copying to Today. Repeat controls expand within the group editor and describe metadata only. [Settings](apps/mobile/lib/app/settings_view.dart) explains local storage, Asia/Manila trip times, and current feature limits; it has no appearance controls or example loader.

### Sample Profile

[Profile](apps/mobile/lib/features/profile/presentation/profile_view.dart) is a scrollable, read-only sample named **Jace Bellen**. A 68-unit circular initials avatar and title-sized name precede a white outlined personal-details group. Email, Phone number, and Home area each say **Not added**; the screen offers no editing or authentication. A plain sharing explanation says live sharing is not connected and nothing is shared from this preview. The sample is not a live account or published identity.

Native emulator captures for this refinement are `.impeccable/review/native-v5-{today-empty,recurring,profile,settings,profile-large-text,profile-landscape,profile-landscape-bottom}.png`: Pixel 6 API 36 at 1080 × 2400 portrait and 2400 × 1080 landscape, with Profile also captured at 1.3 text scale. These supplement the earlier physical-device captures of unchanged components above. Physical-device frame rate, TalkBack, and predictive Back remain unverified.

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
- **Do** keep map credits visible, explain missing pins and unavailable data, and retain map selection and saved-place alternatives when search fails.
- **Do** pair visit dragging with labeled move controls and distinguish saving a reviewed itinerary from calculated travel or tracking.
- **Do** preserve historical Asikaso references and attribution.

### Don't:

- **Don't** reintroduce palette selectors, device-following appearance, or dark-mode controls in this MVP.
- **Don't** use Cornflower as small action text on white; use the readable link role.
- **Don't** turn each compact errand row into a permanent form or separate card.
- **Don't** invent map geometry, business results, route lines, checked hours, or arrival estimates when services have not supplied them.
- **Don't** imply that unsaved editor drafts survive restart or that repeat metadata schedules automatic additions.
- **Don't** treat native screenshots as verification of TalkBack, predictive Back, or performance.
