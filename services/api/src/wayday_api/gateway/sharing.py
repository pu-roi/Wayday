"""Temporary capability-based shares. Never store raw capability credentials."""

from copy import deepcopy
from hashlib import sha256
import hmac
import json
import math
import re
from threading import RLock
import time
from uuid import UUID

from .config import GatewayFailure


def require(condition, status=422, code="invalid_request"):
    if not condition:
        raise GatewayFailure(status, code)


def digest(value):
    require(isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9_-]{43}", value))
    return sha256(value.encode()).hexdigest()


def coordinate(lat, lng):
    return (type(lat) in (int, float) and type(lng) in (int, float)
            and math.isfinite(lat) and math.isfinite(lng)
            and -90 <= lat <= 90 and -180 <= lng <= 180)


def snapshot(value):
    require(isinstance(value, dict) and set(value) == {
        "version", "sourceId", "route", "stops", "start", "destination", "completed"})
    require(value["version"] == 1 and isinstance(value["sourceId"], str)
            and 1 <= len(value["sourceId"]) <= 128)
    route, stops, completed = value["route"], value["stops"], value["completed"]
    require(isinstance(route, list) and 2 <= len(route) <= 1600)
    require(all(isinstance(p, list) and len(p) == 2 and coordinate(*p) for p in route))
    require(isinstance(stops, list) and 1 <= len(stops) <= 12)
    for stop in stops:
        require(isinstance(stop, dict) and set(stop) == {
            "id", "title", "place", "latitude", "longitude"})
        require(all(isinstance(stop[k], str) and 1 <= len(stop[k]) <= limit
                    for k, limit in (("id", 128), ("title", 240), ("place", 240))))
        require(coordinate(stop["latitude"], stop["longitude"]))
    ids = [s["id"] for s in stops]
    require(len(set(ids)) == len(ids))
    require(isinstance(completed, list) and all(isinstance(i, str) for i in completed)
            and len(set(completed)) == len(completed) and set(completed) <= set(ids))
    for name, label in (("start", "Start"), ("destination", "Destination")):
        point = value[name]
        require(isinstance(point, dict) and set(point) == {"latitude", "longitude", "label"})
        require(point["label"] == label and coordinate(point["latitude"], point["longitude"]))
    require(len(json.dumps(value).encode()) <= 55000)
    return deepcopy(value)


class MemoryShareStore:
    """Test/local store. Production always uses the transactional Firestore store."""
    def __init__(self):
        self.documents = {}
        self.lock = RLock()

    def transact(self, key, change):
        with self.lock:
            value, result = change(deepcopy(self.documents.get(key)))
            self.documents[key] = deepcopy(value)
            return result


class FirestoreShareStore:
    def __init__(self, project, collection):
        from google.cloud import firestore
        self.db = firestore.Client(project=project)
        self.collection = self.db.collection(collection)

    @staticmethod
    def encode_document(value):
        result = deepcopy(value)
        result["snapshotJson"] = json.dumps(result.pop("snapshot"), separators=(",", ":"))
        return result

    @staticmethod
    def decode_document(value):
        if value is None:
            return None
        result = deepcopy(value)
        result["snapshot"] = json.loads(result.pop("snapshotJson"))
        return result

    def transact(self, key, change):
        from google.cloud import firestore
        reference = self.collection.document(key)

        @firestore.transactional
        def apply(transaction):
            document = reference.get(transaction=transaction)
            original = self.decode_document(document.to_dict() if document.exists else None)
            value, result = change(deepcopy(original))
            if value != original:
                transaction.set(reference, self.encode_document(value))
            return result

        return apply(self.db.transaction())


