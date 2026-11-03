"""Configuration-only checks. Never signs, builds, installs or calls providers."""

import json
import shutil
import subprocess
import uuid
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "apps/mobile/tool/build-navigation-test.ps1"


@pytest.fixture
def configuration():
    directory = ROOT / ".tools" / "navigation-phone-tool-tests" / str(uuid.uuid4())
    directory.mkdir(parents=True)
    values = {
        "WAYDAY_PUBLIC_BUILD": "true",
        "WAYDAY_GATEWAY_URL": "https://example.invalid",
        "GOOGLE_MAPS_ANDROID_API_KEY": "fixture-restricted-native-key",
        "WAYDAY_FIREBASE_APP_ID": "1:793890374960:android:dbe21167436a082af974f5",
        "WAYDAY_FIREBASE_API_KEY": "fixture-public-id",
        "WAYDAY_FIREBASE_PROJECT_ID": "wayday-513016",
        "WAYDAY_RECAPTCHA_SITE_KEY": "fixture-site",
    }
    return directory, values


def prepare(directory, values, *, gateway="https://navigation-test.example.invalid"):
    source = directory / "input.json"
    source.write_text(json.dumps(values), encoding="utf-8")
    output = directory / "output"
    powershell = shutil.which("pwsh")
    assert powershell, "PowerShell is required to verify the Windows build helper."
    result = subprocess.run([
        powershell, "-NoProfile", "-File", str(SCRIPT), "-PrepareOnly",
        "-TestGatewayUrl", gateway, "-PublicConfiguration", str(source),
        "-OutputDirectory", str(output),
    ], capture_output=True, text=True, timeout=30)
    return result, output


def test_test_identity_and_feature_flags_are_prepared_without_a_build(configuration):
    result, output = prepare(*configuration)
    assert result.returncode == 0, result.stderr
    values = json.loads((output / "public-defines.json").read_text(encoding="utf-8"))
    assert values["WAYDAY_PUBLIC_TEST"] == "true"
    assert values["WAYDAY_ALTERNATIVE_NAVIGATION"] == "true"
    assert values["WAYDAY_UI_KIT_NAVIGATION_TARGETS"] == "true"
    assert values["WAYDAY_FIREBASE_APP_ID"].endswith("dbe21167436a082af974f5")
    assert "fixture-restricted-native-key" not in result.stdout + result.stderr
    assert list(output.iterdir()) == [output / "public-defines.json"]


@pytest.mark.parametrize("case", ["private_key", "production_identity", "production_gateway", "http"])
def test_invalid_or_production_configuration_is_rejected_before_output(configuration, case):
    directory, values = configuration
    gateway = "https://navigation-test.example.invalid"
    if case == "private_key":
        values["GEOAPIFY_API_KEY"] = "private-fixture-must-not-escape"
    if case == "production_identity":
        values["WAYDAY_FIREBASE_APP_ID"] = "1:793890374960:android:71923e4f8600629cf974f5"
    if case == "production_gateway":
        gateway = "https://wayday-gateway-793890374960.asia-southeast1.run.app"
    if case == "http":
        gateway = "http://example.invalid"
    result, output = prepare(directory, values, gateway=gateway)
    assert result.returncode != 0
    assert not output.exists()
    assert "private-fixture-must-not-escape" not in result.stdout + result.stderr


def test_android_studio_configuration_uses_only_the_prebuilt_release_binary(configuration):
    from xml.etree import ElementTree

    directory, _ = configuration
    binary = directory / "wayday-navigation-test.apk"
    result = subprocess.run([
        shutil.which("pwsh"), "-NoProfile", "-File",
        str(ROOT / "apps/mobile/tool/configure-navigation-test-ide.ps1"),
        "-ProjectDirectory", str(directory),
        "-ApplicationBinary", str(binary),
    ], capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stderr
    tree = ElementTree.parse(directory / ".idea/runConfigurations/Wayday_Test.xml")
    config = tree.find("configuration")
    assert config.attrib["name"] == "Wayday Test"
    options = {o.attrib["name"]: o.attrib["value"] for o in config.findall("option")}
    assert "--release --no-pub --use-application-binary=" in options["additionalArgs"]
    assert "wayday-navigation-test.apk" in options["additionalArgs"]
    assert binary.as_posix() in options["additionalArgs"]
    assert "search-defines" not in options["additionalArgs"]
    assert "dart-define" not in options["additionalArgs"]
    assert not list(directory.glob("*.apk"))
