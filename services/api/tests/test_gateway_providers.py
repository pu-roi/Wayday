import asyncio
import httpx
import pytest
from wayday_api.gateway import providers
from wayday_api.gateway.config import Settings, GatewayFailure


def test_provider_failure_never_exposes_error_body_or_retries(monkeypatch):
    calls = []

    def response(request):
        calls.append(request)
        return httpx.Response(400, json={"error": "private provider diagnostic"})

    original = httpx.AsyncClient
    monkeypatch.setattr(
        providers.httpx,
        "AsyncClient",
        lambda **options: original(transport=httpx.MockTransport(response), **options),
    )
    with pytest.raises(GatewayFailure) as error:
        asyncio.run(
            providers.Providers(Settings(gemini_key="fixture-key")).request(
                "gemini", {}
            )
        )
    assert str(error.value) == "provider_http_400"
    assert len(calls) == 1
    assert calls[0].url.host == "generativelanguage.googleapis.com"


def test_provider_response_size_is_bounded(monkeypatch):
    original = httpx.AsyncClient
    monkeypatch.setattr(
        providers.httpx,
        "AsyncClient",
        lambda **options: original(
            transport=httpx.MockTransport(
                lambda _: httpx.Response(200, content=b"x" * 150001)
            ),
            **options,
        ),
    )
    with pytest.raises(GatewayFailure) as error:
        asyncio.run(
            providers.Providers(Settings(gemini_key="fixture-key")).request(
                "gemini", {}
            )
        )
    assert error.value.code == "invalid_response"
