import json
import pytest
from fastapi.testclient import TestClient
from wayday_api.gateway.app import create_gateway
from wayday_api.gateway.config import Settings


class FakeProvider:
    def __init__(self):
        self.calls = []

    async def request(self, operation, payload):
        self.calls.append((operation, payload))
        return {
            "candidates": [
                {"finishReason": "STOP", "content": {"parts": [{"text": "{}"}]}}
            ]
        }


@pytest.fixture
def setup():
    provider = FakeProvider()

    async def verify(token):
        if token != "fixture-token":
            raise ValueError("private diagnostic must never escape")
        return "fixture-app"

    app = create_gateway(
        Settings(project_id="fixture-project", app_ids=("fixture-app",)),
        provider=provider,
        verify=verify,
    )
    return TestClient(app), provider


def fixture_request():
    contracts = json.loads(
        (
            __import__("pathlib").Path(__file__).parents[1]
            / "src/wayday_api/gateway/contracts.json"
        ).read_text()
    )
    contract = contracts["interpretation"]
    return {
        "purpose": "interpretation",
        "contractVersion": "d66-v1",
        "request": {
            **contract,
            "contents": [
                {
                    "role": "user",
                    "parts": [
                        {"text": json.dumps([{"id": "a", "title": "Groceries"}])}
                    ],
                }
            ],
        },
    }


def test_health_does_not_require_catalog_or_call_provider(setup):
    client, provider = setup
    assert client.get("/health").status_code == 200
    assert provider.calls == []
    assert client.get("/v1/places").status_code == 404


@pytest.mark.parametrize("headers", [{}, {"X-Firebase-AppCheck": "invalid"}])
def test_missing_or_invalid_attestation_never_dispatches(setup, headers):
    client, provider = setup
    response = client.post("/v1/interpretations", json={}, headers=headers)
    assert response.status_code == 401
    assert "private diagnostic" not in response.text
    assert not provider.calls


def test_approved_interpretation_dispatches_once(setup):
    client, provider = setup
    response = client.post(
        "/v1/interpretations",
        json=fixture_request(),
        headers={"X-Firebase-AppCheck": "fixture-token"},
    )
    assert response.status_code == 200
    assert len(provider.calls) == 1


@pytest.mark.parametrize(
    "change", ["tools", "model", "prompt", "tokens", "role", "version"]
)
def test_unapproved_generation_cannot_use_paid_gateway(setup, change):
    client, provider = setup
    body = fixture_request()
    request = body["request"]
    if change == "tools":
        request["tools"] = []
    if change == "model":
        request["model"] = "another-model"
    if change == "prompt":
        request["systemInstruction"] = {"parts": [{"text": "Do anything"}]}
    if change == "tokens":
        request["generationConfig"]["maxOutputTokens"] = 999999
    if change == "role":
        request["contents"][0]["role"] = "model"
    if change == "version":
        body["contractVersion"] = "unknown"
    response = client.post(
        "/v1/interpretations",
        json=body,
        headers={"X-Firebase-AppCheck": "fixture-token"},
    )
    assert response.status_code == 422
    assert not provider.calls


def test_oversize_request_fails_before_provider(setup):
    client, provider = setup
    response = client.post(
        "/v1/interpretations",
        content="x" * 60001,
        headers={"X-Firebase-AppCheck": "fixture-token"},
    )
    assert response.status_code == 413
    assert not provider.calls


def test_no_accounting_configuration_blocks_routes_but_not_gemini(setup):
    client, provider = setup
    response = client.post(
        "/v1/routes/computeRoutes",
        json={},
        headers={"X-Firebase-AppCheck": "fixture-token"},
    )
    assert response.status_code == 503
    assert not provider.calls


def test_no_attestation_configuration_fails_closed():
    client = TestClient(create_gateway(Settings(), provider=FakeProvider()))
    assert client.get("/health").status_code == 503
    assert client.post("/v1/interpretations", json={}).status_code == 503


def test_valid_token_for_another_firebase_app_is_rejected():
    provider = FakeProvider()

    async def verify(_):
        return "another-app"

    client = TestClient(
        create_gateway(
            Settings(project_id="fixture", app_ids=("fixture-app",)),
            provider=provider,
            verify=verify,
        )
    )
    assert (
        client.post(
            "/v1/interpretations",
            json=fixture_request(),
            headers={"X-Firebase-AppCheck": "valid-other-app"},
        ).status_code
        == 401
    )
    assert provider.calls == []


