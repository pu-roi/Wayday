# Wayday product scope

Last updated: 2026-10-17 (Asia/Manila).

## Purpose and status

Wayday will help people complete several errands in one trip by choosing suitable places, ordering stops, and checking timing constraints. Initial users are people running errands in Philippine cities, with Pasig/Ortigas as the proposed pilot area.

The current implementation is an Android Flutter UI shell with a single light Cornflower theme, Today, Recurring, a read-only sample Profile, and Settings. The first functional implementation adds local Drift/SQLite storage for the active day, optional multiline notes, reusable groups and saved places, with explicit reviewed input suggestions. Notes copy independently into Today. List insertion and disclosure have short transitions that honor reduced motion; themed in-app feedback expires automatically under ordinary navigation. M2 adds a real MapLibre/OpenFreeMap map, manual pins, saved-place reuse and a draft vertical review after Plan my day. Users can reorder visits, change required/optional priority and choose places before confirming locally. Interpretation is unchanged. M2 place search now uses a bounded local OSM catalog through FastAPI, with a search-first chooser and full-screen center-pin map. Results supply names and addresses; coordinate entry is removed. M2-03 PostGIS runtime checks are complete; physical-location and broader coverage checks remain open. Recommendations, road routing, trip execution and native reminders remain pending. Time entry uses hour/minute fields. New installations start with an empty day; no example-day loader is exposed, and existing saved work remains intact. The sample Profile identifies Jace Bellen without invented contact information, authentication, or sharing. Module transitions honor reduced motion. See PROGRESS.md for persistence verification and the approved implementation plan for milestones.

From and To are session-only as of 2026-10-18: clear them on cold launch/hot restart while retaining errands, errand places, notes, templates, saved places and other trip settings. Recurring groups initially appear collapsed. A unique containing mapped area supplies a manual pin’s name; ambiguous/nearby places require a choice, and unknown pins remain usable. These are place-selection rules, not errand interpretation.

Build and verify Android first, with the phone interface locked to upright portrait. Landscape is not an application feature. iOS remains a later target; iOS tooling and device access do not block Android development.

## Current product direction

| Capability | Planned first-version boundary |
| --- | --- |
| Errand input | Ordinary text or bullet lines with limited, editable rule-based suggestions in English, Filipino, and Taglish |
| Place selection | Specific places, saved places, manual pins, or suitable nearby branches from a regional catalog |
| Day planning | Start/end points, departure, final deadline, stop duration, priority, timing rules, and dependencies |
| Travel | Walking, biking, motorcycle (motor), sedan (low clearance), or truck (high clearance); one profile per trip; no public commute |
| Plan result | Map and stop timeline, selected branches, estimated times, slack, and errands that do not fit |
| Trip progress | Mark stops complete, change a branch, report a delay, and request replanning |
| Routines | Named templates containing groups of errands, copied into a day |
| Reminders | Local time notifications and background location reminders subject to platform permissions and delivery limits |
| Offline use | Local tasks, templates, saved places, saved itinerary, progress, and previously downloaded map coverage |

Public commute is excluded from current scope, including jeepney, bus, and rail journey planning. AI interpretation, live traffic, and in-app turn-by-turn navigation remain deferred. Personal planning remains account-free. Later sharing milestones require sign-in only for publishing/following native alerts and publish selected fields through expiring browser links. Cross-device personal synchronization, analytics and continuous location history remain deferred. Full offline discovery and fresh route optimization are also deferred.

The planned active itinerary keeps route overview and task progress in Wayday, with a user-selected Google Maps/Waze navigation handoff for each leg. Manual arrival remains available; automatic arrival policy is unresolved. Completing an errand requires an explicit Done action before advancing. Sharing entry points become functional in M5/M6. The current review action is only a Find your way placeholder and retains its local draft-save behavior. The active itinerary will hand a leg to an installed navigation app. This is a user convenience, not a source of travel-time or place data; Wayday must still show the saved stop address and coordinates when no navigation app is available.

## Transportation profiles and feasibility

The five profiles above are the owner's clarified product scope. Sedan and truck support supersede the earlier decision to defer those categories; biking is also included. Clearance-aware routing is a requirement to investigate, not an implemented or verified capability.

Keep ground clearance (space below the vehicle) separate from overall height (relevant to overhead clearance). Low/high clearance labels do not establish numeric dimensions, road passability, or vehicle access rights. The owner confirmed that “truck” means pickup/light truck. Validate appropriate costing and required dimensions; do not assume heavy-goods routing. Validate available surface, access, and restriction data in the pilot area. Do not promise ground-clearance safety from an ordinary car/truck route.

## Input and correction

