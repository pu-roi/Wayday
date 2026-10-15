---
name: wayday-database
description: Plan, implement, or review Wayday Drift/SQLite persistence, PostgreSQL/PostGIS catalogs, SQLAlchemy repositories, Alembic migrations, spatial queries, and data imports. Use for data storage changes rather than HTTP wire contracts.
---

# Wayday database

Read the root `AGENTS.md`, the storage boundaries in [Architecture](../../../docs/wayday/ARCHITECTURE.md), and the data policies in [Stack](../../../docs/wayday/STACK.md). The current foundation has no application database or migration history; do not create one unless runtime work is authorized.

## Choose the correct data owner

- Drift/SQLite owns personal errands, template copies, saved places, saved itineraries, reminder identities, and trip progress on the phone.
- PostgreSQL/PostGIS owns the regional place catalog and suitable reusable route-cache data. Backend calculation requests are not permission to persist personal tasks or history.
- Supabase is a future PostgreSQL hosting option. Do not introduce its auth, synchronization, or client database access merely to add storage.

Load `wayday-mobile` for changes to local behavior, `wayday-backend` for server repository/transaction work, and `wayday-planning` when stored fields change itinerary meaning. Keep API serialization decisions in `wayday-api`.

## Preserve data meaning

Use stable IDs and explicit relationships for template copies and dependencies. Copying a template remaps internal references; editing today's copy does not update the original template. Keep original text, confirmed values, unknown values, and suggestions distinguishable.

Store enough itinerary metadata to restore progress offline and detect stale plans. Preserve the transportation profile and relevant restrictions in route-cache keys together with graph/version identity. Model dates, timezones, and durations consistently with the planning contract rather than treating minutes-after-midnight as a complete timestamp.

For OSM imports, retain source identifiers, source dates, and original hours information. Use an import/update strategy that avoids duplicate catalog entries and does not overwrite separately sourced corrections. Missing hours and restrictions remain unknown. Keep OSM provenance and redistribution requirements separate from application licensing.

Choose and document spatial types, SRID, coordinate ordering, and distance units for each query. Verify that nearby searches are bounded and use appropriate indexes. A fast query over the wrong units or swapped coordinates is still incorrect.

## Migrate and verify deliberately

Inspect the current schema, consumers, and migration history before changing fields. For real databases, identify the target and current authorization before executing migrations. Prepare data-preserving transformations and a recovery approach for destructive changes; do not assume rollback can recover deleted data. Test on synthetic or authorized disposable data before touching valuable state.

When code exists, verify clean setup and upgrades from the prior supported schema. Exercise app restart, dependency/template integrity, import reruns, and affected spatial query behavior. Review query plans when a change affects catalog scale rather than adding speculative indexes. Keep downloaded extracts, database files, dumps, credentials, and private coordinates out of source control; use small synthetic fixtures for tests.
