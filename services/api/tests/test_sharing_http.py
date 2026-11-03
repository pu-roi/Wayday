"""Gateway sharing boundary tests with no external service or provider traffic."""

import json
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from wayday_api.gateway.app import create_gateway
from wayday_api.gateway.config import Settings
from wayday_api.gateway.sharing import MemoryShareStore


OWNER = "o" * 43
VIEWER = "v" * 43
INVITATION = "i" * 43
RECIPIENT = "r" * 43
ATTESTATION = {"X-Firebase-AppCheck": "fixture-token"}


class NoProvider:
    async def request(self, operation, payload):
        raise AssertionError("Sharing must never dispatch a paid provider request")


class ObservedStore(MemoryShareStore):
    def __init__(self):
        super().__init__()
        self.keys = []

    def transact(self, key, change):
        self.keys.append(key)
        return super().transact(key, change)


def headers(token, *, attest=False):
    return {"Authorization": "Bearer " + token, **(ATTESTATION if attest else {})}


def create_body():
    return {
        "operationId": str(uuid4()),
        "ownerToken": OWNER,
        "viewerToken": VIEWER,
        "snapshot": {
            "version": 1,
            "sourceId": "fixture-source",
            "route": [[14.561234, 121.081234], [14.571234, 121.091234]],
            "stops": [{
                "id": "groceries", "title": "Private fixture errand",
                "place": "Fixture market", "latitude": 14.571234,
                "longitude": 121.091234,
            }],
            "start": {"latitude": 14.561234, "longitude": 121.081234, "label": "Start"},
            "destination": {"latitude": 14.571234, "longitude": 121.091234, "label": "Destination"},
            "completed": [],
        },
    }


@pytest.fixture
def setup():
    store = ObservedStore()

    async def verify(token):
        if token != "fixture-token":
            raise ValueError("private diagnostic must never escape")
        return "fixture-app"

    def client(**overrides):
        settings = Settings(
            project_id="fixture-project", app_ids=("fixture-app",),
            sharing_enabled=True, share_origin="https://share.example.test",
            **overrides,
        )
        return TestClient(create_gateway(
            settings, provider=NoProvider(), verify=verify, share_store=store,
        ))

    return client, store


def create(client):
    body = create_body()
    response = client.post("/v1/shares", json=body, headers=ATTESTATION)
    assert response.status_code == 201, response.text
    assert response.json()["shareId"] == body["operationId"]
    return body, response.json()["shareId"]


@pytest.mark.parametrize("attestation", [{}, {"X-Firebase-AppCheck": "invalid"}])
def test_create_needs_native_attestation_before_storage(setup, attestation):
    factory, store = setup
    response = factory().post("/v1/shares", json=create_body(), headers=attestation)
    assert response.status_code == 401
    assert response.headers["Cache-Control"] == "no-store"
    assert not store.keys
    assert "private diagnostic" not in response.text


def test_disabled_sharing_returns_safe_unavailable_without_store():
    store = ObservedStore()
    client = TestClient(create_gateway(
        Settings(project_id="fixture-project", app_ids=("fixture-app",)),
        provider=NoProvider(), share_store=store,
    ))
    response = client.get("/v1/shares/" + str(uuid4()), headers=headers(VIEWER))
    assert response.status_code == 503
    assert response.headers["Cache-Control"] == "no-store"
    assert not store.keys


def test_public_viewer_read_uses_its_capability_without_appcheck(setup):
    factory, _ = setup
    client = factory()
    body, share_id = create(client)
    response = client.get(f"/v1/shares/{share_id}", headers=headers(VIEWER))
    assert response.status_code == 200
    assert response.json()["snapshot"] == body["snapshot"]
    assert response.headers["Cache-Control"] == "no-store"
    assert OWNER not in response.text and VIEWER not in response.text


def test_missing_read_credential_is_rejected_before_store_access(setup):
    factory, store = setup
    response = factory().get("/v1/shares/" + str(uuid4()))
    assert response.status_code == 404
    assert not store.keys


def test_unknown_share_with_valid_credential_is_safe_not_found(setup):
    factory, _ = setup
    response = factory().get("/v1/shares/" + str(uuid4()), headers=headers(VIEWER))
    assert response.status_code == 404
    assert VIEWER not in response.text
    assert response.headers["Cache-Control"] == "no-store"


@pytest.mark.parametrize("key", ["not-a-uuid", "accounting%2Fpublic-preview", "..%2Fprivate"])
def test_invalid_document_identifier_never_reaches_storage(setup, key):
    factory, store = setup
    response = factory().get(f"/v1/shares/{key}", headers=headers(VIEWER))
    assert response.status_code in (404, 422)
    assert not store.keys


def test_owner_write_still_requires_appcheck(setup):
    factory, store = setup
    client = factory()
    _, share_id = create(client)
    store.keys.clear()
    response = client.post(f"/v1/shares/{share_id}/events", headers=headers(OWNER), json={
        "kind": "progress", "revision": 0, "completed": ["groceries"],
    })
    assert response.status_code == 401
    assert not store.keys