Rule-based suggestions can recognize explicit phrases such as “before 4pm,” “sunduin,” “palengke,” and “kung may time.” A rule can suggest a category, timing constraint, or priority. It does not establish general language understanding.

Preserve the original text and distinguish explicit user values from suggestions and defaults. Unknown places, ambiguous times, and unclear references need correction. For example, “lunch with her after” must not acquire a guessed dependency or person. Structured editing remains available even when parsing fails. Editing an errand title must not silently erase previously confirmed rules.

Proposed categories include groceries/wet markets, haircuts, coffee/food, pharmacies, banks, offices, and other errands. Category coverage and Filipino/Taglish vocabulary require local validation; the prototype's category list is not a complete specification.

## Timing and priority

- **Anytime:** no user-specified time boundary, but known business hours still matter.
- **At a set time:** service starts at the specified time; early arrival may require waiting.
- **Arrive by:** arrival must occur by the deadline; completion can be later.
- **Finish before:** the visit, including its configured stop buffer, must finish by the deadline.
- **Must do:** never silently omit the errand to produce a successful-looking itinerary.
- **If there is time:** may be omitted with an explanation when the itinerary cannot accommodate it.
- **After another errand:** retain the dependency and reject circular ordering.

Business availability must cover the intended visit. Missing or stale hours are unknown, not proof that a business is open. A manual correction must retain its provenance. Final deadline and appointment feasibility take precedence over reducing travel time.

“On the way home” remains an interaction to refine. Do not silently turn it into a requirement that a particular errand is always the single final stop.

## Offline promise

Tasks and progress remain usable after connectivity loss or app restart. A saved trip includes its ordered stops, coordinates, route geometry, schedule, and calculation time. Map coverage must have completed downloading before it is advertised as available offline.

Fresh place discovery and full replanning require the backend. If unavailable, show the saved plan with its age and retain unsent edits locally. Do not replace a road route with a straight line and label it as a calculated journey. Existing reminders can operate locally, subject to OS behavior.

## Design reference

The interaction reference is [Asikaso V2](../Asikaso-Prototype/V2-NOTES.md): From/Errands/To, compact numbered rows, focused editing, recurring groups, and a future map with a timeline. The owner's refined MVP direction uses a single light Canvas/Cornflower theme with no palette or dark-mode controls. Today and Recurring share compact rows and a focused editor; every quick-added errand starts as Anytime. See the [current design system](../../DESIGN.md).

The [original abstract](../ASIKASO_ABSTRACT.md) emphasizes public commuting. That ambition is excluded from current scope. Preserve the original rather than rewriting project history.

## Acceptance scenarios for later development

1. Enter an English, Filipino, or Taglish errand; review suggestions and correct unknown fields without losing the note.
2. Choose a branch and obtain a schedule using road travel estimates, visit durations, waiting, and known hours.
3. Demonstrate that arrive-by and finish-before produce different feasibility results for the same arrival and visit duration.
4. Report an impossible mandatory appointment or final deadline without silently removing mandatory work.
5. Explain omitted optional errands. Distinguish missing data and solver timeout from proven conflicts.
6. Change a branch or report a delay; preserve completed stops and recalculate only the remaining itinerary.
7. Copy a template into Today, preserve dependencies, avoid duplicate addition, and keep template edits independent from today's copies.
8. Restart offline; recover tasks, progress, itinerary, and available map coverage.
9. Exercise location/notification denial, approximate location, background delay, reboot, and disabled location services with clear fallback behavior.
10. Select each of the five transportation profiles and verify that the appropriate routing assumptions reach planning and replanning. Changing a profile must invalidate incompatible travel estimates. Include bicycle access and vehicle-restriction cases; mark unsupported clearance checks as unverified instead of reporting them as satisfied.

Capstone evaluation should compare route duration/distance against a defined baseline order, task completion, estimated versus observed times, and user feedback. No accuracy or efficiency percentage is claimed before measurement.

## Approved functional implementation

Follow [the implementation plan](IMPLEMENTATION_PLAN.md) and [task board](../../PLANNING.md). M1 stores one active dated draft using Asia/Manila, stable IDs, structured place intent and a visibly assumed 15-minute duration. Saved labels without coordinates remain unresolved. Suggestions require explicit review; notes remain independent. No automatic date rollover or multi-day history is implied.

Sharing supports read-only browser links and later native follower alerts. GPS suggests arrival; traveler/teacher confirmation establishes activity. A teacher/bus phone represents group progress, not proof of individual child presence. Live location is explicit, pauseable and timestamped; published data is limited and expires. Local personal nudges and shared-trip push alerts are distinct features.
