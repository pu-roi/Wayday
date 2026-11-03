from concurrent.futures import ThreadPoolExecutor
from threading import Lock

import pytest
from fastapi.testclient import TestClient
from google.cloud import firestore
from wayday_api.gateway.app import create_gateway
from wayday_api.gateway.config import GatewayFailure, Settings
from wayday_api.gateway.ledger import FirestoreLedger


class Snapshot:
    def __init__(self, value):
        self.value = value
        self.exists = value is not None

    def to_dict(self):
        return dict(self.value)


class Reference:
    def __init__(self, store, path):
        self.store, self.path = store, path

    def get(self, **_):
        return Snapshot(self.store.get(self.path))

    def collection(self, path):
        return Reference(self.store, self.path + "/" + path)

    def document(self, path):
        return Reference(self.store, self.path + "/" + path)


class Transaction:
    def __init__(self, store):
        self.store = store

    def update(self, reference, fields):
        self.store[reference.path].update(fields)

    def create(self, reference, value):
        assert reference.path not in self.store
        self.store[reference.path] = value


@pytest.fixture
def book(monkeypatch):
    lock = Lock()

    def transactional(function):
        def run(transaction):
            with lock:
                return function(transaction)

        return run

    monkeypatch.setattr(firestore, "transactional", transactional)
    store = {"account": {"limitMicros": 50000, "usedMicros": 0}}
    ledger = FirestoreLedger.__new__(FirestoreLedger)
    ledger.document = Reference(store, "account")
    ledger.db = type("Database", (), {"transaction": lambda _: Transaction(store)})()
    return ledger, store


def test_multiple_clients_record_usage_without_a_dollar_cap(book):
    ledger, store = book

    def attempt(number):
        ledger.reserve(str(number), 10000, sku="routes")
        return True

    with ThreadPoolExecutor(max_workers=10) as executor:
        assert sum(executor.map(attempt, range(10))) == 10
    assert store["account"]["usedMicros"] == 100000
    assert store["account"]["limitMicros"] == 50000


def test_alternative_credits_share_search_quota_without_google_spending(book):
    ledger, store = book
    ledger.geoapify_route_start(101, 101)
    assert store["account"]["usedMicros"] == 0
    assert store["account"]["geoapifyRouteCredits"][0][1] == 101
    with pytest.raises(GatewayFailure):
        ledger.search_start("geoapify", credit_limit=101)


def test_alternative_dispatch_is_spaced_and_accounting_is_preserved(book):
    ledger, store = book
    ledger.geoapify_route_start(101, 3000)
    with pytest.raises(GatewayFailure) as failure:
        ledger.geoapify_route_start(101, 3000)
    assert failure.value.code == "provider_rate"
    assert len(store["account"]["geoapifyRouteCredits"]) == 1


@pytest.mark.parametrize("operation", ["route", "search"])
def test_disabled_geoapify_daily_caps_preserve_records_and_spacing(book, operation):
    from datetime import UTC, datetime

    ledger, store = book
    now = datetime.now(UTC).timestamp()
    # Beyond both old daily thresholds, but outside minute/spacing windows.
    routes = [[now - 3600 - i * 2, 105] for i in range(501)]
    searches = [now - 7200]
    store["account"].update(geoapifyRouteCredits=routes[:], searchStarts={"geoapify": searches[:]})
    if operation == "route":
        ledger.geoapify_route_start(105, 250, enforce_limits=False)
        assert store["account"]["geoapifyRouteCredits"][:-1] == routes
        assert store["account"]["geoapifyRouteCredits"][-1][1] == 105
    else:
        ledger.search_start("geoapify", credit_limit=250, enforce_limits=False)
        assert store["account"]["geoapifyRouteCredits"] == routes
        assert store["account"]["searchStarts"]["geoapify"][:-1] == searches
    assert store["account"]["usedMicros"] == 0
    before = repr(store)
    with pytest.raises(GatewayFailure) as failure:
        ledger.geoapify_route_start(105, 250, enforce_limits=False)
    assert failure.value.code == "provider_rate"
    assert repr(store) == before


def test_daily_opt_out_keeps_burst_limits_for_all_providers(book):
    from datetime import UTC, datetime

    ledger, store = book
    now = datetime.now(UTC).timestamp()
    store["account"]["geoapifyRouteCredits"] = [[now - 2, 101]] * 60
    with pytest.raises(GatewayFailure) as failure:
        ledger.search_start("geoapify", enforce_limits=False)
    assert failure.value.code == "provider_rate"
    store["account"]["searchStarts"] = {"locationiq": [now - 3600] * 500}
    # A capped legacy configuration still rejects the original daily threshold.
    with pytest.raises(GatewayFailure) as failure:
        ledger.search_start("locationiq")
    assert failure.value.code == "provider_rate"
    ledger.search_start("locationiq", enforce_limits=False)
    assert len(store['account']['searchStarts']['locationiq']) == 501
    with pytest.raises(GatewayFailure) as failure:
        ledger.search_start('locationiq', enforce_limits=False)
    assert failure.value.code == 'provider_rate'


