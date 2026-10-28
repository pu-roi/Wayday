CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE TABLE IF NOT EXISTS catalog_imports (
    id text PRIMARY KEY,
    source_url text NOT NULL,
    source_date timestamptz NOT NULL,
    imported_at timestamptz NOT NULL DEFAULT now(),
    bounds jsonb NOT NULL
);
CREATE TABLE IF NOT EXISTS places (
    source_id text PRIMARY KEY,
    import_id text NOT NULL REFERENCES catalog_imports(id),
    name_key text NOT NULL,
    aliases text[] NOT NULL,
    search_text text NOT NULL,
    position geography(Point,4326) NOT NULL,
    payload jsonb NOT NULL
);
CREATE INDEX IF NOT EXISTS places_position ON places USING gist(position);
CREATE INDEX IF NOT EXISTS places_search ON places USING gin(search_text gin_trgm_ops);
-- Source corrections survive catalog refresh/removal and are never OSM edits.
CREATE TABLE IF NOT EXISTS place_corrections (
    source_id text PRIMARY KEY,
    verified_aliases text[] NOT NULL DEFAULT '{}',
    evidence_url text NOT NULL,
    verified_at timestamptz NOT NULL,
    note text NOT NULL
);
