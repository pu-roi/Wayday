# Android shell and Today

Mode: Operate. Build directly in Flutter. This is a constrained adaptation of V2, with its route structure and compact list preserved, rather than a new visual identity exercise.

## Current implementation context — 2026-10-30

README.md and DESIGN.md are authoritative. The descriptions below are preserved historical design context where they mention sample seeding, memory-only storage, illustrative maps or deferred planning. Current Android Today/Recurring state is persisted in Drift, startup is empty without reset-to-example actions, and the shared picker uses real maps/search/pins. D47 adds the separate Plan my day preparation, recommendation, Google result-map/timeline and accepted itinerary flow. Keep the existing Cornflower/Figtree tokens, focused editors, quiet compact surfaces, large-text scrolling and reduced motion. Do not copy historical simulated route times into runtime screens. No active Impeccable design tool was available for this implementation; use the actual Flutter theme and shared widgets.

## Direction contract

The first viewport must show Today, the date, route endpoints, a numbered errand list, trip settings, and a clear next action. The signature is the From/Errands/To route spine: tasks visibly belong between the endpoints. The supplied reference contributes generous spacing, quiet tinted surfaces, and a strong anchored action; its booking, payments, glass, and gradients are not product requirements.

Use one light Canvas/Cornflower theme for the MVP. The owner removed appearance choices and dark mode on 2026-10-16. Use Cornflower for primary actions with dark readable text, pale blue for quiet grouping, and a darker derived blue for links and icons. Keep the prior route composition and Figtree identity. Use Material controls and system Back, 48 dp targets, safe-area and keyboard insets, and large-text reflow.

Provide an example day on launch and an empty-day preview. Quick add stays open for consecutive entries; each new errand defaults to Anytime. Put details in a focused editor. Group Leave/Home by/Travel in a single tinted footer inside the route surface. Replace the clock dial with a scrollable hour/minute entry sheet, AM/PM, validation, and quick choices. Changes remain in memory. The planning action explains that route calculation is still to come; it must never display invented calculated routes or times.

## Motion, notes, and feedback

Keep quick add ready between entries: insert rows with a short size/fade transition while preserving field state, focus, and visibility. Use interruptible size disclosure for Today, Recurring group contents, and repeat details, with a coordinated chevron. Use 260 ms entry and 180 ms exit with deceleration; the platform's Remove animations setting makes spatial transitions immediate. Avoid decorative loops and new animation dependencies.

Optional free-form multiline notes belong in the focused errand editor, shared by Recurring and Today. A small note icon indicates details without showing the note body in compact rows. Copy notes independently into Today; keep draft cancellation and clearing notes functional. Notes are plain text, not an interactive shopping checklist.

In-app confirmations use a shared floating Material snackbar with pale-blue fill, readable blue text, and a restrained status icon. Replace old feedback rather than queueing it. Normal messages expire after four seconds and Undo messages after six; accessible navigation retains actionable messages. This does not implement Android reminder notifications.

## Boundaries

Recurring is now an implemented in-memory module: reusable named lists with the same compact rows and focused editor as Today, create/edit/delete, independent drafts, and manual Add to Today. Copying retains timing/priority and source item identity to prevent duplicates. Editing a copy does not change the original list. Repeat settings are descriptive metadata; there is no automatic scheduling. Settings describes the preview and can restore the example day; it contains no appearance controls.

From, To, and errand-place entry open a shared illustrative map preview with manual place labels. The preview has no real geographic coordinates, search, pin placement, GPS, or provider data. No map dependency, backend, credentials, or billing is needed.

## Inspiration

- V2: route spine, numbered rows, and focused editing.
- User-supplied booking reference: spatial separation, soft surfaces, and clear primary action.
- [Google Maps](https://support.google.com/maps/answer/144339?co=GENIE.Platform%3DAndroid&hl=en): editable route endpoints and travel choice.
- [Notion](https://www.notion.com/help/database-properties): compact rows with details revealed only when editing.
- [Notion lists](https://www.notion.com/help/lists) and [Apple Notes organization](https://support.apple.com/en-il/guide/iphone/ipha61270292/ios): named collections, direct entry, and content-first lists. These inform information hierarchy, not imported assets or iOS controls on Android.
- [Angkas](https://www.angkas.com/services/passenger): focused pickup/destination flow.
- [MOVE IT](https://moveit.com.ph/how--it-works/): pickup/drop-off workflow; its website blocked direct retrieval during this task, so no detailed visual claims are made.

No competitor logos, screenshots, or proprietary assets are bundled.
