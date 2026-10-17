-- Additive upgrade: existing point records and corrections are preserved.
ALTER TABLE places ADD COLUMN IF NOT EXISTS footprint geometry(MultiPolygon,4326);
CREATE INDEX IF NOT EXISTS places_footprint ON places USING gist(footprint);
