"""Build the bounded Wayday pilot map from pinned, cached public resources.

Run from any directory. Downloads and generated packages stay ignored. The
publisher stages and verifies a complete package before replacing the prior one;
this is development tooling, not the later in-app package update installer.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import ctypes
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import time
from urllib.parse import quote
from urllib.request import Request, urlopen
import uuid


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
CACHE = ROOT / "data/downloads/maps"
GENERATED = ROOT / "data/generated/maps"
APP_PACKAGE = ROOT / "apps/mobile/assets/maps/pilot"
ASSETS_COMMIT = "028c18f713baecad011301ff7a69acc39bcc2ae7"
ICONS_COMMIT = "92510779634f4a006c61ea70e50cb8c52c765a81"
SOURCE = "https://build.protomaps.com/20261026.pmtiles"
ARCHIVE = CACHE / "pilot-20261026-z15.pmtiles"
BOUNDS = [121.045, 14.548, 121.116, 14.617]
FONT = "Noto Sans Regular"
USER_AGENT = "WaydayMapPackage/0.1 (+https://github.com/pu-roi/Wayday)"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def peak_working_set() -> int | None:
    if os.name != "nt":
        return None
    from ctypes import wintypes

    class Counters(ctypes.Structure):
        _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD)] + [
            (name, ctypes.c_size_t) for name in (
                "PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage",
                "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage", "QuotaNonPagedPoolUsage",
                "PagefileUsage", "PeakPagefileUsage",
            )
        ]

    counters = Counters()
    counters.cb = ctypes.sizeof(counters)
    current = ctypes.windll.kernel32.GetCurrentProcess
    current.restype = wintypes.HANDLE
    function = ctypes.windll.psapi.GetProcessMemoryInfo
    function.argtypes = [wintypes.HANDLE, ctypes.POINTER(Counters), wintypes.DWORD]
    if function(current(), ctypes.byref(counters), counters.cb):
        return counters.PeakWorkingSetSize
    return None


def download(url: str) -> bytes:
    with urlopen(Request(url, headers={"User-Agent": USER_AGENT}), timeout=45) as response:
        return response.read()


def git_blob_sha(body: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(body)).encode() + b"\0" + body).hexdigest()


def asset_tree() -> dict:
    target = CACHE / "assets-tree.json"
    if not target.exists():
        body = download(f"https://api.github.com/repos/protomaps/basemaps-assets/git/trees/{ASSETS_COMMIT}?recursive=1")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(body)
    tree = json.loads(target.read_text(encoding="utf-8"))
    if tree["sha"] != ASSETS_COMMIT or tree.get("truncated"):
        raise ValueError("Asset tree does not match the pinned complete source tree")
    return tree


def fetch_assets() -> list[dict]:
    tree = asset_tree()
    selected = [entry for entry in tree["tree"] if (
        entry["path"].startswith(f"fonts/{FONT}/")
        or entry["path"] in {"fonts/OFL.txt", "scripts/LICENSE.md", "README.md"}
        or entry["path"] in {f"sprites/v4/light{suffix}" for suffix in (".json", ".png", "@2x.json", "@2x.png")}
    )]
    if sum(entry["path"].startswith(f"fonts/{FONT}/") for entry in selected) != 256:
        raise ValueError("Pinned fontstack is not the expected 256 glyph ranges")

    def get(entry: dict) -> None:
        path = entry["path"]
        target = CACHE / "assets" / path
        if target.exists() and git_blob_sha(target.read_bytes()) == entry["sha"]:
            return
        url = f"https://raw.githubusercontent.com/protomaps/basemaps-assets/{ASSETS_COMMIT}/{quote(path)}"
        for attempt in range(2):
            try:
                body = download(url)
                if len(body) != entry["size"] or git_blob_sha(body) != entry["sha"]:
                    raise ValueError(f"Source asset hash mismatch: {path}")
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(body)
                return
            except Exception:
                if attempt:
                    raise
                time.sleep(1)

    with ThreadPoolExecutor(max_workers=4) as executor:
        list(executor.map(get, selected))
    print(f"Verified {len(selected)} pinned font/sprite/provenance files", flush=True)
    return selected


def run_cli(cli: Path, arguments: list[str]) -> str:
    result = subprocess.run([str(cli), *arguments], capture_output=True, check=True)
    return result.stdout.decode("utf-8") + result.stderr.decode("utf-8")


def prepare_archive(cli: Path) -> tuple[dict, dict, str]:
    log = "Reused cached regional archive; no tile download performed."
    if not ARCHIVE.exists():
        temporary = ARCHIVE.with_suffix(".partial.pmtiles")
        log = run_cli(cli, ["extract", SOURCE, str(temporary), "--bbox=" + ",".join(map(str, BOUNDS)), "--minzoom=0", "--maxzoom=15", "--download-threads=4"])
        run_cli(cli, ["verify", str(temporary)])
        temporary.replace(ARCHIVE)
    verification = run_cli(cli, ["verify", str(ARCHIVE)])
    header = json.loads(run_cli(cli, ["show", str(ARCHIVE), "--header-json"]))
    metadata = json.loads(run_cli(cli, ["show", str(ARCHIVE), "--metadata"]))
    if header.get("bounds") != BOUNDS or header.get("minzoom") != 0 or header.get("maxzoom") != 15:
        raise ValueError("Archive coverage/zooms differ from the agreed pilot")
    if header.get("tile_type") != "mvt" or metadata.get("version") != "4.15.2":
        raise ValueError("Archive is not the selected Protomaps v4.15.2 vector schema")
    return header, metadata, log + "\n" + verification


def validate_style(style: dict, layer_ids: set[str]) -> None:
    if style.get("version") != 8:
        raise ValueError("Unsupported map style")
    if style.get("glyphs") != "__PACKAGE_ROOT__/fonts/{fontstack}/{range}.pbf" or style.get("sprite") != "__PACKAGE_ROOT__/sprites/light":
        raise ValueError("Font and sprite resources must be local to the package")
    sources = style.get("sources", {})
    if set(sources) != {"protomaps"} or sources["protomaps"].get("url") != "pmtiles://__PACKAGE_ROOT__/pilot.pmtiles":
        raise ValueError("Only the local pilot archive may supply map geography")
    for layer in style["layers"]:
        if "source-layer" in layer and layer["source-layer"] not in layer_ids:
            raise ValueError(f"Style uses absent vector layer: {layer['source-layer']}")
        fonts = layer.get("layout", {}).get("text-font")
        if fonts is not None and fonts != [FONT]:
            raise ValueError("Style refers to an unbundled fontstack")


def inventory(directory: Path) -> list[dict]:
    return [{"path": path.relative_to(directory).as_posix(), "bytes": path.stat().st_size, "sha256": sha256(path)}
            for path in sorted(directory.rglob("*")) if path.is_file() and path.name not in {"manifest.json", ".gitkeep"}]


def validate_package(directory: Path) -> dict:
    manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("formatVersion") != 1:
        raise ValueError("Unsupported package manifest")
    entries = manifest["files"]
    paths = [entry["path"] for entry in entries]
    if len(paths) != len(set(paths)):
        raise ValueError("Duplicate package file")
    for entry in entries:
        path = PurePosixPath(entry["path"])
        if path.is_absolute() or ".." in path.parts or "\\" in entry["path"] or ":" in entry["path"]:
            raise ValueError("Unsafe package path")
        target = directory / path
        if not target.resolve().is_relative_to(directory.resolve()):
            raise ValueError("Package file escapes its directory")
        if not target.is_file() or target.stat().st_size != entry["bytes"] or sha256(target) != entry["sha256"]:
            raise ValueError(f"Missing/corrupt package file: {path}")
    expected = {"pilot.pmtiles", "style.json", "sprites/light.json", "sprites/light.png", "sprites/light@2x.json", "sprites/light@2x.png", "notices/NOTICES.txt", "notices/Noto-OFL.txt", "notices/Tangram-Icons-MIT.txt"}
    expected.update(f"fonts/{FONT}/{start}-{start + 255}.pbf" for start in range(0, 65536, 256))
    if not expected.issubset(paths) or set(paths) != {item["path"] for item in inventory(directory)}:
        raise ValueError("Package inventory is incomplete")
    return manifest


def remove_owned(directory: Path, parent: Path) -> None:
    if directory.resolve().parent != parent.resolve() or not directory.name.startswith("pilot."):
        raise ValueError("Refusing cleanup outside the explicit package workspace")
    if directory.exists():
        shutil.rmtree(directory)


def publish(staging: Path, destination: Path) -> None:
    if staging.resolve().parent != destination.resolve().parent or not staging.name.startswith("pilot.staging-") or destination.name != "pilot":
        raise ValueError("Package staging must be adjacent to its explicit pilot destination")
    validate_package(staging)
    backup = destination.with_name("pilot.previous-" + uuid.uuid4().hex)
    if destination.exists():
        for marker in destination.rglob(".gitkeep"):
            target = staging / marker.relative_to(destination)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(marker, target)
    if destination.exists():
        destination.rename(backup)
    try:
        staging.rename(destination)
    except Exception:
        if backup.exists():
            backup.rename(destination)
        raise
    remove_owned(backup, destination.parent)


def build(cli: Path, copy_to_app: bool) -> None:
    started = time.perf_counter()
    CACHE.mkdir(parents=True, exist_ok=True)
    GENERATED.mkdir(parents=True, exist_ok=True)
    entries = fetch_assets()
    header, metadata, archive_log = prepare_archive(cli)
    staging = GENERATED / ("pilot.staging-" + uuid.uuid4().hex)
    staging.mkdir()
    try:
        for entry in entries:
            source = CACHE / "assets" / entry["path"]
            path = entry["path"]
            if path.startswith("fonts/" + FONT + "/"):
                target = staging / path
            elif path.startswith("sprites/v4/"):
                target = staging / "sprites" / source.name
            else:
                name = {"fonts/OFL.txt": "Noto-OFL.txt", "scripts/LICENSE.md": "Protomaps-Scripts-BSD.txt", "README.md": "Upstream-Assets-README.md"}[path]
                target = staging / "notices" / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        icon_license = CACHE / "tangram-icons-MIT.txt"
        if not icon_license.exists():
            icon_license.write_bytes(download(f"https://raw.githubusercontent.com/tangrams/icons/{ICONS_COMMIT}/LICENSE.md"))
        shutil.copy2(icon_license, staging / "notices/Tangram-Icons-MIT.txt")
        shutil.copy2(HERE / "package-notices.txt", staging / "notices/NOTICES.txt")
        shutil.copy2(ARCHIVE, staging / "pilot.pmtiles")
        style = json.loads((HERE / "wayday-pilot-style.json").read_text(encoding="utf-8"))
        validate_style(style, {layer["id"] for layer in metadata["vector_layers"]})
        (staging / "style.json").write_text(json.dumps(style, indent=2) + "\n", encoding="utf-8")
        (staging / "source-metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
        manifest = {
            "formatVersion": 1, "id": "pasig-ortigas-20261026-z15-v1", "region": "Pasig / Ortigas pilot",
            "boundsWestSouthEastNorth": BOUNDS, "minZoom": 0, "maxZoom": 15,
            "sourceDate": "2026-10-26", "sourceSnapshot": metadata.get("planetiler:osm:osmosisreplicationtime"),
            "styleFile": "style.json", "archiveFile": "pilot.pmtiles", "tileSchema": "Protomaps 4.15.2",
            "assetsCommit": ASSETS_COMMIT, "attribution": "© OpenStreetMap contributors · Protomaps",
            "files": inventory(staging),
        }
        (staging / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        publish(staging, GENERATED / "pilot")
        if copy_to_app:
            APP_PACKAGE.parent.mkdir(parents=True, exist_ok=True)
            app_staging = APP_PACKAGE.with_name("pilot.staging-" + uuid.uuid4().hex)
            shutil.copytree(GENERATED / "pilot", app_staging)
            publish(app_staging, APP_PACKAGE)
        metrics = {
            "preparedAtUtc": datetime.now(timezone.utc).isoformat(), "elapsedSeconds": round(time.perf_counter() - started, 3),
            "fileCount": len(manifest["files"]), "payloadBytes": sum(entry["bytes"] for entry in manifest["files"]),
            "manifestBytes": (GENERATED / "pilot/manifest.json").stat().st_size,
            "archiveBytes": ARCHIVE.stat().st_size, "archiveSha256": sha256(ARCHIVE),
            "manifestSha256": sha256(GENERATED / "pilot/manifest.json"),
            "archiveHeader": header, "archivePreparationLog": archive_log,
            "downloadThreads": 4, "assetFilesVerified": len(entries),
            "pythonCpuSeconds": round(time.process_time(), 3), "pythonPeakWorkingSetBytes": peak_working_set(),
            "resourceMeasurementScope": "This Python package-preparation process; excludes earlier CLI extraction and native rendering",
            "nativeAssetProtocolStatus": "Unverified until M3-03 Android rendering/offline checks",
        }
        (GENERATED / "build-metrics.json").write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(metrics, indent=2), flush=True)
    finally:
        remove_owned(staging, GENERATED)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pmtiles", type=Path, default=ROOT / ".tools/pmtiles/pmtiles.exe")
    parser.add_argument("--copy-to-app", action="store_true")
    parser.add_argument("--assets-only", action="store_true")
    args = parser.parse_args()
    CACHE.mkdir(parents=True, exist_ok=True)
    if args.assets_only:
        fetch_assets()
    else:
        build(args.pmtiles.resolve(), args.copy_to_app)


if __name__ == "__main__":
    main()
