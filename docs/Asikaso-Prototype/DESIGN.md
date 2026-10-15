---
name: Asikaso
description: A day-of-errands planner in the category standard; calm note in, map and sheet out.
colors:
  paper: "#FFFFFF"
  warm-surface: "#F6F6F4"
  warm-surface-pressed: "#EDEDEA"
  ink: "#191919"
  ink-soft: "#3F3F3D"
  muted: "#6B6B68"
  hairline: "#E7E7E4"
  hairline-strong: "#D9D9D5"
  route-blue: "#2F5CFF"
  route-blue-ink: "#2448D8"
  route-blue-wash: "#ECF0FF"
  fits-green: "#1A7F4B"
  fits-green-wash: "#E6F3EB"
  tight-amber: "#9A5B00"
  tight-amber-wash: "#FFF3DD"
  late-red: "#C2302F"
  late-red-wash: "#FCEBEA"
  tight-amber-signal: "#E19A1C"
  control-off: "#8E8D88"
  stroke-add: "#B9B8B2"
  map-ground: "#EFEEEA"
  map-road: "#FFFFFF"
  map-edge: "#E0DED8"
  map-water: "#D3DFE8"
  map-park: "#E2EADB"
  map-label: "#7A7973"
typography:
  display:
    fontFamily: "Figtree, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "26px"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "-0.02em"
  headline:
    fontFamily: "Figtree, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "20px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.01em"
  headline-trip:
    fontFamily: "Figtree, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.015em"
  sheet-title:
    fontFamily: "Figtree, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "18px"
    fontWeight: 700
    lineHeight: 1.25
  title:
    fontFamily: "Figtree, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.25
  body:
    fontFamily: "Figtree, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.4
  body-sm:
    fontFamily: "Figtree, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.4
  note:
    fontFamily: "Figtree, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "15.5px"
    fontWeight: 400
    lineHeight: 1.7
  label:
    fontFamily: "Figtree, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "13px"
    fontWeight: 600
    lineHeight: 1.4
  caption:
    fontFamily: "Figtree, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "12.5px"
    fontWeight: 500
    lineHeight: 1
    fontFeature: "\"tnum\" 1"
  numeral:
    fontFamily: "Figtree, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "11.5px"
    fontWeight: 700
    lineHeight: 1
    fontFeature: "\"tnum\" 1"
rounded:
  tag: "6px"
  chip: "7px"
  thumb: "8px"
  choice: "9px"
  field: "10px"
  card: "12px"
  float: "14px"
  sheet: "18px"
  pill: "999px"
spacing:
  hair: "4px"
  xs: "6px"
  sm: "8px"
  row: "12px"
  inset: "14px"
  md: "16px"
  gutter: "20px"
  section: "22px"
