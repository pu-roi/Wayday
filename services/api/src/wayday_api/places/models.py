from typing import Literal
from pydantic import BaseModel, Field


class PlacePayload(BaseModel):
    id: str
    name: str
    address: str | None
    latitude: float = Field(ge=-90, le=90, allow_inf_nan=False)
    longitude: float = Field(ge=-180, le=180, allow_inf_nan=False)
    category: str
    source: Literal["openstreetmap"]
    source_url: str
    source_date: str
    coordinate_kind: str
    opening_hours: str | None
    hours_status: Literal["unknown", "unverified"]
    distance_metres: int | None
    match_kind: Literal['area', 'point', 'nearby'] | None = None


class Coverage(BaseModel):
    name: str
    bounds: tuple[float, float, float, float]
    source_date: str


class PlaceSearchResponse(BaseModel):
    places: list[PlacePayload]
    coverage: Coverage
    attribution: str
