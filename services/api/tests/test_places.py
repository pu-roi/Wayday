import json
from dataclasses import asdict, replace
from pathlib import Path
import importlib.util

import pytest
from fastapi.testclient import TestClient
from wayday_api.app import create_app
from wayday_api.places.catalog import BOUNDS, CatalogUnavailable, FileCatalog, Place, inside, metres


@pytest.fixture
def catalog(tmp_path):
    # Synthetic fixtures; no downloaded geography is committed to this test.
    places = [
        Place('osm/node/1', 'Synthetic University', 'Example Street',14.56,121.075,'school',('SU',),None,'2026-10-17T01:00:00Z'),
        Place('osm/node/2', 'Synthetic Pharmacy', None,14.57,121.08,'pharmacy',(), 'Mo-Fr 09:00-17:00','2026-10-17T01:00:00Z'),
    ]
    path=tmp_path/'places.json'
    path.write_text(json.dumps({'bounds':BOUNDS,'source_date':'2026-10-17T01:00:00Z','places':[asdict(p) for p in places]}),encoding='utf-8')
    return FileCatalog(path)


def test_search_alias_and_source_unknowns(catalog):
    result = TestClient(create_app(catalog)).get('/v1/places',params={'q':'SU'})
    assert result.status_code == 200
    data=result.json()
    assert data['places'][0]['name']=='Synthetic University'
    assert data['places'][0]['hours_status']=='unknown'
    assert data['places'][0]['source_url']=='https://www.openstreetmap.org/node/1'
    assert data['coverage']['bounds']==list(BOUNDS)
    assert result.headers['Cache-Control']=='no-store'


@pytest.mark.parametrize('params',[{'q':'a'},{'q':'x'*101},{'q':'name','limit':99},{'q':'name','near_lat':14.56},{'q':'name','near_lat':999,'near_lon':121}])
def test_bounded_requests(catalog,params):
    assert TestClient(create_app(catalog)).get('/v1/places',params=params).status_code==422


def test_no_match_is_not_outage(catalog):
    client=TestClient(create_app(catalog))
    assert client.get('/v1/places',params={'q':'not mapped'}).json()['places']==[]
    assert client.get('/v1/places',params={'q':"'; DROP TABLE places; --"}).json()['places']==[]
    assert client.get('/v1/places/nearby',params={'lat':0,'lon':0}).json()['places']==[]
    places=client.get('/v1/places/nearby',params={'lat':14.56,'lon':121.075}).json()['places']
    assert places[0]['distance_metres']==0


def test_missing_catalog_is_explicit_503(monkeypatch,tmp_path):
    monkeypatch.setenv('WAYDAY_CATALOG_MODE','file')
    monkeypatch.setenv('WAYDAY_CATALOG_PATH',str(tmp_path/'missing'))
    result=TestClient(create_app()).get('/v1/places',params={'q':'school'})
    assert result.status_code==503
    assert result.json()['detail']['code']=='catalog_unavailable'


@pytest.mark.parametrize('origin', ['http://localhost:3000', 'http://127.0.0.1:8080'])
def test_local_browser_origins_can_read_places(catalog, origin):
    result = TestClient(create_app(catalog)).get('/v1/places', params={'q': 'school'}, headers={'Origin': origin})
    assert result.headers['access-control-allow-origin'] == origin


def test_nonlocal_browser_origin_is_not_allowed(catalog):
    result = TestClient(create_app(catalog)).get('/v1/places', params={'q': 'school'}, headers={'Origin': 'http://localhost.example.com:3000'})
    assert 'access-control-allow-origin' not in result.headers


def test_geometry_bounds_and_metric_distance(catalog):
    assert inside(14.56,121.075)
    assert not inside(121.075,14.56)
    assert 1000 < metres(14.56,121.075,14.57,121.075) < 1200
    assert catalog.search('pharmacy',8,None)[0]['hours_status']=='unverified'


def test_import_record_alias_and_out_of_area():
    spec=importlib.util.spec_from_file_location('import_places',Path(__file__).parents[1]/'tools/import_places.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    tags={'name':'Synthetic College of Testing','amenity':'college','addr:street':'Test Avenue'}
    p=module.record('osm/node/99',tags,14.56,121.075,'2026-10-17T00:00:00Z','mapped_point')
    assert 'SCT' in p.aliases and p.opening_hours is None
    assert module.record('osm/node/99',tags,1,2,'2026-10-17T00:00:00Z','mapped_point') is None
    residential = module.record('osm/relation/99', {'name':'Synthetic Residential Village','landuse':'residential'},14.56,121.075,'2026-10-17T00:00:00Z','area_representative_point')
    assert residential is not None and residential.category == 'residential'


def test_file_map_identity_uses_boundaries_not_nearest_centroid(tmp_path):
    footprint = {'type':'MultiPolygon','coordinates':[[
        [[121.074,14.559],[121.079,14.559],[121.079,14.563],[121.074,14.563],[121.074,14.559]],
        [[121.0775,14.561],[121.078,14.561],[121.078,14.562],[121.0775,14.562],[121.0775,14.561]],
    ]]}
    p = Place('osm/relation/1','Synthetic campus',None,14.56,121.075,'school',(),None,'2026-10-17T00:00:00Z','area_representative_point',footprint)
    path=tmp_path/'area.json'
    city = replace(p,id='osm/relation/2',name='Synthetic City',category='city')
    path.write_text(json.dumps({'bounds':BOUNDS,'source_date':p.source_date,'places':[asdict(p),asdict(city)]}),encoding='utf-8')
    client=TestClient(create_app(FileCatalog(path)))
    result=client.get('/v1/places/nearby',params={'lat':14.56,'lon':121.077}).json()['places']
    assert result[0]['name']=='Synthetic campus' and result[0]['match_kind']=='area'
    assert result[0]['distance_metres'] > 100  # Still inside the actual footprint.
    assert len(result)==1  # Broad city boundaries do not name a business pin.
    assert 'footprint' not in result[0]  # Geometry stays on the server.
    assert client.get('/v1/places/nearby',params={'lat':14.5615,'lon':121.0777}).json()['places']==[]
    assert client.get('/v1/places/nearby',params={'lat':14.559,'lon':121.077}).json()['places'][0]['match_kind']=='area'
