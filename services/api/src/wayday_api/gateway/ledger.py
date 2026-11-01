"""Shared nonpersonal reservations. Missing allocation is never auto-provisioned."""

from datetime import UTC, datetime

from google.api_core.exceptions import GoogleAPIError, RetryError
from google.auth.exceptions import GoogleAuthError

from .config import GatewayFailure


class FirestoreLedger:
    def __init__(self, project, document):
        from google.cloud import firestore

        self.db = firestore.Client(project=project)
        self.document = self.db.document(document)

    def reserve(
        self, reservation, cost, *, sku, units=1, check_only=False, channel="server"
    ):
        from google.cloud import firestore

        reference = self.document.collection("reservations").document(reservation)

        @firestore.transactional
        def update(transaction):
            account = self.document.get(transaction=transaction)
            previous = reference.get(transaction=transaction)
            if not account.exists:
                raise GatewayFailure(503, "accounting_unavailable")
            data = account.to_dict()
            limit, used = data.get("limitMicros"), data.get("usedMicros")
            if (
                type(limit) is not int
                or type(used) is not int
                or not 0 <= used <= limit
            ):
                raise GatewayFailure(503, "accounting_unavailable")
            if previous.exists:
                existing = previous.to_dict()
                if (
                    existing.get("costMicros") != cost
                    or existing.get("sku") != sku
                    or existing.get("units") != units
                    or existing.get("released")
                ):
                    raise GatewayFailure(409, "reservation_conflict")
                return
            if used + cost > limit:
                raise GatewayFailure(429, "testing_budget")
            if check_only:
                return
            transaction.update(self.document, {"usedMicros": used + cost})
            transaction.create(
                reference,
                {
                    "costMicros": cost,
                    "sku": sku,
                    "units": units,
                    "channel": channel,
                    "released": False,
                    "at": datetime.now(UTC),
                },
            )

        try:
            update(self.db.transaction())
        except GatewayFailure:
            raise
        except (
            GoogleAPIError,
            GoogleAuthError,
            RetryError,
            ValueError,
            TypeError,
            OSError,
        ):
            raise GatewayFailure(503, "accounting_unavailable") from None

    def release(self, reservation):
        from google.cloud import firestore

        reference = self.document.collection("reservations").document(reservation)

        @firestore.transactional
        def update(transaction):
            account = self.document.get(transaction=transaction)
            previous = reference.get(transaction=transaction)
            if not account.exists or not previous.exists:
                raise GatewayFailure(409, "reservation_conflict")
            record = previous.to_dict()
            if record.get("channel") != "sdk":
                raise GatewayFailure(403, "access")
            if record.get("released"):
                return
            used, cost = account.to_dict().get("usedMicros"), record.get("costMicros")
            if type(used) is not int or type(cost) is not int or used < cost:
                raise GatewayFailure(503, "accounting_unavailable")
            transaction.update(self.document, {"usedMicros": used - cost})
            transaction.update(reference, {"released": True})

        try:
            update(self.db.transaction())
        except GatewayFailure:
            raise
        except (
            GoogleAPIError,
            GoogleAuthError,
            RetryError,
            ValueError,
            TypeError,
            OSError,
        ):
            raise GatewayFailure(503, "accounting_unavailable") from None

    def search_start(self, provider):
        from google.cloud import firestore

        now = datetime.now(UTC).timestamp()

        @firestore.transactional
        def update(transaction):
            account = self.document.get(transaction=transaction)
            if not account.exists:
                raise GatewayFailure(503, "accounting_unavailable")
            records = dict(account.to_dict().get("searchStarts", {}))
            history = records.get(provider, [])
            if not isinstance(history, list) or any(
                type(x) not in (int, float) for x in history
            ):
                raise GatewayFailure(503, "accounting_unavailable")
            history = [x for x in history if now - x < 86400]
            minute = 50 if provider == "locationiq" else 60
            if (
                len(history) >= 500
                or sum(now - x < 60 for x in history) >= minute
                or (history and now - history[-1] < 1.1)
            ):
                raise GatewayFailure(429, "provider_rate")
            records[provider] = history + [now]
            transaction.update(self.document, {"searchStarts": records})

        try:
            update(self.db.transaction())
        except GatewayFailure:
            raise
        except (
            GoogleAPIError,
            GoogleAuthError,
            RetryError,
            ValueError,
            TypeError,
            OSError,
        ):
            raise GatewayFailure(503, "accounting_unavailable") from None
