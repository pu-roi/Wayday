"""Measure real local routes; public-site coordinates are not verified entrances."""

from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import statistics
import time
import xml.etree.ElementTree as ET
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from prepare_graph import RAW, ROOT
from run_graph import OUT, docker, NAME


AUDIT = ROOT / "docs/wayday/evidence/pilot-place-audit-results.csv"
PROFILES = {
    "walking": ("pedestrian", {}),
    "biking": ("bicycle", {}),
    "motorcycle": ("motorcycle", {}),
    "sedan": ("auto", {}),
    "pickup_light": ("auto", {"height": 1.85, "width": 1.8, "length": 5.1, "weight": 2.1}),
    "heavy_delivery": ("truck", {"height": 3.5, "width": 2.4, "length": 8, "weight": 12, "axle_load": 6, "axle_count": 2, "hazmat": False, "hgv_no_access_penalty": 43200}),
}
POINT_IDS = ["G01", "G02", "B01", "L01"]
PAIRS = [("G01", "G02"), ("B01", "L01"), ("L01", "B01")]


def request_json(base: str, action: str, payload: dict) -> tuple[int, dict, float]:
    started = time.monotonic()
    request = Request(f"{base}/{action}", data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urlopen(request, timeout=20) as response:
            return response.status, json.load(response), round(time.monotonic() - started, 4)
    except HTTPError as error:
        return error.code, json.load(error), round(time.monotonic() - started, 4)


def matrix_summary(data: dict, expected: int) -> dict:
    if data.get("units") != "kilometers":
        raise ValueError("Unexpected matrix distance units")
    rows = data["sources_to_targets"]
    if len(rows) != expected or any(len(row) != expected for row in rows):
        raise ValueError("Incomplete matrix shape")
    unreachable = 0
    asymmetric = 0
    for source, row in enumerate(rows):
        for target, cell in enumerate(row):
            duration, distance = cell.get("time"), cell.get("distance")
            if (duration is None) != (distance is None):
                raise ValueError("Partial matrix cell")
            if duration is None:
                unreachable += 1
            elif not math.isfinite(duration) or not math.isfinite(distance) or duration < 0 or distance < 0:
                raise ValueError("Negative road estimate")
            if source < target and duration != rows[target][source].get("time"):
                asymmetric += 1
    return {"rows": expected, "cells": expected * expected, "unreachable_cells": unreachable, "asymmetric_pairs": asymmetric, "units": data.get("units"), "algorithm": data.get("algorithm"), "cells_row_major": rows}


def decode_polyline6(encoded: str) -> list[list[float]]:
    values = []
    index = latitude = longitude = 0
    while index < len(encoded):
        deltas = []
        for _ in range(2):
            result = shift = 0
            while True:
                value = ord(encoded[index]) - 63
                index += 1
                result |= (value & 0x1F) << shift
                shift += 5
                if value < 0x20:
                    break
            deltas.append(~(result >> 1) if result & 1 else result >> 1)
        latitude += deltas[0]
        longitude += deltas[1]
        values.append([latitude / 1e6, longitude / 1e6])
    return values


def distance_meters(a: list[float], b: list[float]) -> float:
    lat1, lon1, lat2, lon2 = map(math.radians, [*a, *b])
    haversine = math.sin((lat2 - lat1) / 2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2)**2
    return round(6371000 * 2 * math.asin(min(1, math.sqrt(haversine))), 1)


def load_points() -> dict:
    points = {}
    with AUDIT.open(encoding="utf-8", newline="") as source:
        for row in csv.DictReader(source):
            if row["sample_id"] in POINT_IDS:
                if row["status"] != "matched_site":
                    raise ValueError(f"Unconfirmed audit site: {row['sample_id']}")
                points[row["sample_id"]] = {
                    "id": row["sample_id"], "label": row["sample_name"], "lat": float(row["latitudes"]), "lon": float(row["longitudes"]),
                    "osm_id": row["osm_ids"], "coordinate_kind": row["coordinate_kind"], "accuracy": row["pin_accuracy"],
                }
    if set(points) != set(POINT_IDS):
        raise ValueError("Missing public audit points")
    return points


def main(base: str) -> None:
    if base != "http://127.0.0.1:18002":
        raise ValueError("This evaluator only queries the local pilot engine")
    OUT.mkdir(parents=True, exist_ok=True)
    points = load_points()
    source_ways = {}
    for _, element in ET.iterparse(RAW / "roads.osm", events=["end"]):
        if element.tag == "way":
            source_ways[int(element.get("id"))] = {tag.get("k"): tag.get("v") for tag in element.findall("tag")}
    results = {}
    all_latencies = []
    for profile, (costing, options) in PROFILES.items():
        costing_options = {costing: {"ignore_restrictions": False, "ignore_oneways": False, "ignore_access": False, **options}}
        profile_result = {"costing": costing, "costing_options": costing_options, "routes": []}
        for start, end in PAIRS:
            locations = [{"lat": points[item]["lat"], "lon": points[item]["lon"]} for item in [start, end]]
            payload = {"locations": locations, "costing": costing, "costing_options": costing_options, "units": "kilometers"}
            code, data, elapsed = request_json(base, "route", payload)
            (OUT / f"route-{profile}-{start}-{end}.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
            measured = {"from": start, "to": end, "http_status": code, "request_seconds": elapsed}
            all_latencies.append(elapsed)
            if code == 200:
                trip = data["trip"]
                geometry = decode_polyline6(trip["legs"][0]["shape"])
                measured.update({"summary": trip["summary"], "geometry_points": len(geometry), "start_snap_distance_meters": distance_meters(list(locations[0].values()), geometry[0]), "end_snap_distance_meters": distance_meters(list(locations[1].values()), geometry[-1]), "street_names": sorted({name for leg in trip["legs"] for maneuver in leg["maneuvers"] for name in maneuver.get("street_names", [])})})
                if start == "B01" and end == "L01":
                    trace_code, trace, trace_elapsed = request_json(base, "trace_attributes", {"encoded_polyline": trip["legs"][0]["shape"], "shape_match": "edge_walk", "costing": costing, "costing_options": costing_options, "filters": {"action": "include", "attributes": ["edge.way_id", "edge.names", "edge.road_class", "edge.traversability"]}})
                    (OUT / f"trace-{profile}.json").write_text(json.dumps(trace, indent=2) + "\n", encoding="utf-8")
                    reviewed = []
                    for way_id in sorted({edge["way_id"] for edge in trace.get("edges", [])}):
                        tags = source_ways.get(way_id, {})
                        reviewed.append({"way_id": way_id, "source_tags": {key: value for key, value in tags.items() if key in {"name", "highway", "oneway", "access", "foot", "bicycle", "motorcycle", "motor_vehicle", "hgv", "maxheight", "maxwidth", "maxlength", "maxweight", "maxaxleload", "surface", "smoothness"}}})
                    measured["source_way_review"] = {"trace_http_status": trace_code, "trace_request_seconds": trace_elapsed, "ways": reviewed, "note": "Cross-check against the same OSM snapshot, not independent legal-access/road-condition verification"}
            else:
                measured["error"] = data
            profile_result["routes"].append(measured)
        locations = [{"lat": points[item]["lat"], "lon": points[item]["lon"]} for item in POINT_IDS]
        code, data, elapsed = request_json(base, "sources_to_targets", {"sources": locations, "targets": locations, "costing": costing, "costing_options": costing_options, "units": "kilometers", "verbose": True})
        (OUT / f"matrix-{profile}.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        profile_result["matrix"] = {"http_status": code, "request_seconds": elapsed, **(matrix_summary(data, len(POINT_IDS)) if code == 200 else {"error": data})}
        all_latencies.append(elapsed)
        results[profile] = profile_result
    # A real out-of-graph point must fail honestly; it is not a within-pilot disconnected-pair claim.
    code, unavailable, elapsed = request_json(base, "route", {"locations": [{"lat": points["G01"]["lat"], "lon": points["G01"]["lon"]}, {"lat": 14.7, "lon": 120.5}], "costing": "auto"})
    restriction_payload = {"locations": [{"lat": points[item]["lat"], "lon": points[item]["lon"]} for item in ["B01", "L01"]], "costing": "truck", "costing_options": {"truck": {**PROFILES["heavy_delivery"][1], "weight": 20}}, "units": "kilometers"}
    restriction_code, restriction_route, restriction_seconds = request_json(base, "route", restriction_payload)
    restriction_probe = {"fixture_weight_tonnes": 20, "http_status": restriction_code, "request_seconds": restriction_seconds, "compared_source_way_id": 23395375, "source_maxweight_tonnes": 15}
    if restriction_code == 200:
        trace_code, trace, _ = request_json(base, "trace_attributes", {"encoded_polyline": restriction_route["trip"]["legs"][0]["shape"], "shape_match": "edge_walk", "costing": "truck", "costing_options": restriction_payload["costing_options"], "filters": {"action": "include", "attributes": ["edge.way_id"]}})
        restriction_probe.update({"trace_http_status": trace_code, "uses_compared_way": any(edge["way_id"] == 23395375 for edge in trace.get("edges", [])), "summary": restriction_route["trip"]["summary"]})
    source = json.loads((RAW / "manifest.json").read_text(encoding="utf-8"))
    summary = {
        "measured_at_utc": datetime.now(timezone.utc).isoformat(),
        "public_points": list(points.values()),
        "point_order_for_matrices": POINT_IDS,
        "profiles": results,
        "out_of_graph_probe": {"http_status": code, "response": unavailable, "request_seconds": elapsed},
        "weight_restriction_probe": restriction_probe,
        "request_latency_median_seconds": statistics.median(all_latencies),
        "request_latency_max_seconds": max(all_latencies),
        "source_osm_base_timestamp": source["osm_base_timestamp"],
        "raw_extract_sha256": source["raw_sha256"],
        "audit_csv_sha256": hashlib.sha256(AUDIT.read_bytes()).hexdigest(),
        "runtime_stats": json.loads(docker("stats", "--no-stream", "--format", "{{json .}}", NAME)),
        "limitations": ["OSM public-site coordinates and snapping are not entrance surveys", "Synthetic representative pickup/heavy dimensions are evaluation fixtures, not user defaults", "No observed travel-time or legal-access field validation", "No live traffic or ground-clearance model", "Missing restriction tags remain unknown"],
    }
    (OUT / "routes.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"profiles": {key: {"routes_ok": sum(route["http_status"] == 200 for route in value["routes"]), "matrix_status": value["matrix"]["http_status"], "asymmetric_pairs": value["matrix"].get("asymmetric_pairs")} for key, value in results.items()}, "latency_median_seconds": summary["request_latency_median_seconds"], "latency_max_seconds": summary["request_latency_max_seconds"], "out_of_graph_status": code}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="http://127.0.0.1:18002")
    main(parser.parse_args().base)
