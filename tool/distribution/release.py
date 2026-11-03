"""Release configuration and manifests. Never reads the private .env.local file."""

import argparse
import hashlib
import json
import os
import time
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
REPOSITORY = "pu-roi/Wayday"
QUALIFICATION = ROOT / "docs/wayday/evidence/public-release-qualification.json"
PUBLIC_KEYS = (
    "WAYDAY_GATEWAY_URL",
    "GOOGLE_MAPS_ANDROID_API_KEY",
    "WAYDAY_FIREBASE_APP_ID",
    "WAYDAY_FIREBASE_API_KEY",
    "WAYDAY_FIREBASE_PROJECT_ID",
    "WAYDAY_RECAPTCHA_SITE_KEY",
)


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def build_number(run, attempt):
    if not 0 < run or not 0 < attempt < 100:
        raise ValueError("Invalid workflow sequence.")
    number = 100000 + run * 100 + attempt
    if number > 2100000000:
        raise ValueError("Android version-code space exhausted.")
    return number


def release_profile():
    profile = json.loads((ROOT / 'tool/distribution/release-profile.json').read_text())
    profile['contracts'] = {
        version: hashlib.sha256((ROOT / 'services/api/src/wayday_api/gateway' / filename).read_bytes()).hexdigest()
        for version, filename in [('d66-v1', 'contracts.json'), ('errand-v2', 'contracts-v2.json')]
    }
    return profile


def validate_gateway(health):
    profile = release_profile()
    if not isinstance(health, dict) or health.get('status') != 'configured' or health.get('providerCalls') is not False:
        raise ValueError('Gateway readiness is unavailable.')
    if any(health.get('contracts', {}).get(k) != v for k, v in profile['contracts'].items()):
        raise ValueError('Live gateway contracts do not match this client.')
    if any(health.get('capabilities', {}).get(k) != v for k, v in profile['capabilities'].items()):
        raise ValueError('Live gateway features do not match this release profile.')


def verify_gateway(url):
    uri = urlparse(url)
    if uri.scheme != 'https' or not uri.hostname or uri.username or uri.query or uri.fragment or uri.path not in ('', '/'):
        raise ValueError('Gateway must be an HTTPS origin.')
    # Cloud Run traffic/tag propagation can briefly return the previous revision.
    # These are bounded, read-only health checks; interpretation is never retried.
    for attempt in range(4):
        try:
            with urlopen(url.rstrip('/') + '/health', timeout=20) as response:
                validate_gateway(json.loads(response.read(20000)))
            return
        except (OSError, ValueError):
            if attempt == 3:
                raise
            time.sleep(3)


def public_defines(fixture=False, channel='public'):
    if channel not in ('public', 'test'):
        raise ValueError('Unknown release channel.')
    values = {key: os.environ.get(key, "").strip() for key in PUBLIC_KEYS}
    if channel == 'test':
        values['WAYDAY_GATEWAY_URL'] = os.environ.get('WAYDAY_TEST_GATEWAY_URL', '').strip()
        values['WAYDAY_FIREBASE_APP_ID'] = os.environ.get('WAYDAY_TEST_FIREBASE_APP_ID', '').strip()
    if not fixture:
        if not all(values.values()):
            raise ValueError("Required public build configuration is missing.")
        uri = urlparse(values["WAYDAY_GATEWAY_URL"])
        if (
            uri.scheme != "https"
            or not uri.hostname
            or uri.username
            or uri.query
            or uri.fragment
            or uri.path not in ("", "/")
        ):
            raise ValueError("Gateway must be an HTTPS origin.")
    return {
        "WAYDAY_PUBLIC_BUILD": "true", **values,
        **release_profile()['features'],
        **({'WAYDAY_PUBLIC_TEST': 'true'} if channel == 'test' else {}),
        'WAYDAY_SOURCE_COMMIT': os.environ.get('GITHUB_SHA', 'local'),
        'WAYDAY_RELEASE_CHANNEL': channel,
        'WAYDAY_RELEASE_PROFILE_SHA': config_fingerprint(release_profile()),
    }


