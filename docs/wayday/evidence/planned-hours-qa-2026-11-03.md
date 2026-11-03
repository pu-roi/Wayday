# Planned visit hours QA

The owner reported that recommendations appeared to use current opening status for future plans. This investigation followed the selected date and errand timing from Review through discovery, alternatives, the joint scheduler, and refined road arrival times. All provider and road responses in these checks are synthetic.

## Findings

The selected trip date already reaches `BusinessHours.day`. Current dated hours apply within their seven-day coverage. Later dates use regular weekly periods with the existing Usual hours label. Missing, failed and stale hours remain unknown. The current clock governs metadata freshness and the separate Open now or Closed now display.

The scheduler already receives the selected date's opening windows, departure, deadlines and durations. It checks service-start appointments, physical arrival deadlines, completion deadlines, the five-minute visit buffer and known opening intervals. Road refinement recalculates arrival and service times. The controller rejects a refined visit that crosses a known closing boundary.

Two earlier-stage defects were reproduced.

1. The shortlist received only the trip-wide time window and duration. It omitted the individual errand's timing rule and clock. Three morning-only branches could therefore fill the shortlist for a 2 PM appointment, excluding a fourth branch open at the appointment time. The later scheduler would correctly reject the retained branches, but could not recover the discarded branch. Finish-before constraints had the same gap.
2. Automatic shortlists could be reused after changes to trip dates or times. Alternative browsing also omitted the final deadline and manual visit constraints from its identity, so earlier exhaustion or filtered results could be retained for a changed schedule.

## Repair

The local hours query now carries the effective errand timing and clock. At-a-set-time filtering checks the complete visit at that service start. Finish-before filtering intersects the trip window with the completion deadline. Both include the existing five-minute buffer. An isolated arrive-by errand must have a possible visit start no later than its arrival deadline, while completion can occur afterward. Discovery, alternatives and the pre-calculation hours check share this query.

Arrive-by continues to constrain physical stop arrival. A task at a shared stop may begin after another task, so the exact arrival and internal order remain the joint scheduler's responsibility. Flexible visits continue to use the selected trip window and calculated arrival, with the existing policy against waiting for opening.

Automatically generated shortlists record the hours context used to create them. Changing the date, departure, deadline, duration or errand timing discards an obsolete automatic shortlist. Saving a draft performs local invalidation. The next explicit Build recommendations action runs discovery under the new context. Confirmed locations and explicitly selected branches remain choices and are validated again. Alternative browse identity now includes the same scheduling constraints.

The existing bounded candidate count and provider request guards apply. A shortlist remains a bounded search result. A place with unknown hours stays provisional, and a calculated itinerary needs the full reported visit interval to fit.

## Verification scenarios

| Scenario | Expected outcome |
| --- | --- |
| Three incompatible branches followed by one branch suitable for a future appointment | The suitable branch survives filtering and reaches the itinerary |
| Same returned branches with a finish-before deadline | Branches opening after the deadline are excluded before shortlisting |
| Current-date closure and tomorrow's dated afternoon opening | Tomorrow's appointment uses tomorrow's period |
| Visit beyond current-hours coverage | Weekly periods are used and labelled Usual hours |
| Full duration ends at closing, including buffer | Exact boundary fits and one minute beyond fails |
| One-minute versus 55-minute estimated travel | Branch selection changes when arrival and the full visit no longer fit |
| Refined roads delay a visit past closing | The proposal is rejected with business-hours recovery |
| Arrive-by task follows an appointment at a shared stop | Physical arrival and later task service stay distinct |
| Schedule edit after discovery | Explicit rebuilding refreshes the automatic shortlist and alternatives context |
| Schedule edit after explicit branch selection | The selected branch remains chosen for recalculation |
| Current status widget changes from closed to open | Future trip-date hours remain independently displayed |

The appointment and completion-deadline shortlist reproductions failed before the repair. Final validation also covers the isolated arrival deadline and shared-stop distinction. The focused run passed 45 tests. The full Flutter suite passed 736 tests with one existing skip, and static analysis reported no issues. These checks use synthetic provider records and road estimates. Live provider behavior and physical-phone qualification remain separate from these local repairs.
