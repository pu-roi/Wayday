"""Download a checksum-checked Metro Manila extract for the bounded importer."""
import hashlib
import json
import os
from pathlib import Path
import urllib.request

base = "https://download.openstreetmap.fr/extracts/asia/philippines/"
output = Path("data/downloads/metro_manila.osm.pbf")
output.parent.mkdir(parents=True, exist_ok=True)
with urllib.request.urlopen(base + "metro_manila.osm.pbf.md5", timeout=30) as response:
    checksum = response.read().decode().split()[0]
if not output.exists() or hashlib.md5(output.read_bytes()).hexdigest() != checksum:
    temporary = output.with_suffix(".download")
    with urllib.request.urlopen(base + "metro_manila.osm.pbf", timeout=45) as response, temporary.open("wb") as target:
        total = 0
        while block := response.read(1024 * 1024):
            total += len(block)
            if total > 150 * 1024 * 1024:
                raise ValueError("Unexpected extract size; preserve previous import")
            target.write(block)
    if hashlib.md5(temporary.read_bytes()).hexdigest() != checksum:
        raise ValueError("Extract checksum mismatch; retry the dated download")
    os.replace(temporary, output)
with urllib.request.urlopen(base + "metro_manila.state.txt", timeout=30) as response:
    state = response.read().decode()
output.with_suffix(".json").write_text(json.dumps({"md5": checksum, "source_url": base + "metro_manila.osm.pbf", "state": state}), encoding="utf-8")
print(f"Verified {output.stat().st_size} bytes from OSM France")
