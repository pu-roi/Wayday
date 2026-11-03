"""Update only the ignored Android Studio APK alias. Never operate a phone."""
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
from tempfile import TemporaryDirectory
from urllib.request import Request, urlopen

from release import ROOT, REPOSITORY, QUALIFICATION, release_profile, write
from verify_apk import command, verify


def validate_manifest(data):
    tag = data.get('tag', '')
    url = f'https://github.com/{REPOSITORY}/releases/download/{tag}/wayday-test.apk'
    certificate = json.loads(QUALIFICATION.read_text())['signingSha256']
    approved = data.get('qualified') is True or (
        data.get('qualified') is False and data.get('previewApproved') is True
        and data.get('verificationStatus') == 'official-phone-pending')
    if (not approved or data.get('channel') != 'test'
            or data.get('package') != 'dev.wayday.wayday.publictest'
            or data.get('apkUrl') != url or not re.fullmatch(r'dev-[0-9]+', tag)
            or not re.fullmatch(r'[0-9a-f]{40}', data.get('commit', ''))
            or data.get('releaseProfile') != release_profile()
            or data.get('signingSha256') != certificate
            or type(data.get('versionCode')) is not int or data['versionCode'] < 1
            or type(data.get('sizeBytes')) is not int or not 0 < data['sizeBytes'] < 512000000
            or len(data.get('sha256', '')) != 64
            or any(c not in '0123456789abcdef' for c in data['sha256'])):
        raise ValueError('Published test release is unqualified or incompatible.')


def latest():
    req = Request(f'https://api.github.com/repos/{REPOSITORY}/releases?per_page=100', headers={'User-Agent': 'wayday-test-sync'})
    with urlopen(req, timeout=20) as response:
        releases = json.loads(response.read(2000000))
    candidates = []
    for release in releases:
        if release.get('draft'):
            continue
        for asset in release.get('assets', []):
            expected = f'https://github.com/{REPOSITORY}/releases/download/{release["tag_name"]}/wayday-test-release.json'
            if asset.get('name') == 'wayday-test-release.json' and asset.get('browser_download_url') == expected:
                with urlopen(expected, timeout=20) as response:
                    data = json.loads(response.read(20000))
                try:
                    validate_manifest(data)
                except ValueError:
                    continue
                candidates.append(data)
    if not candidates:
        raise ValueError('No qualified matching test release has been published. Previous APK kept.')
    return max(candidates, key=lambda x: x['versionCode'])


def replace_binary(source, directory, metadata, *, verify_binary=verify, previous_number=0):
    validate_manifest(metadata)
    if metadata['versionCode'] < previous_number:
        raise ValueError('Refusing a test APK downgrade.')
    source, directory = Path(source), Path(directory)
    if source.stat().st_size != metadata['sizeBytes'] or hashlib.sha256(source.read_bytes()).hexdigest() != metadata['sha256']:
        raise ValueError('Downloaded APK differs from its release checksum.')
    result = verify_binary(source, 'test', metadata['versionCode'], metadata['commit'], metadata['signingSha256'])
    directory.mkdir(parents=True, exist_ok=True)
    versioned = directory / f'wayday-navigation-test-{metadata["versionCode"]}.apk'
    if versioned.exists() and hashlib.sha256(versioned.read_bytes()).hexdigest() != metadata['sha256']:
        raise ValueError('An existing versioned test artifact differs; previous APK kept.')
    if not versioned.exists():
        staging = directory / (versioned.name + '.pending')
        shutil.copyfile(source, staging)
        os.replace(staging, versioned)
    pending = directory / 'wayday-navigation-test.apk.pending'
    shutil.copyfile(versioned, pending)
    os.replace(pending, directory / 'wayday-navigation-test.apk')
    write(directory / 'published-sync.json', result)


def main():
    data = latest()
    directory = ROOT / '.tools/alternative-navigation-phone'
    previous = directory / 'wayday-navigation-test.apk'
    sdk = Path(os.environ.get('ANDROID_HOME', str(Path(os.environ.get('LOCALAPPDATA', '')) / 'Android/Sdk')))
    os.environ.setdefault('ANDROID_HOME', str(sdk))
    if os.name == 'nt':
        os.environ.setdefault('JAVA_HOME', 'C:/Program Files/Android/Android Studio/jbr')
    number = 0
    if previous.exists():
        analyzer = sdk / ('cmdline-tools/latest/bin/apkanalyzer.bat' if os.name == 'nt' else 'cmdline-tools/latest/bin/apkanalyzer')
        number = int(command(str(analyzer), 'manifest', 'version-code', str(previous)))
    with TemporaryDirectory() as temp:
        apk = Path(temp) / 'wayday-test.apk'
        with urlopen(data['apkUrl'], timeout=30) as response, apk.open('wb') as output:
            size = 0
            while chunk := response.read(1048576):
                size += len(chunk)
                if size > data['sizeBytes']:
                    raise ValueError('Test download exceeded its declared size.')
                output.write(chunk)
        replace_binary(apk, directory, data, previous_number=number)
    print('Verified published Wayday Test APK and updated the Android Studio binary. No app was installed.')


if __name__ == '__main__':
    main()
