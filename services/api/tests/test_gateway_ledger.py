from concurrent.futures import ThreadPoolExecutor
from threading import Lock
import pytest
from google.cloud import firestore
from wayday_api.gateway.ledger import FirestoreLedger
from wayday_api.gateway.config import GatewayFailure


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


def test_multiple_clients_share_one_finite_google_allocation(book):
    ledger, store = book

    def attempt(number):
        try:
            ledger.reserve(str(number), 10000, sku="routes")
            return True
        except GatewayFailure as error:
            assert error.code == "testing_budget"
            return False

    with ThreadPoolExecutor(max_workers=10) as executor:
        assert sum(executor.map(attempt, range(10))) == 5
    assert store["account"]["usedMicros"] == 50000


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


def test_missing_allocation_is_never_created_and_checks_do_not_reserve(book):
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