def test_forwarded_viewer_token_cannot_write_even_with_valid_appcheck(setup):
    factory, _ = setup
    client = factory()
    _, share_id = create(client)
    response = client.post(f"/v1/shares/{share_id}/events", headers=headers(VIEWER, attest=True), json={
        "kind": "progress", "revision": 0, "completed": ["groceries"],
    })
    assert response.status_code == 403
    assert OWNER not in response.text and VIEWER not in response.text


def test_owner_progress_is_visible_only_after_valid_event(setup):
    factory, _ = setup
    client = factory()
    _, share_id = create(client)
    revision = client.get(f"/v1/shares/{share_id}", headers=headers(OWNER)).json()["revision"]
    response = client.post(f"/v1/shares/{share_id}/events", headers=headers(OWNER, attest=True), json={
        "kind": "progress", "revision": revision, "completed": ["groceries"],
    })
    assert response.status_code == 200
    assert client.get(f"/v1/shares/{share_id}", headers=headers(VIEWER)).json()["snapshot"]["completed"] == ["groceries"]


def test_invalid_payload_error_does_not_echo_trip_or_credentials(setup):
    factory, _ = setup
    body = create_body()
    body["snapshot"]["privateNotes"] = "Do not expose private diagnostic or errand data"
    response = factory().post("/v1/shares", json=body, headers=ATTESTATION)
    assert response.status_code == 422
    for private in (OWNER, VIEWER, "14.561234", "121.081234", "Private fixture errand", "privateNotes"):
        assert private not in response.text


def test_pair_endpoint_requires_attestation_and_consumes_invitation(setup):
    factory, _ = setup
    client = factory()
    _, share_id = create(client)
    revision = client.get(f"/v1/shares/{share_id}", headers=headers(OWNER)).json()["revision"]
    invitation = client.post(f"/v1/shares/{share_id}/events", headers=headers(OWNER, attest=True), json={
        "kind": "invite", "revision": revision, "invitationToken": INVITATION,
    })
    assert invitation.status_code == 200
    path = f"/v1/shares/{share_id}/pair"
    assert client.post(path, headers=headers(INVITATION), json={"recipientToken": RECIPIENT}).status_code == 401
    assert client.post(path, headers=headers(INVITATION, attest=True), json={"recipientToken": RECIPIENT}).status_code == 200
    assert client.post(path, headers=headers(INVITATION, attest=True), json={"recipientToken": "s" * 43}).status_code == 403


def test_viewer_shell_is_generic_and_contains_no_trip_payload(setup):
    factory, _ = setup
    client = factory()
    _, share_id = create(client)
    response = client.get("/share/")
    assert response.status_code == 200
    assert "text/html" in response.headers["Content-Type"]
    for private in (OWNER, VIEWER, share_id, "14.561234", "Private fixture errand"):
        assert private not in response.text


def test_association_file_is_empty_until_identity_is_configured(setup):
    factory, _ = setup
    response = factory().get("/.well-known/assetlinks.json")
    assert response.status_code == 200
    assert response.json() == []


def test_association_file_pins_exact_package_and_certificate(setup):
    factory, _ = setup
    fingerprint = ":".join(["AB"] * 32)
    client = factory(share_package="dev.wayday.wayday", share_certificate=fingerprint)
    statements = client.get("/.well-known/assetlinks.json").json()
    assert len(statements) == 1
    assert statements[0]["target"]["package_name"] == "dev.wayday.wayday"
    assert statements[0]["target"]["sha256_cert_fingerprints"] == [fingerprint]


@pytest.mark.parametrize("asset", ["viewer.js", "viewer.css", "assets/Figtree.ttf", "assets/wayday-logo.png"])
def test_viewer_assets_are_served_without_access_credentials(setup, asset):
    factory, _ = setup
    response = factory().get("/share/" + asset)
    assert response.status_code == 200
    assert response.content


@pytest.mark.parametrize("suffix", ["", "/events", "/pair"])
def test_malformed_json_is_safe_invalid_request_before_storage(setup, suffix):
    factory, store = setup
    path = "/v1/shares" if not suffix else "/v1/shares/" + str(uuid4()) + suffix
    response = factory().post(
        path, content='{"privateNotes": "must not echo",',
        headers={**headers(OWNER, attest=True), "Content-Type": "application/json"},
    )
    assert response.status_code == 422
    assert response.headers["Cache-Control"] == "no-store"
    assert "privateNotes" not in response.text
    assert "must not echo" not in response.text
    assert not store.keys


@pytest.mark.parametrize("invalid_number", [float("nan"), float("inf"), -float("inf")])
def test_nonfinite_json_coordinate_is_invalid_without_trip_data_echo(setup, invalid_number):
    factory, store = setup
    body = create_body()
    body["snapshot"]["route"][0][0] = invalid_number
    response = factory().post(
        "/v1/shares", content=json.dumps(body, allow_nan=True),
        headers={**ATTESTATION, "Content-Type": "application/json"},
    )
    assert response.status_code == 422
    assert response.headers["Cache-Control"] == "no-store"
    for private in (OWNER, VIEWER, "Private fixture errand", "121.081234"):
        assert private not in response.text
    assert not store.keys
