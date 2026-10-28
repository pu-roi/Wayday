"""Prepare a bounded public road extract for local feasibility evaluation.

The application never uses Overpass as a routing backend. Raw data and generated
graphs belong in ignored data directories, separate from personal phone data.
"""

from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import time
from urllib.parse import urlencode
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "data/downloads/routing-pilot"
GRAPH = ROOT / "data/local/routing-pilot"
IMAGE = "ghcr.io/valhalla/valhalla-scripted@sha256:31d96eb75f73e5f5b3dc40702edfda16c4e1793a384a8235bcf00dd3eed1b9bc"
PILOT = [121.045, 14.548, 121.116, 14.617]
BUFFER = 0.04
BOUNDS = [PILOT[0] - BUFFER, PILOT[1] - BUFFER, PILOT[2] + BUFFER, PILOT[3] + BUFFER]
USER_AGENT = "WaydayRoutingEvaluation/0.1 (+https://github.com/pu-roi/Wayday)"


def road_query(bounds: list[float]) -> str:
    west, south, east, north = bounds
    if not (-180 <= west < east <= 180 and -90 <= south < north <= 90):
        raise ValueError("Invalid WGS84 west/south/east/north bounds")
    if east - west > 0.3 or north - south > 0.3:
        raise ValueError("Evaluation query exceeds the bounded pilot budget")
    box = f"({south:.6f},{west:.6f},{north:.6f},{east:.6f})"
    return (
        '[out:xml][timeout:90][maxsize:134217728];\n'
        f'(way["highway"]{box};way["route"="ferry"]{box};);\n'
        '(._;rel(bw)["type"="restriction"];);\n'
        '(._;>;);\nout meta;\n'
    )


def extract_summary(raw: bytes) -> dict:
    root = ET.fromstring(raw)
    if root.find("remark") is not None:
        raise ValueError("Overpass returned an incomplete response")
    counts = Counter(item.tag for item in root if item.tag in {"node", "way", "relation"})
    if not counts["way"] or not counts["node"]:
        raise ValueError("Road extract contains no road network")
    keys = Counter()
    values = Counter()
    for item in root:
        tags = {tag.get("k"): tag.get("v") for tag in item.findall("tag")}
        if item.tag == "way" and "highway" in tags:
            for key in ["oneway", "access", "foot", "bicycle", "motorcycle", "motor_vehicle", "hgv", "maxheight", "maxwidth", "maxlength", "maxweight", "maxaxleload", "surface", "smoothness", "maxspeed"]:
                if key in tags:
                    keys[key] += 1
                    values[f"{key}={tags[key]}"] += 1
    meta = root.find("meta")
    return {
        "osm_base_timestamp": meta.get("osm_base") if meta is not None else None,
        "element_counts": dict(counts),
        "highway_tag_counts": dict(keys),
        "highway_restriction_values": dict(sorted(values.items())),
    }


def fetch(endpoint: str) -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    query = road_query(BOUNDS)
    started = time.monotonic()
    requested = datetime.now(timezone.utc).isoformat()
    request = Request(endpoint, data=urlencode({"data": query}).encode(), headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=120) as response:
        body = response.read(100 * 1024 * 1024 + 1)
    if len(body) > 100 * 1024 * 1024:
        raise ValueError("Road extract exceeds the 100 MiB evaluation budget")
    summary = extract_summary(body)
    (RAW / "roads.osm").write_bytes(body)
    (RAW / "query.overpassql").write_text(query, encoding="utf-8")
    manifest = {
        "pilot_bounds_west_south_east_north": PILOT,
        "graph_bounds_west_south_east_north": BOUNDS,
        "buffer_degrees_each_side": BUFFER,
        "buffer_note": "Approximately 4.3-4.4 km per side; graph coverage is not an expanded product coverage claim.",
        "source_endpoint": endpoint,
        "requested_at_utc": requested,
        "retrieved_at_utc": datetime.now(timezone.utc).isoformat(),
        "query": query,
        "query_sha256": hashlib.sha256(query.encode()).hexdigest(),
        "raw_sha256": hashlib.sha256(body).hexdigest(),
        "raw_bytes": len(body),
        "download_seconds": round(time.monotonic() - started, 3),
        "license": "ODbL-1.0",
        "attribution": "OpenStreetMap contributors",
        "license_url": "https://www.openstreetmap.org/copyright",
        **summary,
    }
    (RAW / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in manifest.items() if key not in {"query", "highway_restriction_values"}}, indent=2))


def convert() -> None:
    GRAPH.mkdir(parents=True, exist_ok=True)
    target = GRAPH / "pilot.osm.pbf"
    if target.exists():
        raise FileExistsError(f"Use a new evaluation directory instead of overwriting {target}")
    subprocess.run(["docker", "build", "-f", str(Path(__file__).with_name("Dockerfile.osmium")), "-t", "wayday-osmium:1.16.0", str(Path(__file__).parent)], check=True)
    subprocess.run(["docker", "run", "--rm", "--network", "none", "-v", f"{RAW.resolve()}:/input:ro", "-v", f"{GRAPH.resolve()}:/output", "wayday-osmium:1.16.0", "cat", "/input/roads.osm", "-o", "/output/pilot.osm.pbf"], check=True)
    subprocess.run(["docker", "run", "--rm", "--network", "none", "-v", f"{GRAPH.resolve()}:/input:ro", "wayday-osmium:1.16.0", "check-refs", "--check-relations", "/input/pilot.osm.pbf"], check=True)
    print(json.dumps({"pbf_bytes": target.stat().st_size, "pbf_sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "image": IMAGE}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["fetch", "convert"])
    parser.add_argument("--endpoint", default="https://overpass-api.de/api/interpreter")
    args = parser.parse_args()
    fetch(args.endpoint) if args.action == "fetch" else convert()
