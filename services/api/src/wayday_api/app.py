from pathlib import Path
from typing import Annotated
import os
from threading import Lock

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from wayday_api.places.catalog import ATTRIBUTION, BOUNDS, CatalogUnavailable, FileCatalog, inside
from wayday_api.places.models import PlaceSearchResponse


def create_app(catalog=None) -> FastAPI:
    app = FastAPI(title="Wayday pilot places", version="0.1.0")
    app.add_middleware(CORSMiddleware, allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?", allow_methods=["GET"])
    app.state.catalog = catalog
    app.state.catalog_lock = Lock()

    def load_catalog():
        if app.state.catalog is None:
            try:
                mode = os.environ.get("WAYDAY_CATALOG_MODE")
                if mode == "file":
                    app.state.catalog = FileCatalog(Path(os.environ.get("WAYDAY_CATALOG_PATH", "data/generated/pasig-places.json")))
                elif mode == "postgis":
                    from wayday_api.places.postgis import PostgisCatalog
                    app.state.catalog = PostgisCatalog(os.environ["WAYDAY_DATABASE_URL"])
                else:
                    raise CatalogUnavailable("Invalid catalog mode")
            except (CatalogUnavailable, KeyError):
                raise HTTPException(503, detail={"code": "catalog_unavailable", "message": "Place search is unavailable. Choose on map or use a saved place."})
        return app.state.catalog

    def get_catalog():
        with app.state.catalog_lock:
            return load_catalog()

    def response(repo, results):
        return {"places": results, "coverage": {"name": "Pasig/Ortigas pilot", "bounds": BOUNDS, "source_date": repo.source_date}, "attribution": ATTRIBUTION}

    def read(repo, action):
        try:
            return response(repo, action())
        except CatalogUnavailable:
            raise HTTPException(503, detail={"code": "catalog_unavailable", "message": "Place search is unavailable. Choose on map or use a saved place."})

    @app.get("/health")
    def health():
        repo = get_catalog()
        # Readiness includes the database; never report ready from process presence.
        read(repo, lambda: repo.search("__health_probe__", 1, None))
        return {"status": "ready", "catalog_mode": os.environ.get("WAYDAY_CATALOG_MODE", "unconfigured"), "source_date": repo.source_date}

    @app.get("/v1/places", response_model=PlaceSearchResponse)
    def search(q: Annotated[str, Query(min_length=2, max_length=100)], limit: Annotated[int, Query(ge=1, le=12)] = 8,
               near_lat: Annotated[float | None, Query(ge=-90, le=90)] = None,
               near_lon: Annotated[float | None, Query(ge=-180, le=180)] = None):
        if (near_lat is None) != (near_lon is None):
            raise HTTPException(422, detail="Both proximity coordinates are required.")
        near = (near_lat, near_lon) if near_lat is not None and inside(near_lat, near_lon) else None
        repo = get_catalog()
        return read(repo, lambda: repo.search(q.strip(), limit, near))

    @app.get("/v1/places/nearby", response_model=PlaceSearchResponse)
    def nearby(lat: Annotated[float, Query(ge=-90, le=90)], lon: Annotated[float, Query(ge=-180, le=180)]):
        repo = get_catalog()
        return read(repo, lambda: repo.nearby(lat, lon) if inside(lat, lon) else [])

    @app.middleware("http")
    async def private_responses(request, call_next):
        result = await call_next(request)
        result.headers["Cache-Control"] = "no-store"
        result.headers["X-Content-Type-Options"] = "nosniff"
        return result

    return app


app = create_app()
