# Asikaso V2

`asikaso.html` is the original baseline. Its SHA-256 is
`403ea137f839134693e7eba49f7d4728d1d3e5d89a971381a3b6057f8617afab`.
It was copied before changes; all prototype changes in this iteration are in `V2.html`.
Open either file directly in a desktop browser to compare them.
For a restricted local HTTP preview, run `python preview_v2.py` from this folder
and open `http://127.0.0.1:8766/V2.html`; stop the server with Ctrl+C.

## Owner direction, 2026-10-14

Focus on Today's planning input and Recurring. Retain From → Errands → To,
leave/home-by/travel settings, the existing map-plus-planner result, and the calm
white/gray/ink/Figtree identity. The owner wants Add errand → type → Save →
numbered list. They delegated the add flow decision, chose immediate group
addition from templates, and chose suitable branch suggestions with a specific
place override. These decisions supersede the V1 notepad/Write/Pick/Advanced
interaction descriptions for V2 only.

## V2 interaction decisions

- A single compact numbered list replaces the notepad, repeated interpretation
  chips, Write/Pick switch and inline long forms.
- Add errand reveals a short inline composer. Save or Enter adds the sentence
  directly; Cancel/Escape closes the composer. Title parsing suggests a category,
  time and default duration. Unknown places are visibly marked “Set a place.”
- Tap the Errands heading to collapse the entire list. Lists longer than five
  show five rows initially, with Show all/Show fewer. Adding a new individual
  errand expands the list so it is visible.
- Tap a numbered row to edit a draft on a focused screen. Where and When are
  property rows; opening one reveals its controls and closes the others.
- Where offers Any branch or Specific place. When offers Anytime, At a set time,
  Arrive by, and Finish before. Arrive by constrains arrival; Finish before
  constrains completion, including the stop buffer. A fixed start may have an
  optional end time; when provided, the time range sets the duration.
- More options holds duration, priority, and ordering. Save commits the draft;
  Back discards it. Editing the title does not reparse or erase its other rules.
  Circular ordering is rejected, as are missing time values and invalid ranges.
- Today's controls use plain language. In template-item timing controls the
  owner's Flexible/Fixed/Closing labels remain alongside plain descriptions.
- Recurring retains its card lists. Edit opens a full template screen with a
  collapsed schedule property, numbered errands, and the same Add flow.
  Individual item editing opens the shared focused editor and returns to the
  template draft. Save template commits the group.
- Add to today copies the whole group without a review step, retaining timing,
  priority and order. Already-added items are tracked individually to prevent
  duplicate addition. Editing Today's copies doesn't rewrite the template.
- Clear, remove and template deletion have Undo. Dialogs are inert while closed,
  contain keyboard focus while open, and restore focus on dismissal.
- Gym and vehicle-service categories have sample branches so the owner's four
  example errands can all be planned in this simulated prototype.

## Demo URLs

Append a hash when opening the file: `#example` (owner's four errands), `#empty`,
`#edit` (focused Today editor), `#template`, `#newtpl`, `#template-item`, `#stock`,
`#recurring`, `#plan`, `#late`, `#trip`, `#done`, `#from`, or `#settings`.
Deep links are read on page load; reload after changing the hash.

## Validation

Run `node docs/v2-planner-checks.cjs` from the project folder. It parses the
complete application and checks the original 5:30 PM sample result, optional
errand dropping, all four new examples, arrival versus completion deadlines,
large-plan deadline enforcement, and template rule round-tripping.

Browser checks cover quick add, focused editing, blank-deadline validation,
new template creation/save, adding a group to Today, and the original plan.
Screenshots are stored separately from V1 in `docs/screenshots/v2/`.

## Remaining prototype limits

Parsing and travel are simulated, places are a sample catalog, and settings
outside this iteration retain V1's placeholders. State is in memory and resets
on refresh. The plan screen's existing Move to tomorrow still lacks a deferred
queue. V2 is a design prototype, with larger plans using a heuristic.

## Inspiration

The design applies list items with focused properties, informed by
[Notion's database properties](https://www.notion.com/help/database-properties),
and preserves editable route endpoints/stops, informed by
[Google Maps directions](https://support.google.com/maps/answer/144339?co=GENIE.Platform%3DAndroid&hl=en-gb).
These are interaction references; no external assets are copied.