components:
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    rounded: "{rounded.card}"
    height: "50px"
    typography: "{typography.title}"
  button-secondary:
    backgroundColor: "{colors.warm-surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.card}"
    height: "50px"
  button-secondary-hover:
    backgroundColor: "{colors.warm-surface-pressed}"
  button-small:
    backgroundColor: "{colors.warm-surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.choice}"
    height: "36px"
    padding: "0 12px"
  button-clear:
    textColor: "{colors.ink-soft}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.field}"
    height: "38px"
    padding: "0 10px"
  button-clear-hover:
    backgroundColor: "{colors.warm-surface}"
    textColor: "{colors.ink}"
  icon-button:
    backgroundColor: "{colors.warm-surface}"
    textColor: "{colors.ink-soft}"
    rounded: "{rounded.pill}"
    size: "34px"
  route-card:
    backgroundColor: "{colors.paper}"
    rounded: "{rounded.card}"
    padding: "12px 14px"
  notepad:
    backgroundColor: "{colors.warm-surface}"
    textColor: "{colors.ink}"
    typography: "{typography.note}"
    rounded: "{rounded.field}"
    padding: "10px 12px"
  readout-chip:
    backgroundColor: "{colors.warm-surface}"
    textColor: "{colors.ink-soft}"
    rounded: "{rounded.chip}"
    padding: "5px 6px"
  readout-chip-fixed:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
  readout-chip-review:
    backgroundColor: "{colors.tight-amber-wash}"
    textColor: "{colors.tight-amber}"
  tag:
    backgroundColor: "{colors.warm-surface}"
    textColor: "{colors.ink-soft}"
    typography: "{typography.caption}"
    rounded: "{rounded.tag}"
    padding: "3px 7px"
  tag-warn:
    backgroundColor: "{colors.tight-amber-wash}"
    textColor: "{colors.tight-amber}"
    rounded: "{rounded.tag}"
  errand-accordion:
    backgroundColor: "{colors.paper}"
    rounded: "{rounded.field}"
    padding: "11px 12px"
  number-badge:
    backgroundColor: "{colors.warm-surface}"
    textColor: "{colors.ink-soft}"
    typography: "{typography.numeral}"
    rounded: "{rounded.pill}"
    size: "20px"
  add-slot:
    textColor: "{colors.ink-soft}"
    rounded: "{rounded.field}"
    height: "44px"
  segmented:
    backgroundColor: "{colors.warm-surface}"
    textColor: "{colors.muted}"
    rounded: "{rounded.field}"
    padding: "3px"
  segmented-selected:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.thumb}"
  choice-chip:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink-soft}"
    rounded: "{rounded.choice}"
    height: "34px"
    padding: "0 12px"
  choice-chip-selected:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
  text-input:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.field}"
    height: "44px"
    padding: "0 12px"
  toggle-off:
    backgroundColor: "{colors.control-off}"
    rounded: "{rounded.pill}"
    width: "44px"
    height: "26px"
  toggle-on:
    backgroundColor: "{colors.ink}"
  timeline-node:
    backgroundColor: "{colors.route-blue}"
    textColor: "{colors.paper}"
    rounded: "{rounded.pill}"
    size: "24px"
  sheet:
    backgroundColor: "{colors.paper}"
    rounded: "{rounded.sheet}"
    padding: "0 20px"
  toast:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    rounded: "{rounded.card}"
    padding: "12px 14px"
  tab-bar:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.muted}"
    height: "78px"
---

# Design System: Asikaso

## Overview

**Creative North Star: "The Quiet Errand Sheet"**

