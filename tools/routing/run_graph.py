"""Start and measure the pinned local pilot engine without changing Docker settings."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import time
from urllib.error import URLError
from urllib.request import urlopen

from prepare_graph import GRAPH, IMAGE, RAW, ROOT


NAME = "wayday-routing-pilot"
PORT = 18002
OUT = ROOT / "data/local/routing-evaluation"
ENV = {
    "server_threads": "2",
    "build_admins": "False",
    "build_time_zones": "True",
    "build_elevation": "False",
    "build_transit": "False",
    "use_default_speeds_config": "False",
    "build_tar": "True",
    "serve_tiles": "True",
}


def docker(*args: str, timeout: int = 30) -> str:
    return subprocess.check_output(["docker", *args], text=True, encoding="utf-8", stderr=subprocess.STDOUT, timeout=timeout).strip()


def main(max_seconds: int, named_volume: str | None = None, collect_existing: bool = False) -> None:
    if not (GRAPH / "pilot.osm.pbf").exists():
        raise FileNotFoundError("Run prepare_graph.py fetch and convert first")
    existing = docker("ps", "-a", "--filter", f"name=^/{NAME}$", "--format", "{{.ID}}")
    if existing and not collect_existing:
        raise RuntimeError(f"{NAME} already exists; inspect it explicitly rather than overwriting a container")
    if collect_existing and not existing:
        raise RuntimeError("No existing task-owned pilot container to measure")
    OUT.mkdir(parents=True, exist_ok=True)
    mount = named_volume if named_volume else str(GRAPH.resolve())
    args = ["run", "-d", "--name", NAME, "--cpus", "2", "--memory", "4g", "--memory-swap", "4g", "-p", f"127.0.0.1:{PORT}:8002", "-v", f"{mount}:/custom_files"]
    for key, value in ENV.items():
        args.extend(["-e", f"{key}={value}"])
    args.append(IMAGE)
    started = time.monotonic()
    container_id = existing if collect_existing else docker(*args)
    if collect_existing:
        state = json.loads(docker("inspect", "--format", "{{json .State}}", NAME))
        container_started = datetime.fromisoformat(state["StartedAt"].replace("Z", "+00:00"))
        started -= (datetime.now(timezone.utc) - container_started).total_seconds()
    print(f"Started {NAME}: {container_id}", flush=True)
    samples_path = OUT / "resource-samples.json"
    measurements = json.loads(samples_path.read_text(encoding="utf-8")) if collect_existing and samples_path.exists() else []
    status = None
    while collect_existing or time.monotonic() - started < max_seconds:
        state = json.loads(docker("inspect", "--format", "{{json .State}}", NAME))
        if not state["Running"]:
            (OUT / "build.log").write_text(docker("logs", NAME), encoding="utf-8")
            raise RuntimeError(f"Engine exited: {state}")
        measured = json.loads(docker("stats", "--no-stream", "--format", "{{json .}}", NAME))
        measured["elapsed_seconds"] = round(time.monotonic() - started, 3)
        measurements.append(measured)
        (OUT / "resource-samples.json").write_text(json.dumps(measurements, indent=2) + "\n", encoding="utf-8")
        try:
            with urlopen(f"http://127.0.0.1:{PORT}/status", timeout=2) as response:
                status = json.load(response)
            if status.get("tileset_last_modified") and "route" in status.get("available_actions", []):
                break
        except (URLError, TimeoutError, ConnectionError, json.JSONDecodeError):
            pass
        if collect_existing:
            raise RuntimeError("Existing engine is not ready")
        time.sleep(1)
    else:
        (OUT / "build.log").write_text(docker("logs", NAME), encoding="utf-8")
        raise TimeoutError(f"Engine not ready within {max_seconds} seconds; container retained for diagnosis")
    elapsed = round(time.monotonic() - started, 3)
    graph_bytes = int(docker("exec", NAME, "du", "-sb", "/custom_files").split()[0])
    image_info = json.loads(docker("image", "inspect", IMAGE))[0]
    source = json.loads((RAW / "manifest.json").read_text(encoding="utf-8"))
    config = docker("exec", NAME, "cat", "/custom_files/valhalla.json").encode()
    summary = {
        "measured_at_utc": datetime.now(timezone.utc).isoformat(),
        "image": IMAGE,
        "image_bytes": image_info["Size"],
        "container_id": container_id,
        "engine_status": status,
        "cpu_limit": 2,
        "memory_limit_bytes": 4 * 1024**3,
        "graph_mount": mount,
        "cgroup_memory_peak_bytes": int(docker("exec", NAME, "cat", "/sys/fs/cgroup/memory.peak")),
        "environment": ENV,
        "build_and_start_observed_upper_bound_seconds": elapsed,
        "readiness_note": "Collector observed readiness after startup; use build log timestamps for exact graph-stage durations",
        "graph_directory_bytes_including_pbf": graph_bytes,
        "source_sha256": source["raw_sha256"],
        "source_osm_base_timestamp": source["osm_base_timestamp"],
        "graph_config_sha256": hashlib.sha256(config).hexdigest(),
        "pbf_sha256": hashlib.sha256((GRAPH / "pilot.osm.pbf").read_bytes()).hexdigest(),
        "resource_samples": measurements,
        "limitations": ["Sampled container memory is not host/WSL peak memory", "Admin database disabled; pilot has no international border crossing", "No elevation or traffic feed", "Unknown/missing OSM restrictions remain unverified"],
    }
    (OUT / "build.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    (OUT / "build.log").write_text(docker("logs", NAME), encoding="utf-8")
    print(json.dumps({key: value for key, value in summary.items() if key != "resource_samples"}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--max-seconds", type=int, default=600)
    parser.add_argument("--named-volume", help="Existing task-owned Docker volume avoids Windows bind-mount I/O latency")
    parser.add_argument("--collect-existing", action="store_true", help="Collect final evidence from the existing task-owned container")
    args = parser.parse_args()
    main(args.max_seconds, args.named_volume, args.collect_existing)