def config_fingerprint(values):
    values = {key: value for key, value in values.items()
              if key not in ('WAYDAY_SOURCE_COMMIT', 'WAYDAY_RELEASE_CHANNEL')}
    return hashlib.sha256(
        json.dumps(values, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()


def certificate_normalized(value):
    return value.lower().replace(':', '')


def qualification(certificate):
    record = json.loads(QUALIFICATION.read_text(encoding="utf-8"))
    if record.get('releaseProfile') != release_profile():
        raise ValueError('Release profile has changed since physical qualification.')
    required = (
        "appCheckVerified",
        "freshInstallVerified",
        "upgradeVerified",
        "providerFlowVerified",
        "accountingReviewed",
    )
    if record.get("qualified") is not True or not all(
        record.get(key) is True for key in required
    ):
        raise ValueError(
            "Public release qualification is incomplete. Downloads remain disabled."
        )
    if not record.get("compatibility") or not record.get("evidence"):
        raise ValueError(
            "Release compatibility and verification evidence are required."
        )
    if record.get("signingSha256") != certificate.lower().replace(":", ""):
        raise ValueError("Release signing identity has not been qualified.")
    if record.get("configFingerprint") != config_fingerprint(public_defines()):
        raise ValueError("Public app configuration has not been qualified.")
    expected_channels = {
        channel: config_fingerprint(public_defines(channel=channel))
        for channel in ('public', 'test')
    }
    if record.get('channelConfigFingerprints') != expected_channels:
        raise ValueError('Both app channel configurations must be qualified.')
    contract = ROOT / "services/api/src/wayday_api/gateway/contracts.json"
    if (
        record.get("contractSha256")
        != hashlib.sha256(contract.read_bytes()).hexdigest()
    ):
        raise ValueError("Gateway contract has changed since qualification.")
    return record


def valid_manifest(value):
    if not isinstance(value, dict) or value.get("qualified") is not True:
        return False
    try:
        apk, notes = value["apkUrl"], value["notesUrl"]
        tag = value["tag"]
        prefix = f"https://github.com/{REPOSITORY}/releases/"
        return (
            apk == f"{prefix}download/{tag}/wayday.apk"
            and notes == f"{prefix}tag/{tag}"
            and type(value["versionCode"]) is int
            and value["versionCode"] > 0
            and type(value["sizeBytes"]) is int
            and value["sizeBytes"] > 0
            and len(value["sha256"]) == 64
            and all(c in "0123456789abcdef" for c in value["sha256"])
            and bool(value["compatibility"])
            and bool(value["version"])
            and datetime.fromisoformat(value["publishedAt"]).tzinfo is not None
        )
    except (KeyError, ValueError, TypeError):
        return False


def latest_release():
    # Public read only; never forward the Actions token to asset redirects.
    request = Request(
        f"https://api.github.com/repos/{REPOSITORY}/releases?per_page=100",
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "wayday-release",
        },
    )
    with urlopen(request, timeout=20) as response:
        releases = json.loads(response.read(2000000))
    candidates = []
    for release in releases:
        if release.get("draft"):
            continue
        for asset in release.get("assets", []):
            if asset.get("name") != "wayday-release.json":
                continue
            expected = f"https://github.com/{REPOSITORY}/releases/download/{release['tag_name']}/wayday-release.json"
            if asset.get("browser_download_url") != expected:
                continue
            with urlopen(expected, timeout=20) as response:
                data = json.loads(response.read(20000))
            if valid_manifest(data):
                candidates.append(data)
    return (
        max(candidates, key=lambda item: item["versionCode"])
        if candidates
        else {"qualified": False}
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "operation", choices=("defines", "number", "qualify", "manifest", "latest", "gateway")
    )
    parser.add_argument("--output")
    parser.add_argument("--fixture", action="store_true")
    parser.add_argument("--certificate", default="")
    parser.add_argument("--apk")
    parser.add_argument('--channel', choices=('public', 'test'), default='public')
    parser.add_argument('--url')
    parser.add_argument('--number', type=int)
    args = parser.parse_args()
    if args.operation == "defines":
        write(args.output, public_defines(args.fixture, args.channel))
    elif args.operation == 'gateway':
        verify_gateway(args.url)
    elif args.operation == "number":
        print(
            build_number(
                int(os.environ["GITHUB_RUN_NUMBER"]),
                int(os.environ["GITHUB_RUN_ATTEMPT"]),
            )
        )
    elif args.operation == "qualify":
        qualification(args.certificate)
    elif args.operation == "latest":
        write(args.output, latest_release())
    else:
        record = qualification(args.certificate)
        number = args.number or build_number(
            int(os.environ["GITHUB_RUN_NUMBER"]), int(os.environ["GITHUB_RUN_ATTEMPT"])
        )
        apk = Path(args.apk)
        tag = f"dev-{number}"
        artifact = 'wayday.apk' if args.channel == 'public' else 'wayday-test.apk'
        write(
            args.output,
            {
                "qualified": True,
                "tag": tag,
                "version": f"0.1.0+{number}",
                "versionCode": number,
                "publishedAt": datetime.now(UTC).isoformat(),
                "apkUrl": f"https://github.com/{REPOSITORY}/releases/download/{tag}/{artifact}",
                "notesUrl": f"https://github.com/{REPOSITORY}/releases/tag/{tag}",
                "sizeBytes": apk.stat().st_size,
                "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
                "compatibility": record["compatibility"],
                "commit": os.environ["GITHUB_SHA"],
                'channel': args.channel,
                'package': 'dev.wayday.wayday' + ('.publictest' if args.channel == 'test' else ''),
                'releaseProfile': release_profile(),
                'signingSha256': certificate_normalized(args.certificate),
            },
        )


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError):
        raise SystemExit(
            "Release preparation failed. Check configuration, qualification evidence and network availability; no private values are printed."
        ) from None
