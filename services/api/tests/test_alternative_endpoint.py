import pytest
from fastapi.testclient import TestClient
from wayday_api.gateway.app import create_gateway
from wayday_api.gateway.config import Settings
from test_alternative_routing import request, response


class Provider:
    calls = 0
    async def request(self, operation, payload):
        assert operation == "geoapify_navigation"
        self.calls += 1
        return response()


class Ledger:
    credits = 0
    enforcement = None
    def geoapify_route_start(self, credits, limit, *, enforce_limits=True):
        assert not enforce_limits or credits <= limit
        self.enforcement = enforce_limits
        self.credits += credits


def client(enabled, *, enforce_limits=True, limit=3000):
    async def verify(token):
        if token != "test": raise ValueError()
        return "fixture"
    provider, ledger = Provider(), Ledger()
    app = create_gateway(Settings(project_id="fixture", app_ids=("fixture",),
        alternative_navigation=enabled, geoapify_daily_credits=limit,
        geoapify_testing_limits=enforce_limits),
        provider=provider, ledger=ledger, verify=verify)
    return TestClient(app), provider, ledger


@pytest.mark.parametrize("enabled,token,status", [(False,"test",503), (True,"wrong",401), (True,"test",200)])
def test_attested_route_is_disabled_until_review(enabled, token, status):
    api, provider, ledger = client(enabled)
    result = api.post("/v1/navigation/geoapify/route", json=request(), headers={"X-Firebase-AppCheck":token})
    assert result.status_code == status
    assert provider.calls == (1 if status == 200 else 0)
    assert ledger.credits == (101 if status == 200 else 0)
    assert result.headers["cache-control"] == "no-store"


@pytest.mark.parametrize("token,status", [("test", 200), ("wrong", 401)])
def test_opted_in_uncapped_routing_needs_authentication_and_records_usage(token, status):
    api, provider, ledger = client(True, enforce_limits=False, limit=0)
    result = api.post("/v1/navigation/geoapify/route", json=request(), headers={"X-Firebase-AppCheck": token})
    assert result.status_code == status
    assert provider.calls == (1 if status == 200 else 0)
    assert ledger.credits == (101 if status == 200 else 0)
    assert ledger.enforcement == (False if status == 200 else None)


def test_test_limit_opt_out_is_explicit_and_default_remains_capped(monkeypatch):
    monkeypatch.delenv("WAYDAY_GEOAPIFY_TEST_LIMITS", raising=False)
    assert Settings.environment().geoapify_testing_limits is True
    monkeypatch.setenv("WAYDAY_GEOAPIFY_TEST_LIMITS", "false")
    assert Settings.environment().geoapify_testing_limits is False
    monkeypatch.setenv("WAYDAY_GEOAPIFY_TEST_LIMITS", "typo")
    assert Settings.environment().geoapify_testing_limits is True