class ShareService:
    def __init__(self, store, clock=time.time):
        self.store, self.clock = store, clock

    def create(self, app_id, body):
        require(isinstance(body, dict) and set(body) == {
            "operationId", "ownerToken", "viewerToken", "snapshot"})
        key = body["operationId"]
        try:
            require(isinstance(key, str) and str(UUID(key)) == key)
        except (ValueError, AttributeError):
            raise GatewayFailure(422, "invalid_request") from None
        owner, viewer = digest(body["ownerToken"]), digest(body["viewerToken"])
        require(owner != viewer)
        data = snapshot(body["snapshot"])
        fingerprint = sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()
        now = self.clock()

        def create(old):
            if old is not None:
                require(old["appId"] == app_id and old["owner"] == owner
                        and old["viewer"] == viewer and old["fingerprint"] == fingerprint,
                        409, "share_conflict")
                require(not old["ended"] and old["expiresAt"] > now, 404, "share_unavailable")
                return old, {"shareId": key, "expiresAt": old["expiresAt"]}
            from datetime import datetime, timezone
            expiry = int(now) + 7200
            value = {"appId": app_id, "owner": owner, "viewer": viewer,
                     "fingerprint": fingerprint, "snapshot": data,
                     "expiresAt": expiry, "deleteAfter": datetime.fromtimestamp(expiry, timezone.utc),
                     "revision": 0, "ended": False, "recipient": None, "invitation": None,
                     "ownerBroadcast": {"revision": 0, "enabled": False, "position": None},
                     "recipientBroadcast": {"revision": 0, "enabled": False, "position": None}}
            return value, {"shareId": key, "expiresAt": expiry}

        return self.store.transact(key, create)

    def _role(self, value, token):
        require(value is not None and not value["ended"]
                and value["expiresAt"] > self.clock(), 404, "share_unavailable")
        try:
            hashed = digest(token)
        except GatewayFailure:
            raise GatewayFailure(404, "share_unavailable") from None
        for role in ("owner", "viewer", "recipient"):
            if value[role] and hmac.compare_digest(hashed, value[role]):
                return role
        raise GatewayFailure(404, "share_unavailable")

    def read(self, key, token):
        def read(value):
            role = self._role(value, token)
            now = self.clock()

            def fresh(name):
                broadcast = value[name + "Broadcast"]
                position = broadcast["position"]
                return deepcopy(position) if (broadcast["enabled"] and position
                    and 0 <= now - position["recordedAt"] <= 45
                    and 0 <= now - position["receivedAt"] <= 45) else None

            result = {"snapshot": deepcopy(value["snapshot"]), "expiresAt": value["expiresAt"],
                      "revision": value["revision"], "ownerLocation": fresh("owner"),
                      "ownerSharing": value["ownerBroadcast"]["enabled"]}
            if role == "owner":
                result["recipientLocation"] = fresh("recipient")
                result["paired"] = value["recipient"] is not None
            if role in ("owner", "recipient"):
                own = value[role + "Broadcast"]
                result.update(broadcastRevision=own["revision"], broadcasting=own["enabled"])
            return value, result
        return self.store.transact(key, read)

    def pair(self, key, invitation_token, recipient_token):
        invitation, recipient = digest(invitation_token), digest(recipient_token)
        now = self.clock()

        def pair(value):
            require(value is not None and not value["ended"] and value["expiresAt"] > now,
                    404, "share_unavailable")
            invite = value["invitation"]
            require(invite is not None and invite["expiresAt"] > now
                    and hmac.compare_digest(invitation, invite["digest"])
                    and value["recipient"] is None, 403, "pairing_unavailable")
            require(recipient not in (value["owner"], value["viewer"], invitation))
            value["recipient"] = recipient
            value["invitation"] = None
            value["revision"] += 1
            return value, {"revision": value["revision"], "broadcastRevision": 0}
        return self.store.transact(key, pair)

    def update(self, key, token, body):
        require(isinstance(body, dict) and isinstance(body.get("kind"), str))
        now = self.clock()

        def update(value):
            role = self._role(value, token)
            kind = body["kind"]
            require(role != "viewer", 403, "share_access")
            if kind == "position":
                require(set(body) == {"kind", "broadcastRevision", "latitude", "longitude", "accuracy", "recordedAt"})
                broadcast = value[role + "Broadcast"]
                require(broadcast["enabled"] and type(body["broadcastRevision"]) is int
                        and body["broadcastRevision"] == broadcast["revision"], 409, "broadcast_changed")
                require(coordinate(body["latitude"], body["longitude"]))
                require(type(body["accuracy"]) in (int, float) and math.isfinite(body["accuracy"])
                        and 0 <= body["accuracy"] <= 50000)
                require(type(body["recordedAt"]) in (int, float)
                        and 0 <= now - body["recordedAt"] <= 45)
                previous = broadcast["position"]
                require(previous is None or (body["recordedAt"] > previous["recordedAt"]
                        and now - previous["receivedAt"] >= 15), 409, "position_spacing")
                broadcast["position"] = {k: body[k] for k in ("latitude", "longitude", "accuracy", "recordedAt")}
                broadcast["position"]["receivedAt"] = now
                return value, {"broadcastRevision": broadcast["revision"]}
            require(type(body.get("revision")) is int and body["revision"] == value["revision"],
                    409, "share_changed")
            if kind == "broadcast":
                require(set(body) == {"kind", "revision", "enabled"} and type(body["enabled"]) is bool)
                broadcast = value[role + "Broadcast"]
                broadcast.update(enabled=body["enabled"], revision=broadcast["revision"] + 1, position=None)
            else:
                require(role == "owner", 403, "share_access")
                if kind == "progress":
                    require(set(body) == {"kind", "revision", "completed"})
                    completed = body["completed"]
                    require(isinstance(completed, list) and all(isinstance(i, str) for i in completed))
                    ids = {s["id"] for s in value["snapshot"]["stops"]}
                    require(len(set(completed)) == len(completed) and set(completed) <= ids
                            and set(value["snapshot"]["completed"]) <= set(completed))
                    value["snapshot"]["completed"] = completed
                elif kind == "invite":
                    require(set(body) == {"kind", "revision", "invitationToken"})
                    require(value["recipient"] is None, 409, "recipient_exists")
                    invitation = digest(body["invitationToken"])
                    require(invitation not in (value["owner"], value["viewer"]))
                    value["invitation"] = {"digest": invitation, "expiresAt": min(now + 300, value["expiresAt"])}
                elif kind == "removeRecipient":
                    require(set(body) == {"kind", "revision"})
                    value["recipient"] = None
                    value["invitation"] = None
                    previous = value["recipientBroadcast"]["revision"]
                    value["recipientBroadcast"] = {"revision": previous + 1, "enabled": False, "position": None}
                elif kind == "end":
                    require(set(body) == {"kind", "revision"})
                    value["ended"] = True
                    value["snapshot"] = None
                    for name in ("ownerBroadcast", "recipientBroadcast"):
                        value[name].update(enabled=False, position=None, revision=value[name]["revision"] + 1)
                    value["invitation"] = None
                else:
                    raise GatewayFailure(422, "invalid_request")
            value["revision"] += 1
            result = {"revision": value["revision"]}
            if kind == "broadcast":
                result["broadcastRevision"] = value[role + "Broadcast"]["revision"]
            return value, result
        return self.store.transact(key, update)
