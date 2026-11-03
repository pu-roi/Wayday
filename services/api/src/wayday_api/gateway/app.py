import asyncio
import json
from uuid import uuid4

from fastapi import Depends, FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from firebase_admin.exceptions import FirebaseError
from google.api_core.exceptions import GoogleAPIError, RetryError
from google.auth.exceptions import GoogleAuthError
from jwt import PyJWTError
from requests.exceptions import RequestException

from . import validation as v
from .config import GatewayFailure, Settings
from .providers import Providers
from .navigation import route_request, route_response


def create_gateway(settings=None, *, provider=None, verify=None, ledger=None):
    settings = settings or Settings.environment()
    production = provider is None
    provider = provider or Providers(settings)
    app = FastAPI(
        title="Wayday provider gateway",
        version="1.0.0",
        docs_url=None,
        redoc_url=None,
        openapi_url=None,
    )

    async def authenticate(request: Request):
        if not settings.project_id or not settings.app_ids:
            raise GatewayFailure(503, "configuration")
        token = request.headers.get("X-Firebase-AppCheck", "")
        if not token or len(token) > 8192:
            raise GatewayFailure(401, "access")
        try:
            if verify is not None:
                app_id = await verify(token)
            else:

                def check():
                    import firebase_admin
                    from firebase_admin import app_check

                    try:
                        firebase = firebase_admin.get_app("wayday-gateway")
                    except ValueError:
                        firebase = firebase_admin.initialize_app(
                            options={"projectId": settings.project_id},
                            name="wayday-gateway",
                        )
                    return app_check.verify_token(token, app=firebase).get("app_id")

                app_id = await asyncio.to_thread(check)
            if app_id not in settings.app_ids:
                raise ValueError()
            return app_id
        except (
            ValueError,
            FirebaseError,
            GoogleAuthError,
            PyJWTError,
            RequestException,
        ):
            raise GatewayFailure(401, "access") from None

    async def account():
        nonlocal ledger
        if ledger is None:
            if not settings.ledger_document:
                raise GatewayFailure(503, "accounting_unavailable")
            try:
                from .ledger import FirestoreLedger

                ledger = await asyncio.to_thread(
                    FirestoreLedger, settings.project_id, settings.ledger_document
                )
            except (GoogleAPIError, GoogleAuthError, RetryError, ValueError, OSError):
                raise GatewayFailure(503, "accounting_unavailable") from None
        return ledger

    async def payload(request):
        try:
            result = json.loads(
                await request.body(),
                parse_constant=lambda _: (_ for _ in ()).throw(ValueError()),
            )
            if not isinstance(result, dict):
                raise TypeError()
            return result
        except (ValueError, TypeError, RecursionError):
            raise GatewayFailure(422, "invalid_request") from None

    @app.exception_handler(GatewayFailure)
    async def failure(_, error):
        return JSONResponse(
            {"error": {"code": error.code}},
            status_code=error.status,
            headers={"Cache-Control": "no-store", "X-Content-Type-Options": "nosniff"},
        )

    @app.exception_handler(RequestValidationError)
    async def invalid(_, __):
        return await failure(None, GatewayFailure(422, "invalid_request"))

    @app.middleware("http")
    async def boundary(request, call_next):
        try:
            body = bytearray()
            async for chunk in request.stream():
                if len(body) + len(chunk) > 60000:
                    return await failure(
                        request, GatewayFailure(413, "request_too_large")
                    )
                body.extend(chunk)
            request._body = bytes(body)
            response = await call_next(request)
        except GatewayFailure as error:
            return await failure(request, error)
        except (ValueError, TypeError, KeyError, OSError, RuntimeError):
            return await failure(request, GatewayFailure(503, "unavailable"))
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        return response

    @app.get("/health")
    async def health():
        if (
            not settings.project_id
            or not settings.app_ids
            or not getattr(provider, "ready", True)
            or (production and not settings.ledger_document)
        ):
            raise GatewayFailure(503, "configuration")
        return {
            "status": "configured", "version": 1, "providerCalls": False,
            "contracts": v.CONTRACT_HASHES,
            "capabilities": {
                "alternativeNavigation": settings.alternative_navigation,
                "dailyCeilings": settings.geoapify_testing_limits,
            },
        }

    @app.post("/v1/interpretations", dependencies=[Depends(authenticate)])
    async def interpret(request: Request):
        body = await payload(request)
        try:
            approved = v.interpretation(body)
        except (KeyError, TypeError, ValueError):
            raise GatewayFailure(422, "invalid_request") from None
        try:
            async with asyncio.timeout(30):
                return await provider.request("gemini", approved)
        except TimeoutError:
            raise GatewayFailure(504, "provider_timeout") from None

    @app.post("/v1/routes/{operation}", dependencies=[Depends(authenticate)])
    async def routes(operation: str, request: Request):
        book = await account()
        body = await payload(request)
        try:
            data, fields, cost = v.route(operation, body)
        except (KeyError, TypeError, ValueError):
            raise GatewayFailure(422, "invalid_request") from None
        await asyncio.to_thread(book.reserve, str(uuid4()), cost, sku=operation)
        return await provider.request(operation, {"request": data, "fieldMask": fields})

    @app.post("/v1/navigation/geoapify/route", dependencies=[Depends(authenticate)])
    async def alternative_route(request: Request):
        if not settings.alternative_navigation or (settings.geoapify_testing_limits and settings.geoapify_daily_credits <= 0):
            raise GatewayFailure(503, "alternative_disabled")
        if production and not settings.geoapify_key:
            raise GatewayFailure(503, "configuration")
        body = await payload(request)
        params, credits = route_request(body)
        book = await account()
        await asyncio.to_thread(book.geoapify_route_start, credits, settings.geoapify_daily_credits,
                                enforce_limits=settings.geoapify_testing_limits)
        data = await provider.request("geoapify_navigation", params)
        return route_response(data, body["points"])

    @app.post("/v1/search/{provider_id}", dependencies=[Depends(authenticate)])
    async def search(provider_id: str, request: Request):
        body = await payload(request)
        try:
            path, params = v.search(provider_id, body)
        except (KeyError, TypeError, ValueError):
            raise GatewayFailure(422, "invalid_request") from None
        book = await account()
        await asyncio.to_thread(book.search_start, provider_id,
                                credit_limit=settings.geoapify_daily_credits if settings.alternative_navigation else 0,
                                enforce_limits=settings.geoapify_testing_limits)
        return await provider.request(provider_id, {"path": path, "parameters": params})

    @app.post("/v1/usage/{operation}", dependencies=[Depends(authenticate)])
    async def usage(operation: str, request: Request):
        body = await payload(request)
        book = await account()
        v.require(operation in ("reserve", "release", "check"))
        v.exact(
            body,
            ["requestId"] if operation == "release" else ["requestId", "sku", "units"],
        )
        v.require(isinstance(body["requestId"], str) and len(body["requestId"]) == 36)
        try:
            from uuid import UUID

            UUID(body["requestId"])
        except ValueError:
            raise GatewayFailure(422, "invalid_request") from None
        if operation == "release":
            await asyncio.to_thread(book.release, body["requestId"])
        else:
            sku, units = body["sku"], body["units"]
            v.require(
                isinstance(sku, str)
                and (sku in v.SDK_COSTS or sku == "routes_preflight")
            )
            v.require(type(units) is int and 1 <= units <= 2500)
            v.require(
                operation == "check" or (sku != "routes_preflight" and units <= 25)
            )
            cost = units * (15000 if sku == "routes_preflight" else v.SDK_COSTS[sku])
            await asyncio.to_thread(
                book.reserve,
                body["requestId"],
                cost,
                sku=sku,
                units=units,
                check_only=operation == "check",
                channel="sdk",
            )
        return {"status": "ok"}

    return app


app = create_gateway()
