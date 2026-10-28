from pathlib import Path
import os
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from wayday_api.places.postgis import import_snapshot

if __name__ == "__main__":
    import_snapshot(os.environ["WAYDAY_DATABASE_URL"], Path("data/generated/pasig-places.json"))
    print("Imported the validated pilot snapshot into PostGIS.")
