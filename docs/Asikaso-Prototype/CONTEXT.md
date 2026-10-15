# Asikaso: context for AI assistants

> Read this file first. It explains what Asikaso is, what the prototype does, how the code is organized, and what the owner currently likes and dislikes about it (the **Owner feedback** section at the bottom). Respect that feedback when making changes.

**Versions:** `asikaso.html` is the preserved first-iteration baseline described below. `V2.html` is the 2026-10-14 refinement of Today and Recurring. Read [V2-NOTES.md](V2-NOTES.md) before changing V2; its owner-approved interaction direction supersedes the V1 notepad and inline-editor descriptions for that file. Keep the baseline intact for comparisons across AI tools.

---

## 1. What Asikaso is

**Asikaso** (Filipino: "to attend to, to take care of") is a mobile app concept from a capstone project at PLP (Pamantasan ng Lungsod ng Pasig), set in Metro Manila, Philippines.

**One-line pitch:** *Google Maps takes you from A to B. Asikaso plans your whole day, A to Z.*

**The problem.** People run several errands in one day. Some are at a fixed time (a meeting, picking someone up). Some have a closing time (a registrar office that closes at 4). Some can be done at any branch, any time (groceries, lunch). Today people work out the order in their heads and search branches one at a time in Google Maps. They get it wrong, run late, or forget something.

**What the app does.**
1. The user enters a **start point**, an **end point**, a **"home by" deadline**, and a list of **errands**.
2. Asikaso **picks the best branch** for each flexible errand, **orders every stop**, and **checks that everything fits** before the deadline.
3. If something won't fit, it says so **before the user leaves** (for example: "No time for groceries today. Bukas na lang?") and offers fixes.
4. During the trip it hands each leg off to Google Maps or Waze. Asikaso does not do turn-by-turn navigation.

**Positioning.** Asikaso is not a maps app. It's a to-do list that plans the trip.

**Users.** Anyone in a Philippine city with a day of errands: students, workers, parents, freelancers.

**Copy voice.** Clear English labels with warm Taglish touches in summaries and nudges ("Kasya lahat.", "Halos kasya.", "Bukas na lang?", "Tapos na lahat!").

### Core concepts

