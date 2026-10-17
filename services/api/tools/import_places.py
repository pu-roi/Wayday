"""Generate a bounded OSM read model; no public geocoder/Overpass calls.

Run from the repository root with the API virtual environment. The downloaded
PBF, metadata and generated catalog belong to ignored data/ directories.
"""
import argparse
from dataclasses import asdict
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import osmium
from shapely import from_wkb
from shapely.geometry import mapping
from shapely.errors import ShapelyError
from wayday_api.places.catalog import BOUNDS, Place, inside


def category_for(tags):
    return next((tags[k] for k in ("shop", "amenity", "office", "tourism", "leisure", "healthcare", "building") if tags.get(k)), None) or ('residential' if tags.get('landuse') == 'residential' else tags.get('place'))


def record(source_id, tags, lat, lon, source_date, kind):
    name = tags.get("name") or tags.get("name:en")
    category = category_for(tags)
    if not name or not category or not inside(lat, lon):
        return None
    aliases = {tags.get(k, "") for k in ("name:en", "name:tl", "official_name", "short_name", "alt_name", "brand")}
    # Search aliases, not interpretation: derive initials from the mapped name.
    words = [w for w in name.split() if w.casefold() not in {"ng", "sa", "the", "of", "and", "ang"}]
    if len(words) >= 3:
        aliases.add("".join(w[0] for w in words if w[0].isalpha()))
    aliases = tuple(sorted(a for raw in aliases for a in raw.split(";") if a and a != name))
    address = tags.get("addr:full") or ", ".join(filter(None, [" ".join(filter(None, [tags.get("addr:housenumber"), tags.get("addr:street")])), tags.get("addr:suburb"), tags.get("addr:city")])) or None
    return Place(source_id, name, address, lat, lon, category, aliases, tags.get("opening_hours"), source_date, kind)


class Importer(osmium.SimpleHandler):
    def __init__(self, source_date):
        super().__init__()
        self.source_date, self.places = source_date, {}
        self.factory = osmium.geom.WKBFactory()

    def add(self, source_id, tags, lat, lon, kind, footprint=None):
        place = record(source_id, tags, lat, lon, self.source_date, kind)
        if place:
            self.places[place.id] = {**asdict(place), 'footprint': footprint}

    def node(self, node):
        if node.location.valid():
            self.add(f"osm/node/{node.id}", node.tags, node.location.lat, node.location.lon, "mapped_point")

    def area(self, area):
        # Polygon representative points are not business entrances.
        if not area.tags.get("name") or not category_for(area.tags):
            return
        try:
            geometry = from_wkb(bytes.fromhex(self.factory.create_multipolygon(area)))
            if geometry.is_empty or not geometry.is_valid:
                return
            point = geometry.representative_point()
            kind = "way" if area.from_way() else "relation"
            self.add(f"osm/{kind}/{area.orig_id()}", area.tags, point.y, point.x, "area_representative_point", mapping(geometry))
        except (RuntimeError, ValueError, ShapelyError):
            # Missing/invalid source geometry is omitted, never guessed.
            return


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("pbf", type=Path)
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("data/generated/pasig-places.json"))
    args = parser.parse_args()
    meta = json.loads(args.metadata.read_text(encoding="utf-8"))
    digest = hashlib.md5(args.pbf.read_bytes()).hexdigest()
    if digest != meta["md5"]:
        raise ValueError("Extract checksum does not match its metadata")
    source_date = next(line.split("=", 1)[1].replace("\\:", ":") for line in meta["state"].splitlines() if line.startswith("timestamp="))
    with osmium.io.Reader(str(args.pbf)) as reader:
        source_date = reader.header().get("osmosis_replication_timestamp") or source_date
    datetime.fromisoformat(source_date.replace("Z", "+00:00"))
    handler = Importer(source_date)
    handler.apply_file(str(args.pbf), locations=True, idx="flex_mem")
    if not handler.places or len(handler.places) > 20000:
        raise ValueError("Unexpected catalog size; preserve previous import")
    result = {"bounds": BOUNDS, "source_date": source_date, "source_url": meta["source_url"], "md5": digest, "imported_at": datetime.now(timezone.utc).isoformat(), "places": sorted(handler.places.values(), key=lambda p: p["id"])}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix(".tmp")
    temporary.write_text(json.dumps(result, ensure_ascii=False), encoding="utf-8")
    os.replace(temporary, args.output)
    print(f"Imported {len(handler.places)} source-backed places into {args.output}")


if __name__ == "__main__":
    main()
