# Pilot place coverage audit

Updated 2026-10-18. M2-04 remains in progress. A successful import is not evidence that every local place, entrance or opening hour is correct. Record missing places and source-backed fixes here; do not add invented coordinates or hours.

| Report | Source evidence | Cause and action | Remaining verification |
| --- | --- | --- | --- |
| Grand Monaco La Impreza, San Nicolas, Pasig missing from search | [OSM relation 17592405](https://www.openstreetmap.org/relation/17592405) is present in the downloaded 2026-10-17 extract as named residential landuse. [Pasig City's published schedule](https://assets.pasigcity.gov.ph/storage/downloadables/2026/01/19/696df3c33a2e61768813507Pasig%20City%20-%20Proposed%20Schedule%20of%20Market%20Values%20for%20General%20Revision%202027.pdf) also lists the name under San Nicolas; it does not establish a map entrance. | The importer excluded residential-only records. Named residential areas are now included; PostGIS, file mode and Android selection return this source-backed result. | The OSM record labels its geometry source as extrapolation. Verify boundaries/entrance independently; address and hours remain unknown. Do not treat the naming fix as field certification. |
| PLP pin labelled Dropped pin despite being inside the campus | [OSM relation 12541314](https://www.openstreetmap.org/relation/12541314) supplies the university's mapped area. | Previously only its representative point was stored. Optional footprints and containing-place lookup now retain the name when the pin moves within the mapped campus; Android verified at a selected point distinct from its representative point. | A mapped campus boundary is not a verified gate or entrance. Physical access and real GPS remain unverified. |

The current pilot has 13,033 records, including residential areas and place/neighbourhood records, within the existing fixed bounds. Broad city/neighbourhood boundaries can be searched but do not automatically identify a business pin. The dataset remains incomplete, and source timestamps do not establish real-world accuracy.

Next audit a representative set of schools/landmarks, pharmacies, groceries, banks and cafés. Record source IDs, terms tried, branch identity, address/category gaps, independently checked evidence and date, geometry/entrance uncertainty, and missing/unverified hours. Distinguish an import-filter issue, alias/ranking issue, source omission and outside-pilot result. General catalog editing and field-sourced corrections beyond aliases remain separate implementation work.

See [the task board](../../PLANNING.md), [run modes](RUNNING_WAYDAY.md) and [API contract](../../services/api/README.md).
