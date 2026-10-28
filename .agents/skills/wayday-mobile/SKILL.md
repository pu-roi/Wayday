---
name: wayday-mobile
description: Plan, implement, or review Wayday Flutter state, feature architecture, offline trips, platform permissions, map integration, and reminders. Use wayday-ui for purely visual work and dedicated API/database skills for contract or schema changes.
---

# Wayday mobile

Read the repository's `AGENTS.md` and respect the current phase and latest user request. This skill supports authorized work; it does not authorize application development or installations.

## Read the relevant context

- Read [Product requirements](../../../README.md#product-requirements) for current scope and correction behavior.
- Read [Architecture](../../../docs/wayday/ARCHITECTURE.md) for feature boundaries, local persistence, and platform adapters.
- Read [Stack](../../../docs/wayday/STACK.md) before selecting a map/location dependency or service.
- Consult [Decisions](../../../docs/wayday/DECISIONS.md) when historical Asikaso behavior conflicts with current direction.
- Follow the owner's latest task instructions and verification practices in [Contributing](../../../docs/wayday/CONTRIBUTING.md#development-practices). The [mobile README](../../../apps/mobile/README.md) owns runnable commands. Do not recreate a roadmap or task board unless the owner explicitly asks.

## Apply Wayday's mobile boundaries

Organize Flutter work by feature with views, view models, and repositories. Keep SQL and provider requests out of widgets. Load the planning skill as well when a change affects itinerary semantics.

Use `wayday-ui` for visual and interaction design, `wayday-api` for client-server contracts, and `wayday-database` for schema/migration work. Combine only the skills relevant to the change; do not make every mobile task load the entire skill collection.

Preserve the five transportation choices: walking, biking, motorcycle (motor), sedan (low clearance), and truck (high clearance). Public commute is excluded. Keep the selected profile with saved trips and invalidate incompatible plan estimates when it changes. Treat clearance labels as requirements awaiting validation, not as proof of road suitability or numeric vehicle dimensions.

Preserve original errand text and user-confirmed rules. Treat parsing as a limited suggestion mechanism; do not add AI or silently overwrite edited timing, place, priority, or dependency fields.

Keep tasks, template copies, trip progress, and saved itineraries local. A copied template is independently editable; remap its internal dependency IDs. A stale network result must not overwrite newer input or completed-stop history.

Android Today and Recurring persistence already exists; the browser preview remains in memory. Removing future sample seeding must preserve saved rows, including examples the user may have edited. The reconciliation adds online place search and map pin selection; verify their actual Android behavior and provider coverage before claiming readiness. Saved trips and automatic planning remain future work. Manual place selection is an override or development checkpoint; the first usable release must recommend stores, choose branches/order, and estimate schedules.

Keep offline map availability separate from offline routing. Check downloaded map completeness, styles/fonts/sprites, provider limits, and iOS cache eviction. Preserve required attribution outside overlapping map sheets.

Reminders are later work; ordinary in-app feedback does not authorize reminder integration. When reminders are requested, use native geofences for background location events and local notifications. Do not assume a foreground location stream proves killed-app delivery. Verify native engine release licensing before adopting any tracking plugin. Account for permission denial, approximate location, reboot, delayed events, duplicate alerts, and stale reminders after replanning. Android remains first; iOS verification belongs to its later phase.

Use the V2 prototype as a provisional interaction reference. Preserve its source; do not treat simulated data, rendered times, or screenshot dimensions as production constraints.

## Verify the affected behavior

Choose checks that exercise observable persistence, correction, navigation, and failure behavior. For reminders and offline maps, include physical-device cases from the architecture guide. When only documentation exists, review the design and state which checks remain future work rather than inventing executable application tests.
