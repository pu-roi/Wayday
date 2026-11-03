"""Same-origin viewer and capability endpoints, isolated from paid providers."""
import asyncio
import re
import hashlib
import time
from collections import deque
from pathlib import Path
from uuid import UUID

from fastapi import Depends, Request
from fastapi.responses import FileResponse
from google.api_core.exceptions import GoogleAPIError, RetryError
from google.auth.exceptions import GoogleAuthError

from .config import GatewayFailure
from .sharing import FirestoreShareStore, ShareService


def install_sharing(app, settings, authenticate, store=None):
    root = Path(__file__).with_name("share_web")
    service = ShareService(store) if store is not None else None
    bursts = {}

    def spacing(identity, limit):
        now = time.monotonic()
        bucket = hashlib.sha256(identity.encode()).hexdigest()
        for name in list(bursts):
            if not bursts[name] or bursts[name][-1] < now - 60:
                del bursts[name]
        if bucket not in bursts and len(bursts) >= 1024:
            raise GatewayFailure(429, "share_spacing")
        recent = bursts.setdefault(bucket, deque())
        while recent and recent[0] <= now - 60:
            recent.popleft()
        if len(recent) >= limit:
            raise GatewayFailure(429, "share_spacing")
        recent.append(now)

    def configured():
        if not settings.sharing_enabled:
            raise GatewayFailure(503, "sharing_unavailable")

    def key(value):
        try:
            if str(UUID(value)) != value:
                raise ValueError()
        except (ValueError, AttributeError):
            raise GatewayFailure(404, "share_unavailable") from None
        return value

    def bearer(request):
        scheme, _, token = request.headers.get("Authorization", "").partition(" ")
        if scheme != "Bearer" or not re.fullmatch(r"[A-Za-z0-9_-]{43}", token):
            raise GatewayFailure(404, "share_unavailable")
        return token

    async def run(method, *args):
        nonlocal service
        configured()
        spacing(("create:" + args[0]) if method == "create" else "share:" + args[0],
                12 if method == "create" else 120)
        try:
            if service is None:
                service = ShareService(await asyncio.to_thread(
                    FirestoreShareStore, settings.project_id, settings.share_collection))
            return await asyncio.to_thread(getattr(service, method), *args)
        except (GoogleAPIError, GoogleAuthError, RetryError):
            raise GatewayFailure(503, "sharing_unavailable") from None

    async def body(request):
        try:
            value = await request.json()
            if not isinstance(value, dict):
                raise ValueError()
            return value
        except ValueError:
            raise GatewayFailure(422, "invalid_request") from None

    @app.post("/v1/shares", status_code=201)
    async def create(request: Request, app_id=Depends(authenticate)):
        return await run("create", app_id, await body(request))

    @app.get("/v1/shares/{share_id}")
    async def read(share_id: str, request: Request):
        # Reject malformed links before opening any database connection.
        return await run("read", key(share_id), bearer(request))

    @app.post("/v1/shares/{share_id}/events", dependencies=[Depends(authenticate)])
    async def update(share_id: str, request: Request):
        return await run("update", key(share_id), bearer(request), await body(request))

    @app.post("/v1/shares/{share_id}/pair", dependencies=[Depends(authenticate)])
    async def pair(share_id: str, request: Request):
        value = await body(request)
        if set(value) != {"recipientToken"}:
            raise GatewayFailure(422, "invalid_request")
        return await run("pair", key(share_id), bearer(request), value["recipientToken"])

    @app.get("/.well-known/assetlinks.json")
    async def associations():
        values = []
        if settings.share_package and settings.share_certificate:
            values.append({"relation": ["delegate_permission/common.handle_all_urls"],
                "target": {"namespace": "android_app", "package_name": settings.share_package,
                           "sha256_cert_fingerprints": [settings.share_certificate]}})
        return values

    @app.get("/share/config")
    async def browser_config():
        configured()
        return {"mapsKey": settings.share_browser_key, "package": settings.share_package}

    @app.get("/share/privacy")
    async def privacy():
        return FileResponse(root / "privacy.html", headers={"Referrer-Policy": "no-referrer"})

    @app.get("/share/terms")
    async def terms():
        return FileResponse(root / "terms.html", headers={"Referrer-Policy": "no-referrer"})

    @app.get("/share/")
    @app.get("/pair/")
    async def viewer():
        response = FileResponse(root / "index.html")
        response.headers.update({
            "Referrer-Policy": "strict-origin",
            "X-Frame-Options": "DENY",
            "Content-Security-Policy": "default-src 'self'; script-src 'self' https://maps.googleapis.com https://maps.gstatic.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https://*.googleapis.com https://*.gstatic.com https://*.google.com; connect-src 'self' https://*.googleapis.com https://*.gstatic.com https://*.google.com; frame-src https://*.google.com; object-src 'none'; base-uri 'none'; frame-ancestors 'none'",
            "X-Robots-Tag": "noindex, nofollow, noarchive"})
        return response

    @app.get("/share/{asset:path}")
    async def assets(asset: str):
        allowed = {"viewer.js", "viewer.css", "assets/Figtree.ttf", "assets/wayday-logo.png", "assets/OFL.txt"}
        if asset not in allowed:
            raise GatewayFailure(404, "unavailable")
        return FileResponse(root / asset)
