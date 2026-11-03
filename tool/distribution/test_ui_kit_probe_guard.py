"""Probe authorization guards must fail before ADB or Flutter can be invoked."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize(
    ("device", "explicit"),
    [("emulator-5556", False), ("physical-phone-fixture", True), ("physical-phone-fixture", False)],
)
def test_live_probe_requires_explicit_opt_in_and_an_emulator(device, explicit):
    powershell = shutil.which("pwsh")
    assert powershell, "PowerShell is required for the Windows runner checks."
    args = [
        powershell, "-NoProfile", "-File", str(ROOT / "apps/mobile/tool/test-map.ps1"),
        "-DeviceId", device, "-Target", "integration_test/trip_place_ui_kit_probe_test.dart",
    ]
    if explicit:
        args.append("-UiKitIdProbe")
    # No ADB or Flutter is available through this test's environment.
    environment = {
        **os.environ,
        "PATH": str(Path(powershell).parent),
        "LOCALAPPDATA": str(ROOT / ".tools/no-android-sdk-guard-fixture"),
    }
    result = subprocess.run(args, env=environment, capture_output=True, text=True, timeout=30)
    assert result.returncode != 0
    assert "single UI Kit ID probe requires explicit" in result.stderr
    assert not (ROOT / ".tools/no-android-sdk-guard-fixture").exists()
