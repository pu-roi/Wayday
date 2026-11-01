"""Check the minified Navigation 7.9.0 reflection boundary without provider calls.

Its package-private generated registry must be accessible to the reflective
loader after R8. Revalidate these internal names when upgrading the pinned SDK.
"""

import argparse
import json
import re
import struct
import zipfile
from pathlib import Path

LOADER = "com.google.android.libraries.navigation.internal.alt.ax"
REGISTRY = "com.google.android.libraries.navigation.internal.alt.k"


def dex_classes(data):
    if len(data) < 112 or data[:4] != b"dex\n":
        raise ValueError("Expected an Android DEX file.")

    def uint(offset):
        return struct.unpack_from("<I", data, offset)[0]

    def string(index):
        offset = uint(uint(60) + 4 * index)
        for _ in range(5):
            byte = data[offset]
            offset += 1
            if byte < 128:
                break
        else:
            raise ValueError("Invalid DEX string length.")
        return data[offset : data.index(0, offset)].decode("ascii")

    count, offset = uint(96), uint(100)
    for index in range(count):
        entry = offset + index * 32
        descriptor = string(uint(uint(68) + 4 * uint(entry)))
        yield descriptor[1:-1].replace("/", "."), uint(entry + 4)


def verify(apk, mapping):
    text = Path(mapping).read_text(encoding="utf-8")
    names = dict(re.findall(r"^(\S+) -> (\S+):$", text, re.MULTILINE))
    match = re.search(r"^# pg_map_id: (\S+)$", text, re.MULTILINE)
    if not match or not {LOADER, REGISTRY} <= names.keys():
        raise ValueError("Missing pinned SDK classes or R8 mapping identity.")
    selected = {}
    with zipfile.ZipFile(apk) as archive:
        for name in archive.namelist():
            if not re.fullmatch(r"classes\d*\.dex", name):
                continue
            data = archive.read(name)
            for class_name, flags in dex_classes(data):
                if class_name not in (names[LOADER], names[REGISTRY]):
                    continue
                markers = re.findall(rb"~~R8(\{[^\x00]+\})", data)
                if not any(json.loads(m).get("pg-map-id") == match[1] for m in markers):
                    raise ValueError("R8 mapping does not match the APK's SDK classes.")
                selected[class_name] = flags
    if set(selected) != {names[LOADER], names[REGISTRY]}:
        raise ValueError("Reflected SDK classes are missing from the APK.")
    same_package = (
        names[LOADER].rpartition(".")[0] == names[REGISTRY].rpartition(".")[0]
    )
    if not same_package and not selected[names[REGISTRY]] & 1:
        raise ValueError(
            "R8 moved the loader away from its package-private registry: IllegalAccessException risk."
        )
    return {"navigationReflectionAccess": "passed", "mappingId": match[1]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", required=True)
    parser.add_argument("--mapping", required=True)
    arguments = parser.parse_args()
    try:
        print(json.dumps(verify(arguments.apk, arguments.mapping)))
    except (ValueError, OSError, KeyError, IndexError, struct.error) as error:
        parser.exit(1, f"Navigation release verification failed: {error}\n")
