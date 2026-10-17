"""PostGIS catalog adapter. Explicit configuration; no silent file fallback."""
import json
from pathlib import Path

from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError
from wayday_api.places.catalog import BROAD_AREA_CATEGORIES, CatalogUnavailable, FileCatalog, Place, normalize


class PostgisCatalog:
    def __init__(self, url):
        try:
            self.engine = create_engine(url, pool_size=3, max_overflow=0, pool_timeout=2,
                                        connect_args={"connect_timeout": 3, "options": "-c statement_timeout=2000"})
            with self.engine.connect() as conn:
                date = conn.execute(text("""SELECT max(source_date) FROM catalog_imports
                    WHERE id IN (SELECT DISTINCT import_id FROM places)""")).scalar()
                if date is None:
                    raise CatalogUnavailable("Catalog has not been imported")
                self.source_date = date.isoformat()
        except SQLAlchemyError as e:
            raise CatalogUnavailable("Catalog database unavailable") from e

    def _read(self, statement, params, near):
        try:
            with self.engine.connect() as conn:
                rows = conn.execute(text(statement), params)
                return [{**Place(**{**row[0], "aliases": tuple(row[0]["aliases"])}).payload(near),
                         **({'match_kind': row[1]} if len(row) > 1 else {})} for row in rows]
        except SQLAlchemyError as e:
            raise CatalogUnavailable("Catalog query unavailable") from e

    def search(self, q, limit, near):
        query = normalize(q)
        if not query:
            return []
        tokens = query.split()
        params = {f"t{i}": f"%{token}%" for i, token in enumerate(tokens)}
        params.update(q=query, prefix=query + "%", limit=limit,
                      lat=near[0] if near else 14.5764, lon=near[1] if near else 121.0851)
        where = " AND ".join(f"(p.search_text LIKE :t{i} OR EXISTS (SELECT 1 FROM place_corrections c, unnest(c.verified_aliases) a WHERE c.source_id=p.source_id AND a LIKE :t{i}))" for i in range(len(tokens)))
        return self._read(f"""SELECT p.payload FROM places p WHERE {where}
            ORDER BY CASE WHEN name_key=:q OR :q=ANY(aliases) THEN 0 WHEN name_key LIKE :prefix THEN 1 ELSE 2 END,
            ST_Distance(position,ST_SetSRID(ST_MakePoint(:lon,:lat),4326)::geography), source_id LIMIT :limit""", params, near)

    def nearby(self, lat, lon):
        covered = "payload->>'category' <> ALL(:broad) AND ST_Covers(footprint,ST_SetSRID(ST_MakePoint(:lon,:lat),4326))"
        return self._read(f"""SELECT payload,
            CASE WHEN {covered} THEN 'area'
                 WHEN payload->>'category' <> ALL(:broad) AND payload->>'coordinate_kind'='mapped_point' AND
                      ST_DWithin(position,ST_SetSRID(ST_MakePoint(:lon,:lat),4326)::geography,10) THEN 'point'
                 ELSE 'nearby' END AS match_kind
            FROM places WHERE
                ({covered}) OR
                ST_DWithin(position,ST_SetSRID(ST_MakePoint(:lon,:lat),4326)::geography,100)
            ORDER BY CASE WHEN {covered} THEN 0 ELSE 1 END,
                CASE WHEN {covered}
                     THEN ST_Area(footprint)
                     ELSE ST_Distance(position,ST_SetSRID(ST_MakePoint(:lon,:lat),4326)::geography) END,
                source_id LIMIT 3""", {"lat":lat,"lon":lon,"broad":list(BROAD_AREA_CATEGORIES)}, (lat,lon))


def import_snapshot(url: str, path: Path):
    catalog = FileCatalog(path)  # Validate the entire snapshot before any write.
    raw = json.loads(path.read_text(encoding="utf-8"))
    engine = create_engine(url, connect_args={"connect_timeout": 3})
    migrations = Path(__file__).resolve().parents[3] / "migrations"
    try:
        with engine.begin() as conn:
            conn.execute(text("SELECT pg_advisory_xact_lock(73190423)"))
            for migration in sorted(migrations.glob('*.sql')):
                conn.exec_driver_sql(migration.read_text(encoding="utf-8"), execution_options={"no_parameters": True})
            conn.execute(text("""INSERT INTO catalog_imports(id,source_url,source_date,bounds) VALUES (:id,:url,:date,CAST(:bounds AS jsonb)) ON CONFLICT(id) DO NOTHING"""),
                         {"id":raw["md5"],"url":raw["source_url"],"date":raw["source_date"],"bounds":json.dumps(raw["bounds"])})
            conn.execute(text("""INSERT INTO places(source_id,import_id,name_key,aliases,search_text,position,payload,footprint)
                VALUES (:id,:import_id,:name,:aliases,:search,ST_SetSRID(ST_MakePoint(:lon,:lat),4326)::geography,CAST(:payload AS jsonb),
                    ST_SetSRID(ST_GeomFromGeoJSON(:footprint),4326))
                ON CONFLICT(source_id) DO UPDATE SET import_id=EXCLUDED.import_id,name_key=EXCLUDED.name_key,
                aliases=EXCLUDED.aliases,search_text=EXCLUDED.search_text,position=EXCLUDED.position,payload=EXCLUDED.payload,
                footprint=EXCLUDED.footprint"""),
                [{"id": p.id,"import_id":raw["md5"],"name":normalize(p.name),"aliases":[normalize(a) for a in p.aliases],
                  "search":normalize(" ".join([p.name,*p.aliases,p.address or "",p.category])),"lat":p.latitude,"lon":p.longitude,"payload":json.dumps(row),
                  "footprint":json.dumps(p.footprint) if p.footprint else None}
                 for p,row in zip(catalog.places,raw["places"])])
            # Extract checksums can stay the same when the importer changes.
            # Synchronize the actual snapshot membership, not just its checksum.
            conn.execute(text("DELETE FROM places WHERE source_id <> ALL(:ids)"),
                         {"ids": [p.id for p in catalog.places]})
    finally:
        engine.dispose()
