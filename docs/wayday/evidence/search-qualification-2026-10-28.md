# Multi-provider search qualification, 2026-10-28

This is a small deliberate live API qualification, not nationwide coverage, current-business, entrance, or physical-device verification. The fixed public-place sample contains streets, stores/malls, restaurants/branches, and markets in Luzon, Visayas, and Mindanao. Three additional marketplace searches use five-kilometer circles around Pasig, Cebu, and Davao. The [sanitized candidate record](search-qualification-2026-10-28.json) retains public names, addresses, positions, source identifiers, status, and name-search latency; no keys, full request URLs, private errands, or personal locations are recorded.

## Requests and access

- Geoapify: 12 named searches and three marketplace searches returned successful API responses. One additional response-shape inspection confirmed that its autocomplete payload does not expose raw OSM identifiers. Total attempted Geoapify calls: 16.
- LocationIQ: the same 12 named searches and three marketplace searches returned successful responses. Total attempted LocationIQ calls: 15.
- Photon: the first request returned access denied. The runner disabled it for the remaining sample rather than repeatedly retrying. Total attempted Photon calls: one. The cause of the host-specific denial is not established.
- Total: 32 attempts, including the one diagnostic request. This is client-observed accounting, not dashboard-reported consumption. Account dashboard access was not available; the owner must compare dashboard totals, which may include other devices and experiments.

## Manual review of returned candidates

| Query | Observation |
| --- | --- |
| Taft Avenue Manila | Geoapify returned street candidates directly. LocationIQ also returned nearby institutions and a station, illustrating why name relevance and street/POI distinction matter. |
| SM Megamall | Both returned the mall and individual buildings. Different building/source records must not be flattened into one assumed entrance. |
| Carbon Public Market Cebu | Both returned Carbon Main, Interim, Unit 1, and Unit 3 market candidates. LocationIQ also returned Bogo Public Market; that is not an equivalent branch of Carbon. |
| Osmena Boulevard Cebu | Geoapify returned Osmeña Boulevard directly. LocationIQ included it alongside institutions. |
| Metro Supermarket Colon Cebu | LocationIQ contributed named supermarket candidates; Geoapify's candidates were streets/localities. This is a concrete additional relevant candidate family, but branch identity and entrance accuracy remain unverified. |
| Larsian Cebu | Both returned a Larsian candidate. |
| Bankerohan Public Market Davao | Both returned a Bankerohan Public Market candidate. |
| San Pedro Street Davao | Both returned street and related landmark candidates. |
| Gaisano Mall Davao | LocationIQ included Gaisano Mall of Davao; both also returned other buildings/tenants or branches. Retain the address and do not equate a tenant with the mall. |
| Jollibee Cubao / Jollibee Davao | Multiple brand-matching candidates were returned. A matching brand alone does not verify the intended branch. |
| Pasig Mega Market | Both included loosely matching names alongside public-market candidates. Do not label the first response an exact match. |
| Marketplace circles | Both providers returned local markets in all three areas. Some records were unnamed and the initial decoder fell back to street labels. The final decoder displays a category name with “name not recorded” for those records. The JSON preserves what the initial qualification actually returned rather than rewriting historical evidence. |

No complete-list or accuracy percentage is inferred from this sample. Differences in candidate names are not proof of independent datasets. Geoapify autocomplete omits shared OSM IDs in the inspected response; conservative name/position/address comparison therefore leaves ambiguous duplicate records visible.

## Automated and Android checks

Fixture tests cover provider parameters, Philippine and radius filtering, typed errors, metadata roundtrips, debounce, shared in-flight work, stale-response rejection, partial failures, reservations/cooldowns across ledger recreation, fail-closed accounting, local-area categories, explicit search-area navigation, cache TTL/LRU, and stable merging/attribution. They do not contact live services.

The full suite retains the nine failures recorded before this implementation (native MapLibre widget lifecycle and stale earlier map expectations). Compare exact failure names rather than merely comparing counts. No test uses automatic uninstall on the owner's device. Physical Android search, IME behavior, location permission, performance, and TalkBack verification remain required.
