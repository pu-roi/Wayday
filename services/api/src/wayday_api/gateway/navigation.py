"""Ordered Geoapify routing boundary. No place lookup, matrix or stored geometry."""

import math

from .config import GatewayFailure


def number(value, maximum):
    if type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= maximum:
        raise ValueError()
    return value


def coordinate(value):
    if not isinstance(value, list) or len(value) != 2:
        raise ValueError()
    lat, lon = value
    if any(type(x) not in (int, float) or not math.isfinite(x) for x in value):
        raise ValueError()
    if abs(lat) > 90 or abs(lon) > 180:
        raise ValueError()
    return [lat, lon]


def route_request(body):
    try:
        if set(body) != {"points", "profile"}:
            raise ValueError()
        points = body["points"]
        if not isinstance(points, list) or not 2 <= len(points) <= 26:
            raise ValueError()
        points = [coordinate(p) for p in points]
        # Bicycle remains unqualified. Truck must be explicitly confirmed by the
        # client and sent as the already-approved ordinary-driving estimate.
        mode = {"walk": "walk", "motor": "motorcycle", "sedan": "drive"}[body["profile"]]
        return {
            "waypoints": "|".join(f"{p[0]},{p[1]}" for p in points),
            "mode": mode, "format": "geojson", "units": "metric",
            "lang": "en", "details": "instruction_details",
            "optimize_stops": "false",
            "intermediate_waypoint_mode": "stopover",
            "traffic": "free_flow" if mode == "walk" else "approximated",
        }, len(points) - 1 + 100
    except (ValueError, KeyError, TypeError):
        raise GatewayFailure(422, "invalid_request") from None


def near(a, b):
    # Routing may snap to a road; never replace the requested destination.
    return math.hypot(a[0] - b[0], (a[1] - b[1]) * math.cos(math.radians(a[0]))) < .005


def route_response(data, points):
    try:
        features = data["features"]
        if len(features) != 1:
            raise ValueError()
        feature = features[0]
        geometry, properties = feature["geometry"], feature["properties"]
        if geometry["type"] != "MultiLineString" or properties["distance_units"] != "meters":
            raise ValueError()
        lines, legs = geometry["coordinates"], properties["legs"]
        if len(lines) != len(points) - 1 or len(legs) != len(lines):
            raise ValueError()
        result = []
        total_vertices = 0
        for i, (line, leg) in enumerate(zip(lines, legs, strict=True)):
            total_vertices += len(line)
            if len(line) < 2 or total_vertices > 30000:
                raise ValueError()
            coords = [coordinate([p[1], p[0]]) for p in line if len(p) == 2]
            if len(coords) != len(line) or not near(coords[0], points[i]) or not near(coords[-1], points[i + 1]):
                raise ValueError()
            steps, end = [], 0
            raw_steps = leg["steps"]
            if not 1 <= len(raw_steps) <= 2000:
                raise ValueError()
            for raw in raw_steps:
                start, finish = raw["from_index"], raw["to_index"]
                if type(start) is not int or type(finish) is not int or start != end or not start <= finish < len(coords):
                    raise ValueError()
                instruction = raw["instruction"]["text"]
                if not isinstance(instruction, str) or not instruction.strip() or len(instruction) > 1000:
                    raise ValueError()
                maneuver = raw["instruction"].get("type", "None")
                if not isinstance(maneuver, str) or len(maneuver) > 80:
                    raise ValueError()
                steps.append({"from": start, "to": finish,
                              "distance": number(raw["distance"], 10000000),
                              "duration": number(raw["time"], 10000000),
                              "instruction": instruction, "maneuver": maneuver})
                end = finish
            if end != len(coords) - 1 or steps[-1]["from"] != end:
                raise ValueError()
            result.append({"coordinates": coords, "steps": steps,
                           "distance": number(leg["distance"], 10000000),
                           "duration": number(leg["time"], 10000000)})
        return {"version": 1, "legs": result}
    except (ValueError, KeyError, TypeError, IndexError, OverflowError):
        raise GatewayFailure(502, "invalid_route") from None
