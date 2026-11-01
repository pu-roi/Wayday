import json
import struct
import zipfile

import pytest
from check_navigation_reflection import LOADER, REGISTRY, verify
from release import build_number, public_defines, valid_manifest


def test_version_codes_increase_for_pushes_and_reruns():
    assert build_number(1, 1) < build_number(1, 2) < build_number(2, 1)
    with pytest.raises(ValueError):
        build_number(1, 100)
    with pytest.raises(ValueError):
        build_number(22000000, 1)


def test_fixture_never_includes_private_provider_keys(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "must-not-compile")
    monkeypatch.setenv("GOOGLE_ROUTES_API_KEY", "must-not-compile")
    assert "must-not-compile" not in str(public_defines(fixture=True))


def test_incomplete_release_is_not_qualified():
    assert not valid_manifest({})
    assert not valid_manifest({"qualified": True, "apkUrl": "javascript:alert(1)"})


def navigation_artifact(
    tmp_path,
    loader,
    registry,
    registry_flags=16,
    *,
    marker="fixture",
    include_registry=True,
):
    # Minimal synthetic DEX class tables: no Google bytecode or provider calls.
    classes = [(loader, 1)] + ([(registry, registry_flags)] if include_registry else [])
    count = len(classes)
    string_offset, type_offset, class_offset = 112, 112 + count * 4, 112 + count * 8
    data = bytearray(class_offset + count * 32)
    data[:8] = b"dex\n035\0"
    for offset, value in [
        (56, count),
        (60, string_offset),
        (64, count),
        (68, type_offset),
        (96, count),
        (100, class_offset),
    ]:
        struct.pack_into("<I", data, offset, value)
    for index, (name, flags) in enumerate(classes):
        descriptor = ("L" + name.replace(".", "/") + ";").encode()
        assert len(descriptor) < 128
        struct.pack_into("<I", data, string_offset + index * 4, len(data))
        struct.pack_into("<I", data, type_offset + index * 4, index)
        struct.pack_into("<II", data, class_offset + index * 32, index, flags)
        data.extend(bytes([len(descriptor)]) + descriptor + b"\0")
    data.extend(b"~~R8" + json.dumps({"pg-map-id": marker}).encode() + b"\0")
    apk, mapping = tmp_path / "fixture.apk", tmp_path / "mapping.txt"
    with zipfile.ZipFile(apk, "w") as archive:
        archive.writestr("classes.dex", data)
    mapping.write_text(
        f"# pg_map_id: fixture\n{LOADER} -> {loader}:\n{REGISTRY} -> {registry}:\n"
    )
    return apk, mapping


def test_minified_sdk_loader_cannot_access_private_registry_after_repackaging(tmp_path):
    apk, mapping = navigation_artifact(tmp_path, "gt5", REGISTRY)
    with pytest.raises(ValueError, match="IllegalAccessException"):
        verify(apk, mapping)


@pytest.mark.parametrize(
    "loader,registry,flags",
    [
        (LOADER, REGISTRY, 16),
        ("com.google.android.libraries.navigation.internal.alt.a", REGISTRY, 16),
        ("gt5", REGISTRY, 17),
    ],
)
def test_minified_reflection_preserves_java_access_rules(
    tmp_path, loader, registry, flags
):
    assert (
        verify(*navigation_artifact(tmp_path, loader, registry, flags))[
            "navigationReflectionAccess"
        ]
        == "passed"
    )


def test_reflection_check_rejects_mapping_from_a_different_apk(tmp_path):
    with pytest.raises(ValueError, match="mapping does not match"):
        verify(*navigation_artifact(tmp_path, LOADER, REGISTRY, marker="other-build"))


def test_reflection_check_rejects_a_removed_registry(tmp_path):
    with pytest.raises(ValueError, match="missing from the APK"):
        verify(*navigation_artifact(tmp_path, LOADER, REGISTRY, include_registry=False))
