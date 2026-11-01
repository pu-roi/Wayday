import asyncio
import json

import httpx

from .config import GatewayFailure


class Providers:
    def __init__(self, settings):
        self.settings = settings

    @property
    def ready(self):
        return all(
            (
                self.settings.gemini_key,
                self.settings.routes_key,
                self.settings.geoapify_key,
                self.settings.locationiq_key,
            )
        )

    async def request(self, operation, payload):
        headers = {"Content-Type": "application/json"}
        params = None
        body = None
        method = "POST"
        maximum = 1500000
        if operation == "gemini":
            key = self.settings.gemini_key
            url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
            headers["x-goog-api-key"] = key
            body, maximum = payload, 150000
        elif operation in ("computeRoutes", "computeRouteMatrix"):
            key = self.settings.routes_key
            path = (
                "directions/v2:computeRoutes"
                if operation == "computeRoutes"
                else "distanceMatrix/v2:computeRouteMatrix"
            )
            url = "https://routes.googleapis.com/" + path
            headers["X-Goog-Api-Key"] = key
            headers["X-Goog-FieldMask"] = payload["fieldMask"]
            body = payload["request"]
        elif operation in ("geoapify", "locationiq"):
            method, maximum = "GET", 1000000
            key = (
                self.settings.geoapify_key
                if operation == "geoapify"
                else self.settings.locationiq_key
            )
            origin = (
                "https://api.geoapify.com"
                if operation == "geoapify"
                else "https://api.locationiq.com/v1"
            )
            url = origin + payload["path"]
            params = {
                **payload["parameters"],
                ("apiKey" if operation == "geoapify" else "key"): key,
            }
        else:
            raise GatewayFailure(422, "invalid_request")
        if not key:
            raise GatewayFailure(503, "configuration")
        try:
            # No redirects, automatic retries, arbitrary hosts, or provider error bodies.
            async with (
                asyncio.timeout(30),
                httpx.AsyncClient(
                    timeout=httpx.Timeout(25, connect=5),
                    follow_redirects=False,
                    trust_env=False,
                ) as client,
                client.stream(
                    method, url, headers=headers, params=params, json=body
                ) as response,
            ):
                if response.status_code != 200:
                    status = response.status_code
                    raise GatewayFailure(
                        status if status in (400, 401, 403, 404, 422, 429) else 502,
                        f"provider_http_{status}",
                    )
                result = bytearray()
                async for chunk in response.aiter_bytes():
                    if len(result) + len(chunk) > maximum:
                        raise GatewayFailure(502, "invalid_response")
                    result.extend(chunk)
            decoded = json.loads(result)
            if not isinstance(decoded, (dict, list)):
                raise GatewayFailure(502, "invalid_response")
            if operation == "gemini":
                candidates = (
                    decoded.get("candidates", []) if isinstance(decoded, dict) else []
                )
                if len(candidates) != 1 or candidates[0].get("finishReason") != "STOP":
                    raise GatewayFailure(502, "invalid_response")
            return decoded
        except GatewayFailure:
            raise
        except TimeoutError:
            raise GatewayFailure(504, "provider_timeout") from None
        except (httpx.HTTPError, ValueError, TypeError, AttributeError, RecursionError):
            raise GatewayFailure(502, "provider_unavailable") from None
