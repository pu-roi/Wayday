import pytest
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
