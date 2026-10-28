from dataclasses import dataclass
from datetime import datetime
from math import asin, cos, radians, sin, sqrt
from pathlib import Path
import json
import re
import unicodedata
from shapely.geometry import Point, shape
from shapely.errors import ShapelyError

# Pasig/Ortigas pilot rectangle; deliberately not Metro Manila-wide coverage.
BOUNDS = (121.035, 14.525, 121.115, 14.615)
ATTRIBUTION = "© OpenStreetMap contributors · ODbL 1.0"
BROAD_AREA_CATEGORIES = ('city', 'town', 'village', 'suburb', 'quarter', 'neighbourhood', 'locality')


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFKD", value.casefold())
    return " ".join(re.findall(r"[a-z0-9]+", value))


def inside(lat: float, lon: float) -> bool:
    west, south, east, north = BOUNDS
    return south <= lat <= north and west <= lon <= east


def metres(lat: float, lon: float, lat2: float, lon2: float) -> float:
    a = sin(radians(lat2-lat)/2)**2 + cos(radians(lat))*cos(radians(lat2))*sin(radians(lon2-lon)/2)**2
    return 6371000 * 2 * asin(sqrt(min(1, a)))


@dataclass(frozen=True)
class Place:
    id: str
    name: str
    address: str | None
    latitude: float
    longitude: float
    category: str
    aliases: tuple[str, ...]
    opening_hours: str | None
    source_date: str
    coordinate_kind: str = "mapped_point"
    footprint: dict | None = None

    def payload(self, near: tuple[float, float] | None = None) -> dict:
        return {
            "id": self.id, "name": self.name, "address": self.address,
            "latitude": self.latitude, "longitude": self.longitude,
            "category": self.category, "source": "openstreetmap",
            "source_url": "https://www.openstreetmap.org/" + self.id.removeprefix("osm/"),
            "source_date": self.source_date, "coordinate_kind": self.coordinate_kind,
            "opening_hours": self.opening_hours,
            "hours_status": "unverified" if self.opening_hours else "unknown",
            "distance_metres": round(metres(*near, self.latitude, self.longitude)) if near else None,
        }


class CatalogUnavailable(Exception):
    pass


class FileCatalog:
    """Explicit pilot read model, loaded once; no request-time community calls.

    PostGIS is the target catalog store. This bounded snapshot lets the pilot
    run without a container runtime. It is never an automatic database fallback.
    """
    def __init__(self, path: Path):
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
            if raw["bounds"] != list(BOUNDS):
                raise ValueError("Unexpected catalog coverage")
            self.source_date = raw["source_date"]
            datetime.fromisoformat(self.source_date.replace("Z", "+00:00"))
            self.places = [Place(**{**p, "aliases": tuple(p["aliases"])}) for p in raw["places"]]
            if not self.places or len(self.places) > 20000:
                raise ValueError("Invalid pilot catalog size")
            if any(not inside(p.latitude, p.longitude) for p in self.places):
                raise ValueError("Place outside pilot")
            self.index = [(p, normalize(p.name), [normalize(a) for a in p.aliases], normalize(" ".join([p.name, *p.aliases, p.address or "", p.category]))) for p in self.places]
            self.areas = {}
            for p in self.places:
                if p.footprint is not None:
                    geometry = shape(p.footprint)
                    if (geometry.geom_type != 'MultiPolygon' or geometry.is_empty
                            or not geometry.is_valid or not geometry.covers(Point(p.longitude, p.latitude))):
                        raise ValueError('Invalid place footprint')
                    self.areas[p.id] = geometry
        except (OSError, KeyError, TypeError, ValueError, ShapelyError) as e:
            raise CatalogUnavailable("The local pilot catalog is unavailable.") from e

    def search(self, q: str, limit: int, near: tuple[float, float] | None) -> list[dict]:
        query = normalize(q)
        if not query:
            return []
        tokens = query.split()
        candidates = []
        for p, name, aliases, text in self.index:
            if all(t in text for t in tokens):
                rank = 0 if query == name or query in aliases else 1 if name.startswith(query) else 2
                distance = metres(*near, p.latitude, p.longitude) if near else 0
                candidates.append((rank, distance, name, p.id, p))
        candidates.sort(key=lambda row: row[:4])
        return [row[4].payload(near) for row in candidates[:limit]]

    def nearby(self, lat: float, lon: float) -> list[dict]:
        target = Point(lon, lat)
        matches = []
        for p in self.places:
            distance = metres(lat, lon, p.latitude, p.longitude)
            area = self.areas.get(p.id)
            covered = p.category not in BROAD_AREA_CATEGORIES and area is not None and area.covers(target)
            if covered or distance <= 100:
                kind = 'area' if covered else 'point' if distance <= 10 and p.coordinate_kind == 'mapped_point' and p.category not in BROAD_AREA_CATEGORIES else 'nearby'
                matches.append((0 if covered else 1, area.area if covered else distance, p.id, kind, p))
        matches.sort(key=lambda row: row[:3])
        return [{**p.payload((lat, lon)), 'match_kind': kind}
                for _, _, _, kind, p in matches[:3]]
