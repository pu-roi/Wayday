# Android shell and Today

Mode: Operate. Build directly in Flutter. This is a constrained adaptation of V2, with its route structure and compact list preserved, rather than a new visual identity exercise.

## Direction contract

The first viewport must show Today, the date, route endpoints, a numbered errand list, trip settings, and a clear next action. The signature is the From/Errands/To route spine: tasks visibly belong between the endpoints. The supplied reference contributes generous spacing, quiet tinted surfaces, and a strong anchored action; its booking, payments, glass, and gradients are not product requirements.

Use one light Canvas/Cornflower theme for the MVP. The owner removed appearance choices and dark mode on 2026-10-16. Use Cornflower for primary actions with dark readable text, pale blue for quiet grouping, and a darker derived blue for links and icons. Keep the prior route composition and Figtree identity. Use Material controls and system Back, 48 dp targets, safe-area and keyboard insets, and large-text reflow.

New workspaces start empty with a compact left-aligned inline prompt. Preserve saved work and remove all example-day loading actions. Clear is a labeled action with Undo when errands exist. Quick add stays open for consecutive entries; each new errand defaults to Anytime. Put details in a focused editor. Group Leave/Home by/Travel in a single tinted footer inside the route surface. Replace the clock dial with a scrollable hour/minute entry sheet, AM/PM, validation, and quick choices. Committed edits persist locally under M1; draft cancellation is unchanged. Plan my day opens the [manual day review](mobile-review.md), where order, priority and places can change before saving locally. Find your way is the placeholder review action for both incomplete and fully pinned visits; it currently saves the draft locally. Back cancels review. Route calculation, checked hours and trip execution remain later milestones; never display invented routes or times.

## Motion, notes, and feedback

Keep quick add ready between entries: insert rows with a short size/fade transition while preserving field state, focus, and visibility. Use interruptible size disclosure for Today, Recurring group contents, and repeat details, with a coordinated chevron. Use 260 ms entry and 180 ms exit with deceleration; the platform's Remove animations setting makes spatial transitions immediate. Avoid decorative loops and new animation dependencies.

Optional free-form multiline notes belong in the focused errand editor, shared by Recurring and Today. A small note icon indicates details without showing the note body in compact rows. Copy notes independently into Today; keep draft cancellation and clearing notes functional. Notes are plain text, not an interactive shopping checklist.

In-app confirmations use a shared floating Material snackbar with pale-blue fill, readable blue text, and a restrained status icon. Replace old feedback rather than queueing it. Normal messages expire after four seconds and Undo messages after six; accessible navigation retains actionable messages. This does not implement Android reminder notifications.

## Boundaries

Recurring is implemented with local Drift/SQLite persistence: reusable named lists with the same compact rows and focused editor as Today, create/edit/delete, independent drafts requiring Save, and manual Add to Today. Committed errands, notes, recurring lists, and saved places persist locally. Copying retains timing/priority and source item identity to prevent duplicates. Editing a copy does not change the original list. Repeat settings are descriptive metadata; there is no automatic scheduling. Settings describes local storage, time zone and limitations without appearance controls. A fourth destination, Profile, shows the owner-selected Jace Bellen as an explicitly read-only sample; contact details are unset and no sharing or account is connected.

From, To, and errand-place entry open the shared [search and map chooser](mobile-places.md): search a familiar name, landmark or address, choose a saved place, or use Choose on map. Catalog results open a full-screen MapLibre/OpenFreeMap map with a fixed center pin and Confirm location; coordinates are read-only and no custom name is required. Moving the map resolves a supported mapped place name; ambiguous/nearby matches require a choice and unknown positions remain Dropped pin. No match verifies an entrance. Save to my places is a separate optional local save. Explicit one-time foreground location has a cancellable 12-second UI wait, and manual map touches abandon pending results. Existing labels without coordinates remain unresolved. Preserve native attribution, visible credits and honest load/Retry feedback. Search failure retains manual map and saved-place choices; uncached tiles still need connectivity. The local development API now defaults to verified PostgreSQL/PostGIS over imported OSM data; explicit file snapshot mode remains available. M2-03 is complete, while physical-location and coverage checks remain open. No recommendations, road routing or continuous location tracking is implemented. The whole Android app remains upright portrait through startup and manifest locks. No account, credentials or billing is used for this map display.

## Inspiration

- V2: route spine, numbered rows, and focused editing.
- User-supplied booking reference: spatial separation, soft surfaces, and clear primary action.
- [Google Maps](https://support.google.com/maps/answer/144339?co=GENIE.Platform%3DAndroid&hl=en): editable route endpoints and travel choice.
- [Notion](https://www.notion.com/help/database-properties): compact rows with details revealed only when editing.
- [Notion lists](https://www.notion.com/help/lists) and [Apple Notes organization](https://support.apple.com/en-il/guide/iphone/ipha61270292/ios): named collections, direct entry, and content-first lists. These inform information hierarchy, not imported assets or iOS controls on Android.
- [Angkas](https://www.angkas.com/services/passenger): focused pickup/destination flow.
- [MOVE IT](https://moveit.com.ph/how--it-works/): pickup/drop-off workflow; its website blocked direct retrieval during this task, so no detailed visual claims are made.

No competitor logos, screenshots, or proprietary assets are bundled.

## Pre-M2 refinement contract — 2026-10-17

THESIS: Keep the route spine usable and quiet; remove demo controls and the oversized empty-state heading.

OWN-WORLD: Preserve the light Canvas/Cornflower palette, Figtree roles, outlined white grouping and compact numbered errands. No new theme or font system.

STORY: Add an errand or move into Recurring, then return to the same day. A read-only Profile previews recognizable identity without inventing accounts or contact details.

FIRST VIEWPORT: Today retains its date, route surface and anchored Plan action. The empty prompt is body-sized and flush with the route's inner left inset. Profile places initials and Jace Bellen above personal details, then a plain sharing explanation. Settings uses the same heading and column rhythm. Four labeled destinations remain stationary while module content fades and slides slightly over the shared 260 ms entry / 180 ms exit; Remove animations cuts immediately.

FORM: An ordinary extension of the approved Android Material system, code-led; seed: none (ordinary extension; no concept roll).

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
