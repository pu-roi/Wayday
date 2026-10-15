# Wayday product scope

Last updated: 2026-10-15 (Asia/Manila).

## Purpose and status

Wayday will help people complete several errands in one trip by choosing suitable places, ordering stops, and checking timing constraints. Initial users are people running errands in Philippine cities, with Pasig/Ortigas as the proposed pilot area.

The current phase creates documentation, configuration, and agent skills only. Every application capability below is planned. There is no working mobile app or backend yet.

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

Public commute is excluded from current scope, including jeepney, bus, and rail journey planning. AI interpretation, live traffic, and in-app turn-by-turn navigation remain deferred. Accounts, cross-device synchronization, analytics, and continuous location history are not first-version requirements. Full offline discovery and fresh route optimization are also deferred.

The initial plan may hand a leg to an installed navigation app. This is a user convenience, not a source of travel-time or place data; Wayday must still show the saved stop address and coordinates when no navigation app is available.

## Transportation profiles and feasibility

The five profiles above are the owner's clarified product scope. Sedan and truck support supersede the earlier decision to defer those categories; biking is also included. Clearance-aware routing is a requirement to investigate, not an implemented or verified capability.

Keep ground clearance (space below the vehicle) separate from overall height (relevant to overhead clearance). Low/high clearance labels do not establish numeric dimensions, road passability, or vehicle access rights. Confirm whether “truck” means a pickup/light truck or a heavy goods vehicle before choosing engine costing and required dimensions. Validate available surface, access, and restriction data in the pilot area. Do not promise ground-clearance safety from an ordinary car/truck route.

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

The current reference is [Asikaso V2](../Asikaso-Prototype/V2-NOTES.md): From/Errands/To, compact numbered rows, focused editing, recurring groups, and a map with a timeline. White/gray/ink surfaces and restrained route blue are a starting direction, not a finalized Wayday design.

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
