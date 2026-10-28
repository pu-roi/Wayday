"""Reproduce a bounded, read-only OSM audit; downloads stay outside Git.

This tool does not geocode user labels, modify OSM, or seed the application.
"""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import sys
import unicodedata
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[2]
SAMPLE = ROOT / "docs/wayday/evidence/pilot-place-audit-sample.json"
RAW = ROOT / "data/downloads/pilot-audit"
EVIDENCE = ROOT / "docs/wayday/evidence"
USER_AGENT = "WaydayPilotAudit/0.1 (+https://github.com/pu-roi/Wayday)"


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFKD", value).casefold()
    return re.sub(r"[^a-z0-9]", "", value)


def name_matches(alias: str, name: str) -> bool:
    normalized = normalize(alias)
    if len(normalized) <= 4:
        # NBI is not Konbini; SSS is not "Princess School".
        tokens = re.findall(r"[a-z0-9]+", unicodedata.normalize("NFKD", name).casefold())
        return normalized in tokens or normalized == normalize(name)
    return normalized in normalize(name)


def make_query(bounds: list[float], aliases: list[str] | None = None) -> str:
    west, south, east, north = bounds
    if not (-180 <= west < east <= 180 and -90 <= south < north <= 90):
        raise ValueError("Invalid west/south/east/north bounds")
    box = f"({south},{west},{north},{east})"
    keys = ("amenity", "shop", "tourism", "office", "leisure", "historic")
    clauses = "\n".join(f'nwr["{key}"]{box};' for key in keys)
    hosts = 'Galleria|Megamall|30th|Center Pasig|Crescent|Centerpoint|Wynsum|Chipeco|UnionBank Plaza'
    if aliases:
        hosts += "|" + "|".join(re.escape(alias) for alias in sorted(set(aliases)))
    return (
        "[out:json][timeout:60];\n(\n"
        + clauses
        + f'\nnwr["name"~{json.dumps(hosts)},i]{box};\n);\nout meta center;\n'
    )


