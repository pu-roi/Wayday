"""Opt-in integration checks against disposable, local PostGIS databases.

WAYDAY_TEST_DATABASE_URL must point to the local Wayday development server.
Each test creates and drops its own uniquely named database; the pilot catalog
and any other databases are never cleared or used as test fixtures.
"""
from dataclasses import asdict, replace
import json
import os
from uuid import uuid4

from fastapi.testclient import TestClient
import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import DBAPIError

from wayday_api.app import create_app
from wayday_api.places.catalog import BOUNDS, Place
from wayday_api.places.postgis import PostgisCatalog, import_snapshot


@pytest.fixture
def database_url():
    configured = os.environ.get("WAYDAY_TEST_DATABASE_URL")
    if not configured:
        pytest.skip("Set WAYDAY_TEST_DATABASE_URL for local PostGIS integration checks")
    base = make_url(configured)
    if base.host not in {"127.0.0.1", "localhost"} or base.port != 55432:
        pytest.fail("Integration checks require the local Wayday port 55432")
    name = "wayday_verify_" + uuid4().hex
    admin = create_engine(base.set(database="postgres"), isolation_level="AUTOCOMMIT",
                          connect_args={"connect_timeout": 3, "options": "-c statement_timeout=15000"})
    with admin.connect() as conn:
        conn.exec_driver_sql(f'CREATE DATABASE "{name}"')
    try:
        yield base.set(database=name).render_as_string(hide_password=False)
    finally:
        # Generated identifier only; never drop the configured pilot database.
        assert name.startswith("wayday_verify_") and len(name) == 46
        with admin.connect() as conn:
            conn.exec_driver_sql(f'DROP DATABASE "{name}" WITH (FORCE)')
        admin.dispose()


@pytest.fixture
def snapshot(tmp_path):
    places = [
        Place("osm/node/1", "Synthetic School", "Example Street", 14.56,
              121.075, "school", ("SS",), None, "2026-10-17T01:00:00Z"),
        Place("osm/node/2", "Synthetic Pharmacy", None, 14.57,
              121.08, "pharmacy", (), "Mo-Fr 09:00-17:00", "2026-10-17T01:00:00Z"),
    ]

    def write(rows=places, revision="synthetic-first", date="2026-10-17T01:00:00Z"):
        path = tmp_path / f"{revision}.json"
        path.write_text(json.dumps({
            "md5": revision, "bounds": BOUNDS,
            "source_url": "https://example.invalid/synthetic.osm.pbf",
            "source_date": date, "places": [asdict(p) for p in rows],
        }), encoding="utf-8")
        return path

    return places, write


def test_import_is_repeatable_and_preserves_provenance(database_url, snapshot):
    _, write = snapshot
    path = write()
    import_snapshot(database_url, path)
    import_snapshot(database_url, path)
    repo = PostgisCatalog(database_url)
    try:
        with repo.engine.connect() as conn:
            assert conn.execute(text("SELECT count(*) FROM places")).scalar() == 2
            assert conn.execute(text("SELECT count(*) FROM catalog_imports")).scalar() == 1
        school = repo.search("SS", 8, None)[0]
        assert school["id"] == "osm/node/1"
        assert school["source_url"] == "https://www.openstreetmap.org/node/1"
        assert school["hours_status"] == "unknown"
        assert repo.search("pharmacy", 8, None)[0]["hours_status"] == "unverified"
    finally:
        repo.engine.dispose()


def test_refresh_updates_removes_and_preserves_corrections(database_url, snapshot):
    places, write = snapshot
    import_snapshot(database_url, write())
    engine = create_engine(database_url, connect_args={"connect_timeout": 3})
    try:
        with engine.begin() as conn:
            conn.execute(text("""INSERT INTO place_corrections
                (source_id,verified_aliases,evidence_url,verified_at,note)
                VALUES ('osm/node/1',ARRAY['verified academy'],
                'https://example.invalid/evidence',now(),'Synthetic test evidence')"""))
        updated = replace(places[0], name="Synthetic Updated School",
                          source_date="2026-10-18T01:00:00Z")
        import_snapshot(database_url, write([updated], "synthetic-second", updated.source_date))
        repo = PostgisCatalog(database_url)
        try:
            result = repo.search("verified academy", 8, None)
            assert len(result) == 1 and result[0]["name"] == updated.name
            assert repo.search("pharmacy", 8, None) == []
            assert repo.source_date.startswith("2026-10-18")
        finally:
            repo.engine.dispose()
        # Corrections remain source-linked even if their place leaves the extract.
        import_snapshot(database_url, write([places[1]], "synthetic-third"))
        with engine.connect() as conn:
            assert conn.execute(text("SELECT count(*) FROM place_corrections")).scalar() == 1
        repo = PostgisCatalog(database_url)
        try:
            # Readiness describes the active snapshot, not a newer historical import.
            assert repo.source_date.startswith("2026-10-17")
        finally:
            repo.engine.dispose()
    finally:
        engine.dispose()


