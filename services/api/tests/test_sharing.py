"""Sharing acceptance cases; all positions and credentials are disposable fixtures."""

from copy import deepcopy
import json
from uuid import uuid4

import pytest

from wayday_api.gateway.config import GatewayFailure
from wayday_api.gateway.sharing import FirestoreShareStore, MemoryShareStore, ShareService


OWNER = "o" * 43
VIEWER = "v" * 43
RECIPIENT = "r" * 43
INVITATION = "i" * 43


@pytest.fixture
def sharing():
    now = [1_800_000_000.0]
    service = ShareService(MemoryShareStore(), clock=lambda: now[0])
    body = {
        "operationId": str(uuid4()),
        "ownerToken": OWNER,
        "viewerToken": VIEWER,
        "snapshot": {
            "version": 1,
            "sourceId": "fixture-plan-source",
            "route": [[14.56, 121.08], [14.57, 121.09], [14.58, 121.10]],
            "stops": [
                {
                    "id": "groceries",
                    "title": "Buy groceries",
                    "place": "Fixture market",
                    "latitude": 14.57,
                    "longitude": 121.09,
                }
            ],
            "start": {"latitude": 14.56, "longitude": 121.08, "label": "Start"},
            "destination": {
                "latitude": 14.58,
                "longitude": 121.10,
                "label": "Destination",
            },
            "completed": [],
        },
    }
    created = service.create("fixture-app", body)
    return service, now, body, created["shareId"]


def mutate(service, share_id, token, kind, **fields):
    revision = service.read(share_id, OWNER)["revision"]
    return service.update(share_id, token, {"kind": kind, "revision": revision, **fields})


def fails(status, operation):
    with pytest.raises(GatewayFailure) as error:
        operation()
    assert error.value.status == status


def pair(service, share_id):
    mutate(service, share_id, OWNER, "invite", invitationToken=INVITATION)
    return service.pair(share_id, INVITATION, RECIPIENT)


def test_viewer_reads_exact_route_and_only_previewed_fields(sharing):
    service, now, body, share_id = sharing
    view = service.read(share_id, VIEWER)
    assert view["snapshot"] == body["snapshot"]
    assert view["expiresAt"] == now[0] + 7200
    assert all(token not in repr(view) for token in (OWNER, VIEWER, RECIPIENT))
    assert not view.get("ownerLocation")
    assert not view.get("recipientLocation")


def test_identical_create_retry_keeps_original_expiry(sharing):
    service, now, body, share_id = sharing
    expiry = service.read(share_id, VIEWER)["expiresAt"]
    now[0] += 30
    repeated = service.create("fixture-app", deepcopy(body))
    assert repeated["shareId"] == share_id
    assert repeated["expiresAt"] == expiry


def test_create_operation_cannot_replace_an_existing_share(sharing):
    service, _, body, share_id = sharing
    changed = deepcopy(body)
    changed["snapshot"]["stops"][0]["title"] = "Different task"
    fails(409, lambda: service.create("fixture-app", changed))
    assert service.read(share_id, VIEWER)["snapshot"] == body["snapshot"]


def test_viewer_cannot_mutate_progress_or_enable_location(sharing):
    service, _, _, share_id = sharing
    for kind, fields in (("progress", {"completed": ["groceries"]}), ("broadcast", {"enabled": True})):
        fails(403, lambda: mutate(service, share_id, VIEWER, kind, **fields))
    assert service.read(share_id, VIEWER)["snapshot"]["completed"] == []


def test_progress_accepts_only_known_errands_and_preserves_route(sharing):
    service, _, body, share_id = sharing
    fails(422, lambda: mutate(service, share_id, OWNER, "progress", completed=["unknown"]))
    mutate(service, share_id, OWNER, "progress", completed=["groceries"])
    view = service.read(share_id, VIEWER)
    assert view["snapshot"]["completed"] == ["groceries"]
    assert view["snapshot"]["route"] == body["snapshot"]["route"]


def test_out_of_order_progress_cannot_overwrite_confirmed_completion(sharing):
    service, _, _, share_id = sharing
    revision = service.read(share_id, OWNER)["revision"]
    mutate(service, share_id, OWNER, "progress", completed=["groceries"])
    fails(409, lambda: service.update(share_id, OWNER, {"kind": "progress", "revision": revision, "completed": []}))
    assert service.read(share_id, VIEWER)["snapshot"]["completed"] == ["groceries"]


def test_pairing_invitation_is_single_use_and_not_a_viewer_credential(sharing):
    service, _, _, share_id = sharing
    mutate(service, share_id, OWNER, "invite", invitationToken=INVITATION)
    fails(404, lambda: service.read(share_id, INVITATION))
    service.pair(share_id, INVITATION, RECIPIENT)
    fails(403, lambda: service.pair(share_id, INVITATION, "s" * 43))
    fails(403, lambda: mutate(service, share_id, RECIPIENT, "progress", completed=["groceries"]))