@pytest.mark.parametrize("legacy_limit", [0, 2000000, None, "historical"])
def test_legacy_limit_neither_blocks_nor_resets_usage(book, legacy_limit):
    ledger, store = book
    store["account"] = {"usedMicros": 2100000, "limitMicros": legacy_limit}
    ledger.reserve("sdk", 35000, sku="places_35000", channel="sdk")
    assert store["account"]["usedMicros"] == 2135000
    assert store["account"]["limitMicros"] == legacy_limit
    ledger.release("sdk")
    assert store["account"]["usedMicros"] == 2100000


def test_large_preflight_is_read_only_and_needs_no_legacy_limit(book):
    ledger, store = book
    store["account"] = {"usedMicros": 2100000, "operatorNote": "retain"}
    ledger.reserve("preflight", 37500000, sku="routes_preflight", check_only=True)
    assert store == {"account": {"usedMicros": 2100000, "operatorNote": "retain"}}


@pytest.mark.parametrize("used", [None, -1, True, "0", 0.0])
def test_invalid_usage_still_blocks_without_resetting_the_ledger(book, used):
    ledger, store = book
    store["account"] = {"usedMicros": used, "limitMicros": 2000000}
    with pytest.raises(GatewayFailure) as failure:
        ledger.reserve("id", 10000, sku="routes")
    assert failure.value.code == "accounting_unavailable"
    assert store == {"account": {"usedMicros": used, "limitMicros": 2000000}}


def test_reservation_replay_and_release_are_idempotent(book):
    ledger, store = book
    ledger.reserve("id", 10000, sku="navigation", channel="sdk")
    ledger.reserve("id", 10000, sku="navigation", channel="sdk")
    assert store["account"]["usedMicros"] == 10000
    ledger.release("id")
    ledger.release("id")
    assert store["account"]["usedMicros"] == 0
    with pytest.raises(GatewayFailure):
        ledger.reserve("id", 10000, sku="navigation", channel="sdk")


def test_missing_ledger_is_never_created_and_checks_do_not_reserve(book):
    ledger, store = book
    ledger.reserve("check", 50000, sku="routes", check_only=True)
    assert store["account"]["usedMicros"] == 0
    assert "account/reservations/check" not in store
    store.clear()
    with pytest.raises(GatewayFailure):
        ledger.reserve("id", 10000, sku="routes")
    assert store == {}


def test_clients_cannot_refund_server_dispatched_routes(book):
    ledger, store = book
    ledger.reserve("server", 10000, sku="routes")
    with pytest.raises(GatewayFailure):
        ledger.release("server")
    assert store["account"]["usedMicros"] == 10000


def test_installed_client_contract_works_beyond_the_old_shared_limit(book):
    ledger, store = book
    store["account"] = {"limitMicros": 2000000, "usedMicros": 2100000}

    class Provider:
        def __init__(self):
            self.calls = []

        async def request(self, operation, payload):
            self.calls.append(operation)
            return {"routes": []}

    async def verify(token):
        if token != "valid-fixture":
            raise ValueError()
        return "fixture-app"

    provider = Provider()
    client = TestClient(
        create_gateway(
            Settings(project_id="fixture", app_ids=("fixture-app",)),
            provider=provider,
            verify=verify,
            ledger=ledger,
        )
    )
    auth = {"X-Firebase-AppCheck": "valid-fixture"}
    body = {
        "requestId": "ec583b14-eb2c-4c66-b821-bab174eb88d8",
        "sku": "routes_preflight",
        "units": 2500,
    }
    assert client.post("/v1/usage/check", json=body, headers=auth).status_code == 200
    assert store["account"]["usedMicros"] == 2100000
    assert len(store) == 1
    body.update(sku="places_35000", units=1)
    assert client.post("/v1/usage/reserve", json=body, headers=auth).status_code == 200
    assert store["account"]["usedMicros"] == 2135000
    point = {"location": {"latLng": {"latitude": 14.58, "longitude": 121.05}}}
    route = {
        "request": {"origin": point, "destination": point, "travelMode": "DRIVE"},
        "fieldMask": "routes.polyline.encodedPolyline",
    }
    assert client.post("/v1/routes/computeRoutes", json=route).status_code == 401
    assert provider.calls == []
    assert (
        client.post("/v1/routes/computeRoutes", json=route, headers=auth).status_code
        == 200
    )
    assert provider.calls == ["computeRoutes"]
    assert store["account"]["usedMicros"] == 2140000
    assert store["account"]["limitMicros"] == 2000000
