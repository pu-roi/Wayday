"""All upstream URLs, prompts, field masks and costs are server owned."""

import json
import hashlib
import math
import re
from datetime import datetime
from pathlib import Path

from .config import GatewayFailure

CONTRACTS = json.loads(
    Path(__file__).with_name("contracts.json").read_text(encoding="utf-8")
)
CURRENT_CONTRACTS = json.loads(
    Path(__file__).with_name("contracts-v2.json").read_text(encoding="utf-8")
)
CONTRACT_VERSIONS = {"d66-v1": CONTRACTS, "errand-v2": CURRENT_CONTRACTS}
CONTRACT_HASHES = {
    version: hashlib.sha256(Path(__file__).with_name(filename).read_bytes()).hexdigest()
    for version, filename in [("d66-v1", "contracts.json"), ("errand-v2", "contracts-v2.json")]
}
ROUTE_FIELDS = {
    "computeRoutes": {
        "routes.polyline.encodedPolyline",
        "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.warnings,fallbackInfo",
    },
    "computeRouteMatrix": {
        "originIndex,destinationIndex,status,condition,duration,distanceMeters,fallbackInfo"
    },
}
SDK_COSTS = {
    "places_5000": 5000,
    "places_20000": 20000,
    "places_35000": 35000,
    "navigation": 25000,
}


def require(value):
    if not value:
        raise GatewayFailure(422, "invalid_request")


def exact(value, required, optional=()):
    require(
        isinstance(value, dict)
        and set(required) <= value.keys()
        and value.keys() <= set(required) | set(optional)
    )


def interpretation(body):
    exact(body, ["purpose", "contractVersion", "request"])
    purpose = body["purpose"]
    version = body["contractVersion"]
    require(
        isinstance(purpose, str)
        and purpose in CONTRACTS
        and isinstance(version, str)
    )
    if version not in CONTRACT_VERSIONS:
        raise GatewayFailure(422, "unsupported_contract")
    request = body["request"]
    exact(request, ["systemInstruction", "generationConfig", "contents"])
    if {k: v for k, v in request.items() if k != "contents"} != CONTRACT_VERSIONS[version][purpose]:
        raise GatewayFailure(422, "contract_mismatch")
    contents = request["contents"]
    require(isinstance(contents, list) and len(contents) == 1)
    exact(contents[0], ["role", "parts"])
    require(
        contents[0]["role"] == "user"
        and isinstance(contents[0]["parts"], list)
        and len(contents[0]["parts"]) == 1
    )
    exact(contents[0]["parts"][0], ["text"])
    text = contents[0]["parts"][0]["text"]
    require(isinstance(text, str) and 0 < len(text) <= 50000)
    require(
        len(
            json.dumps(request, ensure_ascii=False, separators=(",", ":")).encode(
                "utf-8"
            )
        )
        <= 50000
    )
    try:
        data = json.loads(text)
    except (ValueError, RecursionError):
        raise GatewayFailure(422, "invalid_request") from None
    if purpose == "interpretation":
        require(
            isinstance(data, list)
            and 1 <= len(data) <= 12
            and all(isinstance(x, dict) for x in data)
        )
    else:
        exact(data, ["facts", "previousAnswers", "answer"])
        require(
            isinstance(data["facts"], dict)
            and isinstance(data["answer"], str)
            and 0 < len(data["answer"]) <= 8000
        )
        require(
            isinstance(data["previousAnswers"], list)
            and len(data["previousAnswers"]) <= 32
            and all(
                isinstance(x, str) and len(x) <= 8000 for x in data["previousAnswers"]
            )
        )
    return request


def coordinate(value, maximum):
    require(
        type(value) in (int, float) and math.isfinite(value) and abs(value) <= maximum
    )


def waypoint(value):
    exact(value, ["location"])
    exact(value["location"], ["latLng"])
    point = value["location"]["latLng"]
    exact(point, ["latitude", "longitude"])
    coordinate(point["latitude"], 90)
    coordinate(point["longitude"], 180)


