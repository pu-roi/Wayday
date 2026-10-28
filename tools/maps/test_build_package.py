"""Offline failure tests; fixture bytes do not stand in for real map evidence."""

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from build_package import FONT, inventory, publish, validate_package, validate_style


def fixture_package(directory: Path) -> None:
    names = ["pilot.pmtiles", "style.json", "sprites/light.json", "sprites/light.png", "sprites/light@2x.json", "sprites/light@2x.png", "notices/NOTICES.txt", "notices/Noto-OFL.txt", "notices/Tangram-Icons-MIT.txt"]
    names += [f"fonts/{FONT}/{start}-{start + 255}.pbf" for start in range(0, 65536, 256)]
    for name in names:
        target = directory / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(b"synthetic-resource")
    (directory / "manifest.json").write_text(json.dumps({"formatVersion": 1, "files": inventory(directory)}), encoding="utf-8")


class PackageFailureTests(unittest.TestCase):
    def test_corrupt_archive_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            fixture_package(root)
            (root / "pilot.pmtiles").write_bytes(b"corrupted-resource")
            with self.assertRaisesRegex(ValueError, "corrupt"):
                validate_package(root)

    def test_missing_glyph_prevents_replacement_of_prior_package(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            old = root / "pilot"
            staging = root / "pilot.staging-test"
            fixture_package(old)
            shutil.copytree(old, staging)
            before = (old / "manifest.json").read_bytes()
            (staging / f"fonts/{FONT}/0-255.pbf").unlink()
            with self.assertRaisesRegex(ValueError, "Missing"):
                publish(staging, old)
            self.assertEqual((old / "manifest.json").read_bytes(), before)
            self.assertTrue((old / f"fonts/{FONT}/0-255.pbf").exists())

    def test_manifest_path_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            fixture_package(root)
            path = root / "manifest.json"
            manifest = json.loads(path.read_text())
            manifest["files"][0]["path"] = "../outside"
            path.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, "Unsafe"):
                validate_package(root)

    def test_publish_preserves_nested_repository_markers(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            old = root / "pilot"
            staging = root / "pilot.staging-test"
            fixture_package(old)
            fixture_package(staging)
            for name in [".gitkeep", f"fonts/{FONT}/.gitkeep", "sprites/.gitkeep", "notices/.gitkeep"]:
                (old / name).touch()
            publish(staging, old)
            self.assertTrue((old / ".gitkeep").exists())
            self.assertTrue((old / f"fonts/{FONT}/.gitkeep").exists())
            self.assertTrue((old / "sprites/.gitkeep").exists())
            self.assertTrue((old / "notices/.gitkeep").exists())
            validate_package(old)

    def test_network_resource_fallback_is_rejected(self):
        style = json.loads((Path(__file__).parent / "wayday-pilot-style.json").read_text())
        ids = {layer["source-layer"] for layer in style["layers"] if "source-layer" in layer}
        validate_style(style, ids)
        style["glyphs"] = "https://example.invalid/fonts/{fontstack}/{range}.pbf"
        with self.assertRaisesRegex(ValueError, "local"):
            validate_style(style, ids)


if __name__ == "__main__":
    unittest.main()