Asikaso looks like the apps it sits next to on a phone: a Notion-calm note surface for writing the day, and a Maps/Life360 map-plus-sheet for reading the plan. It is the category standard executed at full craft, not a themed world. White paper, warm-gray wells, near-black ink, one route blue, and state color only where the plan has something true to say (fits, tight, didn't fit).

Density is comfortable phone density: 20px screen gutters, 12-14px row padding, hairline-divided lists rather than stacked cards. Hierarchy comes from weight and ink depth (ink, ink-soft, muted) far more than from size or color. Filled black is the language of "chosen" and "commit": the primary button, the selected choice chip, the on toggle, the fixed-time chip. Blue is the language of "where you are going": the route line, its numbered pins and timeline nodes, the branch radio, links, focus and caret.

The user rejected decorative worlds twice before landing here; the visual stance is "simple, little color", and the look is never derived from the app's name.

**Key Characteristics:**
- White ground, warm-gray wells, hairline dividers; no tinted backgrounds beyond state washes.
- One blue for route and wayfinding; black for selection and commitment.
- Figtree throughout, tabular numerals on every time, count and duration.
- Map on top, sheet rising over it; sheets carry the content, floating layers carry the only real shadows.
- Drawn single-stroke line icons (1.75 stroke, 24 grid, round caps and joins).

## Colors

A near-monochrome warm-neutral palette with a single cobalt route blue and three quiet state hues.

### Primary
- **Route Blue** (`route-blue`): the route line on the map, numbered stop pins, timeline stop nodes, the selected branch radio, the map picker pin, focus outline and text caret. It means "the path".
- **Route Blue Ink** (`route-blue-ink`): blue when it is text: "Map", "Change" links on stops and rows. Darker for legibility at 13-14px.
- **Route Blue Wash** (`route-blue-wash`): text selection, focus halo around inputs and the notepad, the accent tag.

### Tertiary (state)
- **Fits Green** (`fits-green`) with **Fits Wash** (`fits-green-wash`): "Kasya lahat" status dot, finished timeline nodes, the done badge, positive tags.
- **Tight Amber** (`tight-amber`) with **Tight Wash** (`tight-amber-wash`): warning line above the plan button, read-out chips and errand rows that need review ("Needs a place").
- **Tight Amber Signal** (`tight-amber-signal`): the bright amber fill of the "tight" status dot only. The deep `tight-amber` reads brown as a 10px dot; the signal amber fails as text, so it never carries words. Green and red dots use their text tokens.
- **Late Red** (`late-red`) with **Late Wash** (`late-red-wash`): didn't-fit status dot, conflict callouts, destructive "Delete" text.

### Neutral
- **Paper** (`paper`): every screen, card, sheet and input ground.
- **Warm Surface** (`warm-surface`): wells: notepad, segmented track, secondary buttons, read-out chips, tags, icon tiles, count pills.
- **Warm Surface Pressed** (`warm-surface-pressed`): hover/pressed state of warm-surface controls; shimmer highlight while chips are being read.
- **Ink** (`ink`): text, primary buttons, selected chips, on toggles, fixed-time chips, home pin, toast.
- **Ink Soft** (`ink-soft`): secondary text, icon color, unselected choice text.
- **Muted** (`muted`): labels, sub-lines, inactive tabs, legs and durations.
- **Hairline** (`hairline`) and **Hairline Strong** (`hairline-strong`): list dividers and card borders; strong for input and choice-chip strokes, scrollbar thumbs, sheet grab handle.
- **Add Stroke** (`stroke-add`): the 1.5px dashed border of "Add errand" slots (Pick mode and the template editor). Darker than the hairlines so an empty slot still reads as a target.
- **Control Off** (`control-off`): the off track of toggles; dark enough to hold 3:1 against paper so "off" is visible, not absent.
- **Map palette** (`map-ground`, `map-road`, `map-edge`, `map-water`, `map-park`, `map-label`): a desaturated Google-Maps-like base so the blue route is the only saturated thing on the map.

### Named Rules
**The Blue Is the Route Rule.** Route Blue marks wayfinding only: route, pins, stop nodes, branch choice, links, focus. It never fills a button or a selected chip.

**The Black Means Chosen Rule.** Selection and commitment are filled ink (`ink` on `paper` text): primary button, selected choice, on toggle, fixed time. A second "selected" color is not introduced.

**The State Earns Color Rule.** Green, amber and red appear only when the plan reports fit, tightness or failure. Categories, errand types and decoration never get a color.

## Typography

**Display Font:** Figtree (with system-ui, -apple-system, Segoe UI, Roboto, sans-serif)
**Body Font:** Figtree (same stack)

**Character:** One workhorse geometric-humanist sans in four weights (400/500/600/700), the way Maps and Notion use one family. Weight and ink depth do the work; size steps are small.

### Hierarchy
- **Display** (700, 26px, 1.15, -0.02em): screen titles ("Today", "Recurring", "Settings") and the done-screen heading.
- **Headline Trip** (700, 24px, -0.015em): the current leg's destination on the trip screen.
- **Headline** (700, 20px, -0.01em): the one-sentence plan verdict ("Kasya lahat.") beside its state dot.
- **Sheet Title** (700, 18px): bottom-sheet headings.
- **Title** (600-700, 16-17px): section heads (17/600), template names (16.5/600), picked place (17/700), button labels (16/600), stop names (15.5/600).
- **Body** (400, 15px, 1.4): default text; list item names step to 500 weight. Values in the route card are 15/600.
- **Body Small** (400-500, 14px): secondary sentences, segmented and choice labels, the Clear button, toast text, list end values. The most-used size after labels.
- **Note** (400, 15.5px, 1.7): the notepad only; the loose leading makes it read like writing, not a form.
- **Label** (600, 13px, muted, sentence case): field labels, group heads, the read-out header, "Templates" lead-in. 12.5px for trip-meta and leg-fact labels.
- **Caption** (500, 12.5px, tabular): chips, tags, count pills, timeline sub-durations. Tab labels are 12/500.
- **Numeral** (700, 11.5px, tabular): numbers inside 20px round badges (read-out rows, errand accordions, template lists).

Exceptions, not roles: 11px/700 white numerals inside map pins and 9px/600 tracked map labels belong to the drawn map only; the 22px heading in the desktop presentation frame's side note is not part of the app.

### Named Rules
**The Tabular Time Rule.** Every clock time, duration, count and stop number uses tabular numerals so columns of times align on the timeline.

**The Sentence Case Rule.** Labels and group heads are sentence case at 13px/600 in muted ink. No uppercase tracked labels in the UI; the only tracked caps are street and district names drawn on the map itself, as a map convention.

## Layout

A single phone column (390px reference). Screens stack: 44px status bar, a scrolling body, an optional footer holding one full-width primary button (with a white fade above it), and a 78px tab bar (Today, Recurring, Settings).

- **Gutters:** 20px screen padding on every list, card and footer. Card internals 12px vertical, 14px horizontal.
- **Rhythm:** a 4/6/8/12/16/22 step set. 4-6px between chips, 8px between buttons and stacked controls, 12px row padding, 16px between blocks, 22px above section heads.
- **Lists over cards:** content is hairline-divided rows inside one bordered container or bare on paper; nested cards are avoided. Template errands in the editor are the exception: each errand is a bordered accordion.
- **Map + sheet:** map screens give the map the top 47% (38% on the trip screen) and raise a sheet that overlaps it by 18px.
- **Presentation frame:** above 760px the phone is shown in a device frame beside a short description; at or below 760px the app fills the viewport. The frame is presentation-only and outside the system: its 44px bezel radius, `#151515`/`#2a2a2a` bezel rings, `0 30px 80px rgba(0,0,0,.28)` drop shadow, `#E7E6E2` backdrop, 22px side-note heading and the simulated status-bar glyphs (1-3px radii) must not be reused in app surfaces.

## Elevation & Depth

Flat at rest. Content surfaces are paper on paper, separated by hairlines and warm-gray wells. Shadows belong to things that float over the map or over content: sheets, the map search card, map buttons. Two in-control micro-lifts (segmented thumb, toggle knob) give the moving part of a control a physical edge.

### Shadow Vocabulary
- **Float** (`box-shadow: 0 1px 2px rgba(25,25,25,.06), 0 8px 24px rgba(25,25,25,.10)`): map buttons and the place-picker search card.
- **Sheet over map** (`box-shadow: 0 -6px 24px rgba(0,0,0,.08)`): the plan sheet and the place-picker bottom panel (.10 there).
- **Modal sheet** (`box-shadow: 0 -10px 40px rgba(0,0,0,.12)`): bottom sheets over a 32% ink scrim.
- **Segmented thumb** (`box-shadow: 0 1px 2px rgba(0,0,0,.08), 0 0 0 1px #E7E7E4`): the selected segment.
- **Toggle knob** (`box-shadow: 0 1px 2px rgba(0,0,0,.2)`).

### Named Rules
**The Only Floaters Cast Rule.** If it does not sit over the map or over other content, it has no shadow. Route card, rows, chips and buttons are flat.

## Shapes

Gently rounded, nested by size: the bigger the container, the larger the radius. Tags 6px, chips 7px, segmented thumb 8px, choice chips and small buttons 9px, inputs, notepad, segmented track and icon tiles 10px, cards, buttons and toast 12px, the floating map search card 14px, sheets 18px on the top corners only. Fully round (`pill`) for icon buttons (34px), map buttons (40px), stop nodes (24px), number badges (20px), toggles (26px tall), the done badge (52px), the grab handle (4px) and scrollbar thumbs (6px). The code writes these as half the element's size (2, 3, 10, 12, 13, 17, 20, 26px); those literals are the pill role, not extra radius steps, and new round elements should use half their height or 999px.

Borders are 1px hairlines; input and choice strokes use the stronger hairline. A dashed 1.5px `stroke-add` border means "add" (Add errand). A 2px dotted vertical rail inside the route card joins From, Errands and To (a component-local `#C4C3BD`, kept as a one-off of the route card rather than a palette token); the plan timeline uses a solid 2px hairline rail.

## Components

### Buttons
Quiet, full-width, one per screen footer.
- **Shape:** 12px radius, 50px tall, 16px/600 label, optional leading line icon.
- **Primary:** ink fill, white text; hover goes to pure black; press scales to 0.985.
- **Secondary:** warm-surface fill, ink text; hover to warm-surface-pressed. Destructive variant keeps the secondary fill with late-red text.
- **Small:** 36px, 9px radius, 14px text, auto width; used for unfit actions and template actions.
- **Ghost:** no fill, ink-soft text, 44px. Destructive ghost ("Remove errand") uses late-red text.
- **Clear (tool ghost):** 38px, 10px radius, body-small 500 in ink-soft with a leading x icon; hover fills warm-surface with ink text; disabled at 40% when there is nothing to clear. Destructive-in-bulk actions like this always pair with a toast Undo rather than a confirm dialog.
- **Icon button:** 34px warm-surface circle (close, back, add).
- **Disabled:** 45% opacity.

### Chips (read-out chips and tags)
- **Read-out chip:** warm-surface, ink-soft, 12.5px, 7px radius, 14px leading icon. Variants: fixed time (ink fill, white, lock icon), needs review (amber wash, amber text, tappable), soft (transparent with a hairline-strong inset stroke).
- **Tag:** 12.5px/500, 6px radius, used on timeline stops, errand accordions and template rows (warm-surface default, green wash for fits, ink for "Fixed", blue wash for accent, amber wash with amber text for "Needs a place"). Tags carry plain words ("Any branch", "Before 4:00 PM", "11:00–2:00 PM"), optionally with a 13px icon.
- **Reading state:** while the AI reads, chips become shimmering warm-surface bars (1s linear); when they land they fade up from a 4px blur over 0.45s.

### Choice chips
- **Style:** 34px tall, 9px radius, paper fill, hairline-strong stroke, 14px/500 ink-soft. Hover darkens the stroke to ink-soft.
- **Selected:** ink fill and stroke, white text. Used for durations, weekdays (7-column grid), saved places and template quick-adds (with a count).

### Segmented control
- Warm-surface track, 10px radius, 3px padding; segments 14px/500 muted. Selected segment is a paper thumb (8px) with the segmented-thumb shadow and ink text. Used for Write/Pick, place kind, timing, priority and repeat cadence.

### Inputs / Fields
- **Text input / select:** 44px (40px inside Advanced), paper fill, 1px hairline-strong, 10px radius, 15px text, drawn chevron for selects.
- **Focus:** stroke turns route blue with a 3px route-blue-wash halo. Global focus-visible is a 2px route blue outline at 2px offset.
- **Field:** 13px/600 muted label above, 12px vertical padding, hairline between fields.

### Toggles and radios
- **Toggle:** 44x26 pill, `control-off` track when off, ink on, white 20px knob sliding 18px.
- **Radio (branch):** 20px circle; selected becomes a 6px route-blue ring.

### Navigation
- **Tab bar:** 78px, hairline top, three tabs of icon over 12px/500 label. Inactive muted; active ink with the icon stroke thickened to 2.1.
- **Back on map screens:** 40px round paper map button with the float shadow.

### Route card (signature)
The Today screen's single bordered container (1px hairline, 12px radius) reading top to bottom: From row (ring icon, label over 15/600 value, blue "Map" link), the Errands section (list icon, title with count pill, muted summary, chevron) joined to From and To by a dotted rail, the To row, then a three-column Leave / Home by / Travel strip split by hairlines. Rows hover to `#FAFAF8`.

### Notepad and read-out (signature)
The Errands body opens with a tools row: the Write/Pick segmented control filling the width beside the Clear button. Below it, shared by both modes, a horizontal template bar ("Templates" label, then choice chips with a plus icon and an item count). Write mode then shows the warm-surface notepad (min 148px, no border, blue inset focus ring), and below it "Asikaso understood" with a sparkle icon and a ready count, then one numbered row per line: a 20px warm-surface number badge, the errand name at 14.5/500, and its chips.

### Pick mode
Pick reuses the template editor's errand accordion on today's errands: a stack of 10px-radius hairline-bordered rows, each a 20px number badge, the errand name (500, ellipsized), one plain tag, and a chevron. Only an expanded row shows fields, and only there does the Flexible / Fixed / Closing segmented switch appear, with a one-line muted description under it. A dashed "Add errand" slot closes the list.

### Advanced settings accordion
A hairline-topped 14/600 ink-soft toggle with a sliders icon and a rotating chevron (0.25s). Inside, each errand is a hairline-separated row that expands to its fields (what, where, when, how long, priority, order) with slightly compacted controls (32px choices, 40px inputs, 13.5px segments).

### Sheets
Bottom sheets rise over a 32% ink scrim in 0.34s, 18px top radius, 36x4 grab handle, 18/700 title with a round close button, scrolling body, footer row of buttons. Max 88% height.

### Toast with undo
Ink pill-card (12px radius) floating 16px from the edges above the footer, 14px white text, underlined white "Undo" on the right. Slides up 16px and fades in over 0.3s.

### Map
A drawn, desaturated street map: warm ground, white roads with a darker edge stroke, a grid of faint minor streets, blue-gray river, green parks, tracked uppercase district labels haloed in ground color. The route follows the street grid: each leg turns once, choosing the turn that minimizes self-crossings, drawn as a 4px route-blue line over an 8px white casing, animated in over 1.1s. Stops within 32px merge into one pill pin labeled "1·2". Pins are route-blue pills with a 2.5px white stroke; when a stop is active, others dim to blue-gray and the active pin gets a blue halo. Home is an ink rounded square with a white house icon; the start is a white ring with an ink stroke.

### Timeline
Three columns: right-aligned time (13.5/600 with muted duration), a rail with 24px numbered route-blue nodes (ink for the end, green when done, each with a 3px paper ring), and the stop body (name, place with blue "Change" link, tags). Leg rows between stops show mode and minutes in muted 13px with a warm-surface "Free" tag.

### Template list and editor
Template rows (Recurring screen): 36px warm-surface icon tile, 16.5/600 name with muted schedule, an indented numbered errand list, and small action buttons. The editor sheet: name input, repeat segmented control, weekday choice grid, next-date line, then each errand as the same bordered errand accordion used by Pick mode, with its type tag; a dashed "Add errand" slot closes the list. Footer pairs a destructive secondary Delete with the primary Save.

## Do's and Don'ts

### Do:
- **Do** keep Route Blue for the route, pins, stop nodes, branch choice, links and focus only.
- **Do** show selection and commitment as filled ink with white text.
- **Do** use state color only for fit (green), tight (amber, deep `#9A5B00` text) and didn't fit (red), each with its wash.
- **Do** set every time, duration, count and stop number in tabular numerals.
- **Do** draw icons as single-stroke line icons: 24 grid, 1.75 stroke, round caps and joins, currentColor.
- **Do** separate content with hairlines and warm-gray wells; reserve shadows for layers floating over the map or content.
- **Do** keep labels sentence case at 13px/600 muted.
- **Do** keep the map desaturated so the blue route is the only saturated line on it.
- **Do** pair bulk destructive actions (Clear) with a toast Undo instead of a confirmation dialog.

### Don't:
- **Don't** fill buttons or selected chips with blue.
- **Don't** color-code errand categories or types.
- **Don't** add shadows to the route card, rows, chips or buttons.
- **Don't** introduce uppercase tracked labels or eyebrows above titles in the UI; tracked caps belong only to map place names.
- **Don't** use a second typeface; Figtree carries display through caption.
- **Don't** nest bordered cards inside bordered cards, except the errand accordions (Pick mode and the template editor).
- **Don't** reuse the desktop presentation frame's bezel colors, 44px radius or drop shadow in app surfaces.

## V2 refinement, 2026-10-14

`V2.html` preserves this visual system. For V2, the interaction specifications
for Notepad/read-out, Pick mode, Advanced settings, and the template editor above
are replaced by [V2-NOTES.md](V2-NOTES.md). The original `asikaso.html` remains as
described above.

V2 uses hairline-separated numbered rows (48px minimum), one concise neutral
tag per row, a 44px Add errand action and an inline one-sentence composer.
Focused full-screen editors use the same typeface, surfaces, controls and spacing:
20px title, 20px gutters, a title field, collapsed Where/When/More options
properties, and a pinned Save action. Property summaries are at least 68px high;
primary interactive controls in the new flows are at least 44px high. Circular
number badges and back buttons use half-height radii as already permitted.
Lists wrap long names rather than truncating essential errand text.