def test_pairing_does_not_start_broadcasting(sharing):
    service, now, _, share_id = sharing
    pair(service, share_id)
    fails(409, lambda: service.update(share_id, RECIPIENT, {
        "kind": "position", "broadcastRevision": 0, "latitude": 14.57,
        "longitude": 121.09, "accuracy": 25, "recordedAt": now[0],
    }))
    assert not service.read(share_id, OWNER).get("recipientLocation")


def test_recipient_location_is_owner_only_and_hidden_when_stale(sharing):
    service, now, _, share_id = sharing
    pair(service, share_id)
    enabled = mutate(service, share_id, RECIPIENT, "broadcast", enabled=True)
    service.update(share_id, RECIPIENT, {
        "kind": "position", "broadcastRevision": enabled["broadcastRevision"],
        "latitude": 14.57, "longitude": 121.09, "accuracy": 25,
        "recordedAt": now[0],
    })
    assert service.read(share_id, OWNER)["recipientLocation"]["latitude"] == 14.57
    assert not service.read(share_id, VIEWER).get("recipientLocation")
    now[0] += 46
    assert not service.read(share_id, OWNER).get("recipientLocation")


def test_stop_broadcast_clears_location_and_rejects_late_fix(sharing):
    service, now, _, share_id = sharing
    enabled = mutate(service, share_id, OWNER, "broadcast", enabled=True)
    position = {
        "kind": "position", "broadcastRevision": enabled["broadcastRevision"],
        "latitude": 14.57, "longitude": 121.09, "accuracy": 8,
        "recordedAt": now[0],
    }
    service.update(share_id, OWNER, position)
    assert service.read(share_id, VIEWER)["ownerLocation"]["latitude"] == 14.57
    mutate(service, share_id, OWNER, "broadcast", enabled=False)
    assert not service.read(share_id, VIEWER).get("ownerLocation")
    fails(409, lambda: service.update(share_id, OWNER, position))


def test_expiry_is_enforced_without_waiting_for_ttl_cleanup(sharing):
    service, now, _, share_id = sharing
    now[0] += 7200
    fails(404, lambda: service.read(share_id, VIEWER))
    fails(404, lambda: service.update(share_id, OWNER, {"kind": "progress", "revision": 0, "completed": []}))


def test_end_revokes_the_viewer_and_late_writes(sharing):
    service, _, _, share_id = sharing
    mutate(service, share_id, OWNER, "end")
    fails(404, lambda: service.read(share_id, VIEWER))
    fails(404, lambda: service.update(share_id, OWNER, {"kind": "progress", "revision": 0, "completed": []}))


@pytest.mark.parametrize("latitude,longitude", [(float("nan"), 121), (91, 121), (14, 181)])
def test_unusable_coordinates_cannot_create_a_share(sharing, latitude, longitude):
    service, _, body, _ = sharing
    changed = deepcopy(body)
    changed["operationId"] = str(uuid4())
    changed["snapshot"]["route"][0] = [latitude, longitude]
    fails(422, lambda: service.create("fixture-app", changed))


def test_firestore_serialization_preserves_exact_route_without_nested_arrays(sharing):
    service, _, _, share_id = sharing
    document = deepcopy(service.store.documents[share_id])
    document["snapshot"]["route"] = [
        [14.5600123456789, 121.0800987654321],
        [14.5600123456789, 121.0800987654321],
        [14.5634567890123, 121.0845678901234],
    ]
    original = deepcopy(document)

    encoded = FirestoreShareStore.encode_document(document)

    assert "snapshot" not in encoded
    assert isinstance(encoded["snapshotJson"], str)
    assert json.loads(encoded["snapshotJson"]) == original["snapshot"]
    assert encoded["deleteAfter"] == original["deleteAfter"]
    assert encoded["revision"] == original["revision"]
    assert FirestoreShareStore.decode_document(encoded) == original
    assert document == original


def test_firestore_serialization_preserves_ended_share_with_cleared_snapshot(sharing):
    service, _, _, share_id = sharing
    mutate(service, share_id, OWNER, "end")
    document = deepcopy(service.store.documents[share_id])

    encoded = FirestoreShareStore.encode_document(document)

    assert "snapshot" not in encoded
    decoded = FirestoreShareStore.decode_document(encoded)
    assert decoded == document
    assert decoded["snapshot"] is None
    assert decoded["ended"] is True


def test_firestore_decode_preserves_nonexistent_document():
    assert FirestoreShareStore.decode_document(None) is None
