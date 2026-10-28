"""Publish bounded public measurements; never copy raw geographic packages."""

import json
import re

from prepare_graph import RAW, ROOT
from run_graph import OUT


def main():
    source = json.loads((RAW / "manifest.json").read_text())
    build = json.loads((OUT / "build.json").read_text())
    routes = json.loads((OUT / "routes.json").read_text())
    log = re.sub(r'\x1b\[[0-9;]*m', '', (OUT / "build.log").read_text())
    profiles = {}
    for name, data in routes["profiles"].items():
        measured_routes = []
        for route in data["routes"]:
            measured = {key: value for key, value in route.items() if key != "source_way_review"}
            if "source_way_review" in route:
                review = route["source_way_review"]
                measured["source_way_review"] = {"trace_http_status": review["trace_http_status"], "way_count": len(review["ways"]), "note": review["note"], "restriction_examples": [way for way in review["ways"] if any(key in way["source_tags"] for key in ["maxweight", "maxheight", "hgv", "motor_vehicle"])]}
            measured_routes.append(measured)
        matrix = data["matrix"]
        profiles[name] = {"costing": data["costing"], "costing_options": data["costing_options"], "routes": measured_routes, "matrix": {key: value for key, value in matrix.items() if key != "cells_row_major"}, "matrix_seconds_row_major": [[cell["time"] for cell in row] for row in matrix["cells_row_major"]], "matrix_kilometers_row_major": [[cell["distance"] for cell in row] for row in matrix["cells_row_major"]]}
    build.pop("resource_samples")
    evidence = {
        "task": "M5-01", "recorded_on": "2026-10-27", "disposition": "bounded_static_estimate_feasibility_with_explicit_restriction_limits",
        "reference_integrity": {"tool": "osmium check-refs --check-relations", "missing_nodes_in_ways": 0, "missing_nodes_in_relations": 0, "missing_ways_in_relations": 0, "missing_relations_in_relations": 0},
        "source": source, "build": build,
        "graph_stage_timing_lines": [line for line in log.splitlines() if "build_tile_set took" in line],
        "public_points": routes["public_points"], "matrix_point_order": routes["point_order_for_matrices"], "profiles": profiles,
        "out_of_graph_probe": routes["out_of_graph_probe"], "weight_restriction_probe": routes["weight_restriction_probe"],
        "request_latency_median_seconds": routes["request_latency_median_seconds"], "request_latency_max_seconds": routes["request_latency_max_seconds"],
        "request_latency_scope": "18 public-site route requests and six 4x4 matrices; trace/restriction probes excluded; not a 38-location request or field-time benchmark",
        "runtime_stats": routes["runtime_stats"], "limitations": routes["limitations"],
        "environment_findings": ["Windows Application Control blocked native pyosmium DLL; left policy unchanged and used pinned Linux osmium-tool 1.16.0-1build1", "Docker Desktop startup exceeded 60-second CLI wait but subsequently initialized normally", "Existing unrelated containers resumed on Desktop startup; left untouched and avoided occupied port8002 using loopback18002", "Windows bind-mount shortcut build stalled in disk-sleep p9_client_rpc; preserved logs and used task-owned Docker volume", "First-attempt cgroup peak390639616 bytes includes timezone preparation; native-volume peak in build includes the subsequent graph build", "Initial extraction tool recorded request start under retrieved_at_utc; source snapshot timestamp is authoritative; future tool runs record both separately"],
        "third_party": [
            {"name": "Valhalla 3.9.1", "license": "MIT", "source": "https://github.com/valhalla/valhalla/tree/3.9.1", "reference": "https://raw.githubusercontent.com/valhalla/valhalla/3.9.1/docker/README.md"},
            {"name": "osmium-tool 1.16.0-1build1", "license": "GPL-3.0", "role": "build-time conversion only", "source": "https://github.com/osmcode/osmium-tool/tree/v1.16.0"},
            {"name": "Timezone Boundary Builder 2026d", "license": "ODbL-1.0 data / MIT code", "source": "https://github.com/evansiroky/timezone-boundary-builder/tree/2026d", "artifact": "timezones-with-oceans-1970.shapefile.zip"},
        ],
    }
    target = ROOT / "docs/wayday/evidence/routing-pilot-2026-10-27.json"
    target.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote bounded routing evidence: {target.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
