# Manual day review and map selection

Mode: Operate. Android first. Extend the existing Cornflower/Figtree system and V2 route-spine interaction; no identity replacement or concept tournament. Owner confirmed real map and editable review first, with interpretation owned by another contributor.

## Direction contract

THESIS: A day is a short, editable sequence of visits. Show the full vertical itinerary before any future trip execution; map and detail editing support that sequence.

OWN-WORLD: Existing Canvas, Cornflower actions, readable blue, compact Figtree, quiet outlines and Material controls. Do not invent recommendation badges, arrival estimates or road geometry.

STORY: Plan my day opens a local draft review. Choose a named catalog result, saved place or manual map pin, move visits and change required/optional priority, then confirm changes into Today. Back cancels the draft. Text interpretation remains independently owned; place search does not recommend a branch or schedule.

FIRST VIEWPORT: A normal Back/header pair, compact date/travel context, a restrained stop-map overview, then a connected vertical list from departure through numbered errands to destination. The anchored confirmation action remains above safe insets. Each visit names the errand and chosen place, with timing rules and editable priority. Reordering has a drag handle plus a tap-to-move alternative. The shared place chooser starts with named search suggestions and saved places, then opens a full-screen real basemap with fixed center pin, visible attribution and Confirm location. Coordinates are read-only; custom-name entry is not required. Larger text scrolls naturally in portrait. The entire Android app is locked upright; earlier landscape captures are historical evidence.

FORM: User-pinned V2-inspired vertical review inside the established Android system, code-led; seed: none (precisely specified extension; no concept roll).

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Boundaries

MapLibre/OpenFreeMap provides the map. Public tiles require connectivity and have no availability guarantee. Saved places and return to search remain available when map loading fails; manual map selection remains independent of catalog availability. Location is requested only after Use my location and is a one-time foreground fix, never shared; its UI wait is cancellable and bounded to 12 seconds, and map touches abandon pending results. The local development places API now searches real imported OSM data in verified PostgreSQL/PostGIS by default; file snapshot mode remains opt-in. M2-03 is complete; physical-location and pilot coverage checks remain open. No NLP changes, road routing, solver, feasibility verdict, live trip or notifications in this slice. Confirmation saves the reviewed day, not an optimized or actively tracked trip.

## Implemented interaction record — 2026-10-17

The source uses a 560-unit centered review column, 20-unit horizontal insets, a 200-unit rounded overview, and a numbered vertical visit spine. The overview ignores pointer input so the itinerary scrolls through it; Explore map opens a separate interactive map. The shared [place flow](mobile-places.md) uses an existing filled search field, compact Material result rows and a full-map confirmation screen with readable-blue controls and a Cornflower action. Its scrollable confirmation detail is capped at 26% of screen height above the safe-area action. Visible map credits and the interactive native attribution control remain present. Provider geography and Noto Sans map labels are external map content; Figtree and every Wayday palette, type and shape primitive remain unchanged.

The editable title, Options and drag handle have 8-unit gaps between their touch targets. Options exposes Move earlier/later, required/optional priority and focused details alongside the 48-unit drag handle. Prerequisites constrain movement without dropping visits. The bottom action is Find your way as a placeholder for the future active itinerary. It currently saves the reviewed day locally, including incomplete drafts, with the existing guards. A stale revision shows Reload Today before committing. Back cancels the review draft; Save to my places is a separate explicit local save in the chooser. Timing and visit length remain editable constraints, with assumed durations identified. No arrival estimate or availability result is generated.

Shared shell/list motion keeps its established reduced-motion behavior. Review dragging and pushed pages use native framework behavior; there is no additional authored motion vocabulary or measured performance claim. Native map rendering, pins, labels, move controls and confirmation have Android emulator evidence. Physical GPS accuracy, TalkBack, predictive Back and a live provider-outage scenario remain unverified. M2 catalog coverage remains incomplete; implementation evidence does not close that gate.
