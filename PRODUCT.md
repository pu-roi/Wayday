# Wayday product context

<!-- impeccable:product-schema 1 -->

## Platform

android

## Stack

Flutter/Dart with Riverpod and GoRouter, as selected in [the stack inventory](docs/wayday/STACK.md). iOS is a later target.

## Product authority

[Product scope](docs/wayday/PRODUCT.md) and [decisions](docs/wayday/DECISIONS.md) remain the maintained product authorities. This entry point makes their location discoverable to design tools; it does not replace them.

## Current implementation scope

The latest approved status supersedes the earlier in-memory/example-day preview: the Android shell has Today, Recurring, Profile, and Settings, with one light Cornflower theme and the compact From/Errands/To structure. The entire Android app stays in upright portrait. M1 stores committed errands, notes, recurring lists, and saved places locally in Drift/SQLite; editor drafts require Save. New workspaces start with an empty day, existing saved work is preserved, and no example-day loader is exposed. Quick add defaults to Anytime. From and To clear on cold launch or Flutter hot restart; errands, saved places and other committed settings remain durable. Recurring groups start collapsed. Recurring lists copy independently into Today only on request; repeat settings remain descriptive metadata. Place entry starts with familiar business, landmark and address search plus saved places. A selected result opens a full-screen MapLibre/OpenFreeMap map with a fixed center pin and Confirm location; Choose on map is also available without search. Custom-name and coordinate entry are not required or exposed; coordinates are read-only. Save to my places is an optional, separate local save. Use my location explicitly requests one foreground fix with a cancellable 12-second UI wait; moving the map abandons a pending result. Existing labels without coordinates remain unresolved. Plan my day opens a draft vertical review with manual order, required/optional priority, place changes and focused details. Find your way is the review action placeholder. It currently saves the reviewed day locally with existing revision checks; missing pins still save a draft, and Back cancels the review. Neither action calculates a road route or starts a trip. Interpretation remains unchanged and independently owned. The local development place API searches a real imported OSM catalog of 13,033 records through verified PostgreSQL/PostGIS by default. M2-03 import, transaction, correction-retention and outage/restart checks are complete; file snapshot mode remains an explicit development option. Physical-location and pilot coverage gates remain open. M2 overall is incomplete. Recommendations, routing, trip execution, reminders and sharing remain pending. Time entry uses numeric fields. Profile is a read-only sample named Jace Bellen, with unset contact details and no account or connected sharing. iOS remains deferred. Follow [the map/review handoff](docs/wayday/MAP_REVIEW_HANDOFF.md), [implementation plan](docs/wayday/IMPLEMENTATION_PLAN.md) and [task board](PLANNING.md) for milestone gates.

## Evidence on hand

The current refinement preserves optional multiline notes, independent note copies, smooth list insertion/disclosure, and themed transient in-app feedback. Today uses a compact left-aligned empty prompt. All four labeled modules share a short fade and slight slide, including Add from a recurring list; reduced motion makes module changes immediate. Preserve consecutive-entry focus. Android reminder notifications remain a separate, later milestone.

The [V2 notes](docs/Asikaso-Prototype/V2-NOTES.md), [historical design system](docs/Asikaso-Prototype/DESIGN.md), and [V2 screenshots](docs/Asikaso-Prototype/docs/screenshots/v2) provide provisional interaction references. The supplied image is visual inspiration only. Preserve historical source material.

## Brand commitments

Use Wayday. Keep the interface clean, refined, and uncluttered. The owner supplied Canvas `#FBFBF8`, Mist `#DBE3E9`, Cornflower `#6AA6DA`, and black as references. The initial palette options have been superseded by a single light Cornflower direction. The five-digit black value is interpreted as `#000000`.