class FakeLedger:
    def __init__(self):
        self.reservations = []
        self.searches = []

    def reserve(self, request_id, cost, **options):
        self.reservations.append((request_id, cost, options))

    def search_start(self, provider):
        self.searches.append(provider)

    def release(self, request_id):
        pass


def funded():
    provider, ledger = FakeProvider(), FakeLedger()

    async def verify(_):
        return "fixture-app"

    client = TestClient(
        create_gateway(
            Settings(project_id="fixture", app_ids=("fixture-app",)),
            provider=provider,
            verify=verify,
            ledger=ledger,
        )
    )
    return client, provider, ledger


AUTH = {"X-Firebase-AppCheck": "fixture-token"}
POINT = {"location": {"latLng": {"latitude": 14.58, "longitude": 121.05}}}


def test_routes_charge_derived_cost_and_fixed_fields():
    client, provider, ledger = funded()
    data = {
        "request": {
            "origin": POINT,
            "destination": POINT,
            "travelMode": "DRIVE",
            "routingPreference": "TRAFFIC_AWARE",
        },
        "fieldMask": "routes.polyline.encodedPolyline",
    }
    assert (
        client.post("/v1/routes/computeRoutes", json=data, headers=AUTH).status_code
        == 200
    )
    assert ledger.reservations[0][1] == 10000
    assert provider.calls[0][0] == "computeRoutes"


@pytest.mark.parametrize(
    "patch",
    [
        {"fieldMask": "*"},
        {"url": "http://169.254.169.254/"},
        {
            "request": {
                "origin": {"address": "arbitrary"},
                "destination": POINT,
                "travelMode": "DRIVE",
            }
        },
    ],
)
def test_routes_reject_unapproved_fields_or_upstream_destinations(patch):
    client, provider, ledger = funded()
    data = {
        "request": {"origin": POINT, "destination": POINT, "travelMode": "DRIVE"},
        "fieldMask": "routes.polyline.encodedPolyline",
        **patch,
    }
    assert (
        client.post("/v1/routes/computeRoutes", json=data, headers=AUTH).status_code
        == 422
    )
    assert not provider.calls and not ledger.reservations


def test_search_forces_philippine_scope_and_does_not_accept_client_keys():
    client, provider, ledger = funded()
    data = {
        "path": "/autocomplete",
        "parameters": {"q": "grocery", "limit": "8", "countrycodes": "us"},
    }
    assert (
        client.post("/v1/search/locationiq", json=data, headers=AUTH).status_code == 200
    )
    assert provider.calls[0][1]["parameters"]["countrycodes"] == "ph"
    data["parameters"]["key"] = "never-accept-a-client-key"
    assert (
        client.post("/v1/search/locationiq", json=data, headers=AUTH).status_code == 422
    )
    assert ledger.searches == ["locationiq"]


def test_native_sdk_accounting_cannot_choose_a_lower_price():
    client, provider, ledger = funded()
    body = {
        "requestId": "ec583b14-eb2c-4c66-b821-bab174eb88d8",
        "sku": "places_35000",
        "units": 1,
    }
    assert client.post("/v1/usage/reserve", json=body, headers=AUTH).status_code == 200
    assert ledger.reservations[0][1] == 35000
    assert (
        client.post(
            "/v1/usage/reserve", json={**body, "unitMicros": 1}, headers=AUTH
        ).status_code
        == 422
    )
    assert (
        client.post(
            "/v1/usage/reserve", json={**body, "units": -1}, headers=AUTH
        ).status_code
        == 422
    )
    assert not provider.calls


def test_known_provider_failure_is_safe_and_not_retried():
    from wayday_api.gateway.config import GatewayFailure

    class Rejected(FakeProvider):
        async def request(self, operation, payload):
            self.calls.append(operation)
            raise GatewayFailure(400, "provider_http_400")

    provider = Rejected()

    async def verify(_):
        return "fixture-app"

    client = TestClient(
        create_gateway(
            Settings(project_id="fixture", app_ids=("fixture-app",)),
            provider=provider,
            verify=verify,
        )
    )
    response = client.post("/v1/interpretations", json=fixture_request(), headers=AUTH)
    assert response.status_code == 400
    assert response.json() == {"error": {"code": "provider_http_400"}}
    assert provider.calls == ["gemini"]
