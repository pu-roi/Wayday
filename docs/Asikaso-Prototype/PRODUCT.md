# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

(Sample UI is a phone-sized clickable HTML prototype standing in for a future mobile app. Native platform target is undecided.)

## Stack

Static HTML/CSS/JS, single file, clickable prototype at phone viewport.

## Users

Anyone in Philippine cities with a day of errands: students, workers, parents, freelancers. They have a start point, an end point with a deadline, and a mix of errands, some at fixed times, some with closing times, some doable at any branch. Today they plan the order in their head and look up branches one at a time in Google Maps.

## Product Purpose

Asikaso plans a whole day of errands: it picks which branch to use for flexible errands, orders every stop, and checks that everything fits before the user's deadline. If something does not fit, it says so before the user leaves. Success: the user ends their day on time without doing the routing math themselves.

## Positioning

"Google Maps takes you from A to B. Asikaso plans A to Z." Maps apps route to one chosen destination. Asikaso chooses the branches, sets the order, respects fixed times and closing times, and tells you what won't fit. It is a to-do list that plans the trip, not a maps app.

## Operating Context

- Errand types: Fixed (set time and place), Closing (set place, must arrive before close), Flexible (any branch, any time). On Today the notepad never asks for a type; it is inferred. In the recurring-template editor the user explicitly asked (2026-10-13) to choose "Flexible / Fixed / Closing" per errand, so those three words are user-facing there, each with a one-line plain description.
- Recurring = templates: a named set of errands (e.g. "Weekly Stock") with a repeat schedule, added to a day in one tap from the Errands card or Pick mode; after a trip, finished stops can be saved as a new template.
- Primary errand input is a free-text note: the user types errands in plain language ("registrar before 4, pitch 11–2, sunduin si Bea 3pm, lunch with her, grocery for Mom") and AI interprets each line into a structured errand (what, where, when, duration, must/if-time, do-after). The user reviews and corrects the interpretation.
- Secondary input is a structured picker (chips/checkboxes): what, where (specific place or any branch of a category/chain), when (anytime / before a time / at exactly a time window), duration, must-do vs if-there's-time, optional "do after" dependency.
- Recurring errands: errands can repeat (weekly, every two weeks, monthly, custom). After each finished trip, Asikaso asks whether to save errands as recurring; they live in a recurring list the user can add to a day's plan.
- Trip inputs: start, end, leave time, arrive-by deadline, travel mode (car / motorcycle / walk). No public-commute mode.
- Output: timeline of stops with chosen branches and times, map, summary of slack, "didn't fit" list with actions (move to tomorrow, shorten, make it a must). The user can pick a different branch for any flexible stop; the plan re-checks timing.
- On the trip: Go per leg (hands off to maps app), check off stops, "I'm running late" re-plan.
- Settings: saved places, default travel mode, buffer per stop, default durations per category, language, avoid tolls.
- Navigation per leg is handed off to Google Maps / Waze; Asikaso does not do turn-by-turn.
- Metro Manila traffic and commute modes matter.

## Capabilities and Constraints

- Capstone project (PLP, Pamantasan ng Lungsod ng Pasig). Prototype stage.
- Demonstration day from the pitch: start PLP; registrar (closing time); pitch 11:00–2:00 (fixed); fetch girlfriend 3:00 (fixed); lunch with her (any branch, after pickup); groceries for mom (any branch, on the way home); home by 6:00, planned arrival 5:30.
- Undecided: real-time traffic source, multi-day carryover depth, native platform.

## Brand Commitments

- Name: Asikaso (Filipino: to attend to, to take care of).
- Voice: clear English labels with warm Taglish touches in summaries and nudges.
- Visual stance (user, 2026-10-13): simple, little color, sits alongside established apps (Life360, Google Maps, Waze, Notion). Do not derive the look from the app's name. Category standard at full craft.

## Evidence on Hand

- Pitch script (slides 2–7). No user research, no metrics, no testimonials. Do not fabricate adoption or performance claims.

## Product Principles

1. Ask plain questions (where? when? how long?), never expose the solver's categories. Sole exception: the template editor, where the user asked to choose Flexible / Fixed / Closing per errand; everywhere else errands read in plain words ("Any branch", "Before 7:00 PM").
2. Tell the truth before the user leaves: show slack, and show what won't fit.
3. Plan the day, hand off the driving: defer navigation to the maps app people already use.
4. Smart defaults over settings: saved places, category durations, buffers.

## V2 interaction update, 2026-10-14

For `V2.html`, the owner replaced the V1 notepad/Write/Pick interaction with
Add errand → type → Save into a compact numbered list. Individual rows open a
focused editor with Where, When and collapsed More options. Recurring uses the
same pattern. Templates add directly to Today, and suitable branches are the
default with a specific-place override. Arrive by and Finish before are separate
constraints. The V1 file remains the comparison baseline. See V2-NOTES.md.