def route(operation, body):
    require(operation in ROUTE_FIELDS)
    exact(body, ["request", "fieldMask"])
    require(
        isinstance(body["fieldMask"], str)
        and body["fieldMask"] in ROUTE_FIELDS[operation]
    )
    data = body["request"]
    matrix = operation == "computeRouteMatrix"
    exact(
        data,
        ["origins", "destinations", "travelMode"]
        if matrix
        else ["origin", "destination", "travelMode"],
        ["routingPreference", "departureTime"] + ([] if matrix else ["intermediates"]),
    )
    mode = data["travelMode"]
    require(mode in ("WALK", "BICYCLE", "DRIVE", "TWO_WHEELER"))
    require(data.get("routingPreference") in (None, "TRAFFIC_AWARE"))
    require(mode not in ("WALK", "BICYCLE") or "routingPreference" not in data)
    if "departureTime" in data:
        require(
            isinstance(data["departureTime"], str) and len(data["departureTime"]) <= 40
        )
        try:
            require(datetime.fromisoformat(data["departureTime"]).tzinfo is not None)
        except ValueError:
            raise GatewayFailure(422, "invalid_request") from None
    if matrix:
        for key in ("origins", "destinations"):
            require(isinstance(data[key], list) and 1 <= len(data[key]) <= 10)
            for item in data[key]:
                exact(item, ["waypoint"])
                waypoint(item["waypoint"])
        units = len(data["origins"]) * len(data["destinations"])
    else:
        waypoint(data["origin"])
        waypoint(data["destination"])
        require(
            isinstance(data.get("intermediates", []), list)
            and len(data.get("intermediates", [])) <= 23
        )
        for point in data.get("intermediates", []):
            waypoint(point)
        units = 1
    price = (
        15000
        if mode == "TWO_WHEELER"
        else 10000
        if data.get("routingPreference") == "TRAFFIC_AWARE"
        else 5000
    )
    return data, body["fieldMask"], units * price


SEARCH_PATHS = {
    ("geoapify", "/v1/geocode/autocomplete"): ("text", "limit", "filter", "bias"),
    ("geoapify", "/v2/places"): ("name", "categories", "limit", "filter", "bias"),
    ("geoapify", "/v1/geocode/reverse"): ("lat", "lon", "limit", "countrycodes"),
    ("locationiq", "/autocomplete"): (
        "q",
        "format",
        "limit",
        "countrycodes",
        "addressdetails",
        "viewbox",
        "bounded",
        "importancesort",
    ),
    ("locationiq", "/nearby"): ("lat", "lon", "tag", "radius", "format", "limit"),
    ("locationiq", "/reverse"): ("lat", "lon", "format", "limit", "countrycodes"),
}


def search(provider, body):
    exact(body, ["path", "parameters"])
    path, params = body["path"], body["parameters"]
    require(isinstance(path, str) and (provider, path) in SEARCH_PATHS)
    require(
        isinstance(params, dict) and params.keys() <= set(SEARCH_PATHS[provider, path])
    )
    require(all(isinstance(v, str) and 0 < len(v) <= 300 for v in params.values()))
    require(
        params.get("limit", "1").isdigit() and 1 <= int(params.get("limit", "1")) <= 20
    )
    if path.endswith(("autocomplete",)):
        require(
            0 < len(params.get("text" if provider == "geoapify" else "q", "")) <= 100
        )
    for key, maximum in [("lat", 90), ("lon", 180)]:
        if key in params:
            try:
                coordinate(float(params[key]), maximum)
            except ValueError:
                raise GatewayFailure(422, "invalid_request") from None
    if path.endswith(("/reverse", "/nearby")):
        require("lat" in params and "lon" in params)
    if path == "/v2/places":
        require(
            "categories" in params
            and params.get("filter", "").startswith("countrycode:ph|circle:")
        )
        require(
            bool(
                re.fullmatch(
                    r"countrycode:ph\|circle:-?[\d.]+,-?[\d.]+,5000", params["filter"]
                )
            )
        )
    if "bias" in params:
        require(bool(re.fullmatch(r"proximity:-?[\d.]+,-?[\d.]+", params["bias"])))
    if "radius" in params:
        require(params["radius"] == "5000")
    # Force geography/format; callers cannot expand provider coverage or select another host.
    params = dict(params)
    if provider == "geoapify":
        if path == "/v1/geocode/autocomplete":
            params["filter"] = "countrycode:ph"
        if path.endswith("/reverse"):
            params["countrycodes"] = "ph"
    else:
        params["format"] = "json"
        if path != "/nearby":
            params["countrycodes"] = "ph"
    return path, params