def test_failed_refresh_rolls_back_every_write(database_url, snapshot):
    places, write = snapshot
    import_snapshot(database_url, write())
    engine = create_engine(database_url, connect_args={"connect_timeout": 3})
    try:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE places ADD CONSTRAINT reject_test_failure CHECK (name_key NOT LIKE '%reject%')"))
        rows = [replace(places[0], name="Changed before failure"),
                replace(places[1], name="Reject this synthetic record")]
        with pytest.raises(DBAPIError):
            import_snapshot(database_url, write(rows, "synthetic-failed"))
        with engine.connect() as conn:
            assert conn.execute(text("SELECT payload->>'name' FROM places WHERE source_id='osm/node/1'")).scalar() == places[0].name
            assert conn.execute(text("SELECT count(*) FROM catalog_imports WHERE id='synthetic-failed'")).scalar() == 0
            assert conn.execute(text("SELECT count(*) FROM places")).scalar() == 2
    finally:
        engine.dispose()


def test_reimport_same_extract_removes_obsolete_snapshot_records(database_url, snapshot):
    places, write = snapshot
    import_snapshot(database_url, write())
    # Importer changes can alter the read model without changing extract MD5.
    import_snapshot(database_url, write([places[0]]))
    repo = PostgisCatalog(database_url)
    try:
        assert repo.search("pharmacy", 8, None) == []
        assert repo.search("SS", 8, None)[0]["id"] == "osm/node/1"
    finally:
        repo.engine.dispose()


def test_nearby_uses_metres_and_correct_coordinate_order(database_url, snapshot):
    _, write = snapshot
    import_snapshot(database_url, write())
    repo = PostgisCatalog(database_url)
    try:
        result = repo.nearby(14.56, 121.075)
        assert [p["id"] for p in result] == ["osm/node/1"]
        assert result[0]["distance_metres"] == 0
        # Approximately 111m away, beyond the 100m neighborhood.
        assert repo.nearby(14.561, 121.075) == []
        assert repo.nearby(0, 0) == []
        assert repo.search("'; DROP TABLE places; --", 8, None) == []
    finally:
        repo.engine.dispose()


def test_footprint_upgrade_names_area_beyond_centroid_radius(database_url, snapshot):
    places, write = snapshot
    import_snapshot(database_url, write())  # Prior point-only snapshot is valid.
    footprint = {'type':'MultiPolygon','coordinates':[[
        [[121.074,14.559],[121.079,14.559],[121.079,14.563],[121.074,14.563],[121.074,14.559]],
        [[121.0775,14.561],[121.078,14.561],[121.078,14.562],[121.0775,14.562],[121.0775,14.561]],
    ]]}
    area = replace(places[0], footprint=footprint, coordinate_kind='area_representative_point')
    city = replace(area,id='osm/relation/999',name='Synthetic City',category='city')
    import_snapshot(database_url, write([area, places[1], city], 'synthetic-footprint'))
    repo = PostgisCatalog(database_url)
    try:
        result = repo.nearby(14.56,121.077)
        assert result[0]['id']==area.id and result[0]['match_kind']=='area'
        assert result[0]['distance_metres'] > 100
        assert len(result)==1
        assert repo.nearby(14.5615,121.0777)==[]  # Hole is not the named place.
        assert repo.nearby(14.559,121.077)[0]['match_kind']=='area'  # Boundary included.
        assert repo.nearby(14.57,121.08)[0]['match_kind']=='point'
    finally:
        repo.engine.dispose()


def test_http_reads_postgis_and_does_not_fall_back(database_url, snapshot, monkeypatch):
    _, write = snapshot
    path = write()
    import_snapshot(database_url, path)
    monkeypatch.setenv("WAYDAY_CATALOG_MODE", "postgis")
    monkeypatch.setenv("WAYDAY_DATABASE_URL", database_url)
    # A valid file snapshot exists, but must never mask database failure.
    monkeypatch.setenv("WAYDAY_CATALOG_PATH", str(path))
    app = create_app()
    with TestClient(app) as client:
        assert client.get("/health").json()["catalog_mode"] == "postgis"
        assert client.get("/v1/places", params={"q": "SS"}).json()["places"][0]["id"] == "osm/node/1"
        repo = app.state.catalog
        try:
            with repo.engine.begin() as conn:
                conn.execute(text("ALTER TABLE places RENAME TO unavailable_test_places"))
            response = client.get("/v1/places", params={"q": "SS"})
            assert response.status_code == 503
            assert response.json()["detail"]["code"] == "catalog_unavailable"
            assert client.get("/health").status_code == 503
            with repo.engine.begin() as conn:
                conn.execute(text("ALTER TABLE unavailable_test_places RENAME TO places"))
            assert client.get("/health").status_code == 200
        finally:
            repo.engine.dispose()