def fetch(endpoint: str) -> None:
    sample_bytes = SAMPLE.read_bytes()
    sample = json.loads(sample_bytes)
    query = make_query(
        sample["bounds_west_south_east_north"],
        [alias for item in sample["samples"] for alias in item["aliases"]],
    )
    RAW.mkdir(parents=True, exist_ok=True)
    query_hash = hashlib.sha256(query.encode()).hexdigest()
    (RAW / f"query-{query_hash[:12]}.overpassql").write_text(query, encoding="utf-8")
    started = datetime.now(timezone.utc).isoformat()
    request = Request(
        endpoint,
        data=urlencode({"data": query}).encode(),
        headers={"User-Agent": USER_AGENT},
    )
    try:
        with urlopen(request, timeout=90) as response:
            body = response.read()
        data = json.loads(body)
        if "elements" not in data or data.get("remark"):
            raise ValueError(f"Incomplete Overpass response: {data.get('remark')}")
    except (HTTPError, URLError, TimeoutError, ValueError) as error:
        failure = {"started_at_utc": started, "endpoint": endpoint, "query_sha256": query_hash, "error": str(error)}
        with (RAW / "failures.jsonl").open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(failure) + "\n")
        raise
    (RAW / "osm.json").write_bytes(body)
    (RAW / "query.overpassql").write_text(query, encoding="utf-8")
    manifest = {
        "started_at_utc": started,
        "retrieved_at_utc": datetime.now(timezone.utc).isoformat(),
        "endpoint": endpoint,
        "query": query,
        "query_sha256": query_hash,
        "bounds_west_south_east_north": sample["bounds_west_south_east_north"],
        "frozen_sample_sha256": hashlib.sha256(sample_bytes).hexdigest(),
        "raw_sha256": hashlib.sha256(body).hexdigest(),
        "raw_bytes": len(body),
        "elements": len(data["elements"]),
        "osm_base_timestamp": data.get("osm3s", {}).get("timestamp_osm_base"),
        "generator": data.get("generator"),
        "user_agent": USER_AGENT,
        "license": "ODbL-1.0",
        "attribution": "OpenStreetMap contributors",
        "license_url": "https://www.openstreetmap.org/copyright",
    }
    (RAW / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


def coordinates(element: dict) -> tuple[float, float] | None:
    point = element.get("center", element)
    if "lat" in point and "lon" in point:
        return point["lat"], point["lon"]
    return None


def candidates(sample: dict, elements: list[dict]) -> list[dict]:
    aliases = sample["aliases"]
    result = []
    for element in elements:
        tags = element.get("tags", {})
        names = [tags.get(key, "") for key in ("name", "name:en", "alt_name", "official_name", "brand")]
        if not any(name_matches(alias, name) for alias in aliases for name in names):
            continue
        point = coordinates(element)
        if point is None:
            continue
        result.append({
            "osm_id": f"{element['type']}/{element['id']}",
            "latitude": point[0], "longitude": point[1],
            "tags": tags,
            "osm_timestamp": element.get("timestamp"),
            "coordinate_kind": "node" if element["type"] == "node" else "bounding_box_center",
        })
    return result


def validate_extract(body: bytes, manifest: dict, query: str, sample_bytes: bytes) -> dict:
    if hashlib.sha256(body).hexdigest() != manifest["raw_sha256"]:
        raise ValueError("Raw extraction hash does not match its manifest")
    if query != manifest["query"]:
        raise ValueError("Query does not belong to the successful extraction")
    if hashlib.sha256(sample_bytes).hexdigest() != manifest["frozen_sample_sha256"]:
        raise ValueError("Frozen audit sample changed after extraction")
    data = json.loads(body)
    if data.get("remark") or "elements" not in data:
        raise ValueError("Incomplete Overpass extraction")
    if data.get("osm3s", {}).get("timestamp_osm_base") != manifest["osm_base_timestamp"]:
        raise ValueError("Source snapshot does not match its manifest")
    return data


def load_extract() -> tuple[dict, dict, dict]:
    sample_bytes = SAMPLE.read_bytes()
    manifest = json.loads((RAW / "manifest.json").read_text(encoding="utf-8"))
    data = validate_extract(
        (RAW / "osm.json").read_bytes(), manifest,
        (RAW / "query.overpassql").read_text(encoding="utf-8"), sample_bytes,
    )
    manifest["query_sha256"] = hashlib.sha256(manifest["query"].encode()).hexdigest()
    return json.loads(sample_bytes), manifest, data


def list_candidates() -> None:
    sample_manifest, _, data = load_extract()
    samples = sample_manifest["samples"]
    elements = data["elements"]
    result = {sample["id"]: candidates(sample, elements) for sample in samples}
    target = RAW / "candidates.json"
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for sample in samples:
        print(f"{sample['id']} {sample['name']}: {len(result[sample['id']])} name candidates")
    print(f"Manual branch review required: {target}")


def report() -> None:
    sample_manifest, manifest, data = load_extract()
    review = json.loads((EVIDENCE / "pilot-place-audit-review.json").read_text(encoding="utf-8"))
    samples = sample_manifest["samples"]
    reviews = {row["id"]: row for row in review["reviews"]}
    if len(review["reviews"]) != len(samples) or len(reviews) != len(samples) or set(reviews) != {row["id"] for row in samples}:
        raise ValueError("Every frozen sample requires exactly one manual review")
    elements = {f"{row['type']}/{row['id']}": row for row in data["elements"]}
    rows = []
    category_counts = {}
    for sample in samples:
        assessment = reviews[sample["id"]]
        status = assessment["status"]
        if status not in {"matched_site", "ambiguous", "not_found"}:
            raise ValueError(f"Unsupported review status: {status}")
        identifiers = assessment.get("osm_ids", [])
        if (status == "not_found" and identifiers) or (status != "not_found" and not identifiers):
            raise ValueError(f"Review identifiers contradict status for {sample['id']}")
        selected = [elements[identifier] for identifier in identifiers]
        points = [coordinates(element) for element in selected]
        if any(point is None for point in points):
            raise ValueError("Selected public feature has no coordinates")
        ref = sample_manifest["references"][sample["reference"]]
        row = {
            "sample_id": sample["id"], "category": sample["category"],
            "sample_name": sample["name"], "frozen_expected_area": sample["expected_area"],
            "reference_url": ref["url"], "reference_checked_on": ref["checked_on"],
            "status": status, "osm_ids": ";".join(identifiers),
            "osm_names": ";".join(element.get("tags", {}).get("name", "") for element in selected),
            "latitudes": ";".join(str(point[0]) for point in points),
            "longitudes": ";".join(str(point[1]) for point in points),
            "coordinate_kind": ";".join("node" if element["type"] == "node" else "bounding_box_center" for element in selected),
            "osm_record_timestamps": ";".join(element.get("timestamp", "") for element in selected),
            "opening_hours": ";".join(element.get("tags", {}).get("opening_hours", "unknown") for element in selected) or "unknown",
            "pin_accuracy": "not_independently_surveyed",
            "duplicate_assessment": assessment.get("duplicate_assessment", "none_confirmed_in_review"),
            "closed_business_signal": assessment.get("closed_business_signal", "unknown; no current-opening verification"),
            "reference_review": assessment.get("reference_review", ""),
            "review_reason": assessment["reason"],
            "source_license": "ODbL-1.0", "source_snapshot": manifest["osm_base_timestamp"],
        }
        rows.append(row)
        counts = category_counts.setdefault(sample["category"], Counter())
        counts[status] += 1
    target = EVIDENCE / "pilot-place-audit-results.csv"
    with target.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    summary = {
        "audit_id": sample_manifest["audit_id"],
        "sample_size": len(samples),
        "status_counts": dict(Counter(row["status"] for row in rows)),
        "category_counts": category_counts,
        "matched_sites_with_osm_hours": sum(row["status"] == "matched_site" and row["opening_hours"] != "unknown" for row in rows),
        "independently_surveyed_pins": 0,
        "extracted_elements_without_name_or_brand": sum(not any(element.get("tags", {}).get(key) for key in ("name", "brand", "name:en")) for element in elements.values()),
        "extraction": manifest,
        "audit_tool_python": sys.version.split()[0],
        "audit_tool_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "results_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "review_sha256": hashlib.sha256((EVIDENCE / "pilot-place-audit-review.json").read_bytes()).hexdigest(),
        "disposition": review["disposition"],
        "limitations": review["limitations"],
        "overture_decision": review["overture_decision"],
        "reproduction": [
            "py tools/geodata/pilot_audit.py fetch",
            "py tools/geodata/pilot_audit.py candidates",
            "py tools/geodata/pilot_audit.py report",
            "py -m unittest discover -s tools/geodata -p test_*.py",
        ],
    }
    (EVIDENCE / "pilot-place-audit-summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({key: summary[key] for key in ("sample_size", "status_counts", "category_counts", "matched_sites_with_osm_hours", "independently_surveyed_pins", "results_sha256")}, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    fetch_parser = sub.add_parser("fetch")
    fetch_parser.add_argument("--endpoint", default="https://overpass-api.de/api/interpreter")
    sub.add_parser("candidates")
    sub.add_parser("report")
    args = parser.parse_args()
    if args.command == "fetch":
        fetch(args.endpoint)
    elif args.command == "candidates":
        list_candidates()
    else:
        report()


if __name__ == "__main__":
    main()
