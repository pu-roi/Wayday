---
name: wayday-mobile
description: Plan, implement, or review Wayday Flutter state, feature architecture, offline trips, platform permissions, map integration, and reminders. Use wayday-ui for purely visual work and dedicated API/database skills for contract or schema changes.
---

# Wayday mobile

D66 keeps the manual map mounted, captures the final idle camera with a three-second revision guard, and throttles isolated zoom UI to four updates per second. Superseding gestures/selections invalidate confirmation; map movement never searches. Empty/default Today date refreshes on Manila startup/resume/midnight only without explicit date, active drafts/editors or accepted progress. Preserve legacy date history and source fingerprints. Additive dateSelected JSON needs no schema migration. Keep transient primary type/rating/count metadata and prior interpretation/clarification request lookup compatibility; report native/physical profile timings separately from mock rebuild counts.

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

D61 combines recommendation, route and schedule review; multiple place replacements need one explicit route update without Gemini/discovery. Start trip saves active progress and opens guidance directly, while Save for reuse adds a separately named Recurring entry. Preserve five-minute foreground reuse and invalidate it on background. Reuse remaps task/dependency IDs and refreshes providers without generation. The approved additional Google test allocation is US$8 personal / US$2 disposable, durable without refill or an account-wide guarantee. Keep the personal-phone harness protection. Future sharing/live GPS remains documentation only.

D62 replaces manual route updates with persisted, 500 ms debounced replacement refreshes. Keep Your plan mounted, preserve other branches, coalesce one calculation flight and queue the latest saved revision. Reject stale results; no Gemini or automatic discovery. Keep in-flight storage/request identities after a ten-second caller deadline and do not report unsaved choices as saved. Explicitly synchronize native markers/polylines on changed coordinates/geometry without replacing the map view. Manual cancellation returns to alternatives; alternatives/map dismissal returns to the plan; Back goes to Review and unchanged valid proposals reuse work. Preserve the US$0.782 disposable live-accounting recovery floor against the original US$2 before any further paid rehearsal. Mocked emulator checks do not authorize personal-phone installation/reset or live usage.

D63 extends transient place snapshots with field-profile-aware main opening hours, date coverage, retrieval time and distinct missing/failed/stale states. Reuse sufficient metadata and hydrate selected errand businesses when needed, without Gemini or business rediscovery. Pins and unrelated trip endpoints do not trigger inferred business lookups. Include hours in proposal validity and recheck after road refinement; explicit closed choices remain editable and cannot start. Expose hours in Details/alternatives and keep period evaluation local, avoiding hidden isOpen requests. Preserve no provider hours in templates or drafts, existing accounting allocations and the disposable recovery floor. Separate mocked/native/build checks from actual Google hours, charged-SKU and physical-phone qualification.

D64 submits all ordered remaining waypoints plus the destination once per navigation session and uses manual continuation after saved task completion. Show one active errand at a time, retain shared-stop task identities and later return visits, and merge only consecutive identical navigation targets. Keep native views stable, explicitly follow the location after readiness, and fit all returned route segments for Whole trip rather than relying on the bounded default overview. Bound map/location waits, distinguish GPS/permission/route errors, preserve pan/recenter intent, retain dispatched native work and reject obsolete callbacks. Count submitted waypoints, not camera changes or ordinary progression. Keep supported terms customization, accepted JSON compatibility, existing allocations/recovery floor and personal-phone protections. No new schema/provider/dependency or background-navigation behavior is added.

D65 keeps unfinished recovery visible in a top-of-Today Current trip section, separate from reusable saving. Finish, unlike Back, requires confirmation then atomically clears Today and the matching trip; all Today errands/locations/settings reset to current Manila date and existing defaults. Serialize shared database writes, bind cleanup to the run and confirmed Today revision, require new confirmation after edits and prevent stale progress from recreating finished trips. Apply UI reset only after commit, keep retries explicit and propagate a finished result through both navigation entry paths. No provider request, schema/history feature or automatic old-record purge is introduced. Preserve explicit reusable trips, recurring lists, saved places and personal-phone safeguards.