| Concept | Meaning |
|---|---|
| **Fixed** errand | Set place **and** set time (e.g. capstone pitch 11:00–2:00, pick up girlfriend at 3:00). |
| **Closing** errand | Set place, must be done **before** a time (e.g. registrar before 4:00 PM). |
| **Flexible** errand | **Any branch, any time** (e.g. groceries, lunch). Asikaso chooses the branch. |
| Priority | **Must do** or **If there's time**. "If there's time" errands are dropped first when the day doesn't fit. |
| Order | Optional: "do after X" (lunch after pickup) or "on the way home" (last stop). |
| Travel mode | Car, Motorcycle, Walk. **No public-commute mode** (owner's decision). |
| Recurring template | A named group of errands that repeats (e.g. "Weekly Stock": supermarket, cat food shop, pick up laundry, flower shop, motorcycle parts shop). One tap adds the whole group to today. |

Product rule: on the main errand input, users are **never asked to pick a type**; the type is inferred from what they type. The words "Flexible / Fixed / Closing" are user-facing **only in the template editor**, because the owner asked for them there.

### Sample day (used throughout the prototype and pitch)
Start at PLP, 8:30 AM. Get data from the registrar (before 4 PM). Capstone pitch 11:00–2:00 at PLP. Pick up girlfriend in Ortigas at 3:00. Lunch with her after. Groceries for Mom on the way home, only if there's time. Home by 6:00 PM. Planned arrival: **5:30 PM, 30 min to spare**.

---

## 2. Project status

- **Stage:** clickable design prototype, before real development. The owner will keep refining the prototype first, then build the real app.
- **Everything is simulated:** places, coordinates, travel times and the "AI" reading of typed errands are hard-coded sample data in JavaScript. There are no APIs, no backend and no real maps.
- **Target platform:** a mobile app, still undecided (native, Flutter or React Native). The prototype is phone-sized HTML.
- **Planned real stack ideas (not decided):** a maps/places API for branches and opening hours, a distance-matrix API for travel times, an LLM to parse free-text errands, and a solver for ordering stops. The underlying problem is a *generalized traveling-salesman problem with time windows*.

---

## 3. How to run it

- **Simplest:** double-click `asikaso.html`; it opens in any desktop browser. It's one self-contained file. Only the Google Font (Figtree) needs internet.
- **Or serve it:** in this folder, run `python -m http.server 8765`, then open `http://localhost:8765/asikaso.html`.
- On desktop it shows a phone frame with notes beside it. Below 760px wide it fills the screen like a real phone.

**Demo deep links** (add to the end of the URL to jump straight to a screen):

| Hash | Opens |
|---|---|
| `#plan` | Plan result (everything fits, home by 5:30) |
| `#late` | Plan with a 5:00 PM deadline: the "Didn't fit today" section |
| `#trip` | On-the-trip screen (stop 3 of 5) |
| `#done` | Trip finished: save stops as a recurring template |
| `#from` | Map picker for the start point |
| `#pick` | Errands in Pick mode, first errand expanded |
| `#edit` | Write mode with Advanced settings open |
| `#stock` | Today with the "Weekly Stock" template added (10 errands) |
| `#recurring` | Recurring templates list |
| `#template` | Template editor (Weekly Stock) |
| `#newtpl` | Create a new template |
| `#settings` | Settings |

---

## 4. Screens and flow

Bottom tabs: **Today · Recurring · Settings**.

1. **Today (main module)**: a single **route card** that reads top to bottom:
   - **From**: tap to choose on a full-screen map (drop a pin or pick a saved place).
   - **Errands**: a collapsible section between From and To:
     - Toolbar: **Write | Pick** switch and a **Clear** button (with Undo).
     - **Templates** chip row: one tap adds or removes a recurring template's errands.
     - **Write mode:** a notepad. One errand per line in plain English or Taglish (e.g. "Sunduin si jowa sa Ortigas 3pm"). Below it, **"Asikaso understood"** shows the system's reading of each line as chips (time rule, place, duration, priority). A collapsed **Advanced settings** section holds per-errand structured controls.
     - **Pick mode:** the same errands as a numbered, expandable list (the same component as the template editor), with "+ Add errand".
   - **To**: tap to choose on the map.
   - **Leave · Home by · Travel**: tap to edit the times and travel mode in a sheet.
   - Then **Plan my day**.
2. **Map picker**: full-screen map, saved-place chips, tap to drop a pin, then "Start here" or "End here".
3. **Plan result**: **map on top** (numbered pins, route following the street grid) and a **planner sheet** below:
   - A summary line ("Kasya lahat. Home by 5:30 PM, 30 min before your 6:00 PM deadline.").
   - A timeline of stops showing times, the chosen branch, and tags (Fixed / Before X / Anytime, Best fit).
   - **Change** on any flexible stop opens a branch picker showing how each option shifts the arrival time.
   - A **Didn't fit today** section with *Move to tomorrow / Shorten / Make it a must*.
   - **Start trip** at the bottom.
4. **On the trip**: the current leg's card (leave, travel time, arrive), **Go with Google Maps** or **Waze**, **Done**, **Running late** (re-plans the rest of the day), and the list of today's stops.
5. **Trip finished**: a summary, then "Save as a recurring template?" (choose stops, name, repeat).
6. **Recurring**: a list of **template cards**. Each shows name, repeat schedule and next date, a numbered list of errands (1, 2, 3, …) with a plain tag each, and **Add to today** / **Edit**. **+** creates a template.
   - **Template editor** (sheet): name, repeats (Weekly / Every 2 weeks / Monthly) and day, then an errand list. Each errand expands to: What, **Type: Flexible / Fixed / Closing**, and only the controls for that type. There's "+ Add errand", Save and Delete.
7. **Settings**: saved places, default travel mode, extra time per stop, default durations per category, language (English / Filipino), avoid tolls.

---

## 5. Files in this folder

| File | What it is |
|---|---|
| `asikaso.html` | **The whole prototype**: HTML, CSS and JS in one file, about 1,400 lines. |
| `CONTEXT.md` | This file. |
| `PRODUCT.md` | Product truth: users, purpose, positioning, constraints, principles. |
| `DESIGN.md` | The design system as built: tokens, type, components, rules. Follow it. |
| `.impeccable/design.json` | Machine-readable version of DESIGN.md (used by the Impeccable design skill). |
| `.impeccable/surfaces/asikaso-html.md` | Design brief and "direction contract" for the prototype. |
| `docs/screenshots/*.png` | Screenshots of every screen at 390×844 (phone) and 1440×900 (desktop). |
| `AGENTS.md`, `CLAUDE.md` | Short pointers telling AI tools to read this file. |

### Code map of `asikaso.html`

Search for these comment headers in the file:

- **CSS**
  - `:root` tokens (colors, radius, shadow, easing).
  - Sections: `/* route card */`, `/* notepad */`, `/* advanced settings */`, `/* templates */`, `/* place picker */`, `/* map */`, `/* plan sheet */`, `/* trip screen */`, `/* sheet */`, `/* toast */`.
- **Markup:** one `<section class="screen">` per screen, namely `s-today`, `s-place`, `s-plan`, `s-trip`, `s-done`, `s-recurring`, `s-settings`, plus a shared bottom `sheet`, `scrim` and `toast`.
- **JS sections**
  - `icons`: the inline SVG icon set (`icon(name)`).
  - `places & catalog`: `PLACES` (sample places with x/y map coordinates; branches carry a `cat`) and `CATS` (categories and default durations; `any:true` means a flexible, any-branch category).
  - `state`: the global `S` (trip, settings, errands, templates, plan, run).
  - `simulated AI reading`: `interpret(text, prev)` turns a typed line into an errand using regex rules for times, keywords, Taglish phrases, "after", "pauwi" (on the way home) and "kung may time" (if there's time). **Swap this for a real LLM call later.**
  - `planner`: `travel()` (fake minutes from map distance and mode), `evaluate()`, `bestFor()` (exhaustive search for 6 or fewer errands), `searchBest()` (seeded local search for bigger days), `solve()` (drops "if there's time" errands until the day fits, or reports a conflict).
  - `TODAY`: route card, notepad sync (`syncFromNotes`: the notepad is the source of truth, one line per errand, matched by text), read-out chips, Advanced settings, Pick list (`errandView` / `viewToErrand`), Clear with Undo, times sheet, map picker.
  - `MAP`: `baseMap()`, `mapLabels()`, `mapSVG()` (route legs turn once along the street grid and pick the turn direction with the fewest self-crossings; nearby pins merge into one, e.g. "3·4").
  - `PLAN`, `TRIP`, `TEMPLATES (recurring)`, `DONE`, `SETTINGS`, `boot`, and `deep links`.

### Data shapes
```js
// errand (today)
{ id, text /* the typed line */, title, kind: 'any'|'specific', cat, place,
  when: 'any'|'before'|'at', t1, t2 /* minutes after midnight */, dur, must,
  after /* errand id */, last /* on the way home */, review /* needs a place */,
  tpl, tplName /* if added from a template */ }

// template
{ id, name, freq: 'Weekly'|'Every 2 weeks'|'Monthly', day, items: [
  { id, title, type: 'flexible'|'fixed'|'closing', cat, place, t1, t2, close, dur, must } ] }
```

---

## 6. Design direction (summary; full rules in DESIGN.md)

- The owner asked for: **simple, little color, like established apps (Life360, Google Maps, Waze, Notion)**. Don't base the look on the app's name or on Filipino folk motifs (both directions were tried and rejected).
- White background, warm-gray surfaces (#F6F6F4), ink #191919, hairlines #E7E7E4. Font: **Figtree**. Times use tabular numerals.
- **Blue (#2F5CFF) is only for the route**, pins, links and focus. **Black means chosen** (selected chips, primary buttons). **Green / amber / red only for fits / tight / didn't fit.**
- Line icons with one consistent stroke. Shadows only on things that float (sheets, map buttons).
- The map is a stylized illustration of the Pasig/Ortigas area, not real tiles.

---

## 7. Decisions log

- No public-commute travel mode; only Car, Motorcycle and Walk.
- From and To are chosen **on a map**, not from a list.
- The errand section sits **between From and To** as a collapsible part of the route card.
- Errands are typed like a **notepad** first; the structured form is secondary (Advanced settings / Pick).
- The old checkbox-style "Pick" list was replaced by the numbered errand list.
- Recurring = **templates** (groups of errands), not single recurring tasks.
- Users can choose the **branch** of any flexible stop on the plan.
- Running late re-plans the rest of the day.

---

## 8. Owner feedback: likes and dislikes (current as of 2026-10-14)

> The owner's verdict on this version: *"not quite satisfied but it will suffice."* They will keep improving the prototype before development. **Keep what they like. Rework what they dislike.**

### Likes (keep these)
1. **The main module's concept: simple trip input.** Enter a **start point** and a **final destination**, with the **errands in between**. The From, Errands, To structure is right.
2. **The Plan my day result.** The **map** together with the **planner** below it, the clear split between **fixed** things and **flexible** stuff, and being able to **change the location (branch)** of a flexible task.
3. **The Recurring list (outside view).** Each template is a **card** that lists its errands **neatly as 1, 2, 3, 4, 5**.

### Dislikes (rework these)
1. **Adding errands in between From and To looks cluttered and ugly.** The Errands section currently stacks too much: the Write/Pick switch, Clear, the template chip row, the notepad, the "Asikaso understood" chip list, and the Advanced settings accordion with a full form. It needs a much simpler, calmer way to add and see errands.
2. **Adding and editing errands is extremely cluttered**, both in the **template editor** (Recurring) and in **Plan my day's errand input**. Each errand expands into a long form (What, type switch, place, time, duration chips, priority, order, remove) stacked inside accordions inside a sheet. It needs a simpler editing pattern.

### Notes for whoever changes this next
These are suggestions, not owner decisions; confirm with the owner.
- Keep the route card's From, Errands, To spine and the plan screen's map-plus-planner layout as they are.
- For errand input and editing, aim for **one obvious way to add an errand** and a **compact list** (like the Recurring card's numbered list), with details edited in a **focused single-errand screen or sheet**, not inline accordions.
- Show fewer controls at once: progressive disclosure, sensible defaults, and the typed sentence doing most of the work.
- The look and feel the owner likes is the Recurring card style: numbered rows, one plain tag each, lots of breathing room.
