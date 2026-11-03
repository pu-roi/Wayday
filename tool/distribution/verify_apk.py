"""Verify the actual release binary before offering it to users. No device I/O."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET
import zipfile

from release import ROOT, QUALIFICATION, certificate_normalized, config_fingerprint, release_profile


def command(*args):
    result = subprocess.run(list(args), capture_output=True, text=True, encoding='utf-8', timeout=90)
    if result.returncode:
        raise ValueError('APK verification tool failed.')
    return result.stdout


def verify(apk, channel, number, commit, certificate, *, sdk=None):
    registered = json.loads(QUALIFICATION.read_text(encoding='utf-8'))['signingSha256']
    if certificate_normalized(certificate) != registered:
        raise ValueError('Candidate signing identity differs from the registered permanent certificate.')
    sdk = Path(sdk or os.environ.get('ANDROID_HOME', os.environ.get('ANDROID_SDK_ROOT', '')))
    suffix = '.bat' if os.name == 'nt' else ''
    analyzer = sdk / ('cmdline-tools/latest/bin/apkanalyzer' + suffix)
    xml = ET.fromstring(command(str(analyzer), 'manifest', 'print', str(apk)))
    a = '{http://schemas.android.com/apk/res/android}'
    app = xml.find('application')
    sdk_info = xml.find('uses-sdk')
    if sdk_info is None or sdk_info.get(a + 'minSdkVersion') != '24' or sdk_info.get(a + 'targetSdkVersion') != '36':
        raise ValueError('APK Android compatibility differs from the qualified platform range.')
    package = 'dev.wayday.wayday' + ('.publictest' if channel == 'test' else '')
    label = 'Wayday Test' if channel == 'test' else 'Wayday'
    if xml.get('package') != package or int(xml.get(a + 'versionCode')) != number or app.get(a + 'label') != label:
        raise ValueError('APK package, label or version does not match the release channel.')
    metadata = {x.get(a + 'name'): x.get(a + 'value') for x in app.findall('meta-data')}
    if metadata.get('wayday.sourceCommit') != commit or metadata.get('wayday.releaseProfile') != config_fingerprint(release_profile()):
        raise ValueError('APK source/profile differs from the release.')
    tools = sdk / 'build-tools/36.0.0' / ('apksigner' + suffix)
    signature = command(str(tools), 'verify', '--verbose', '--print-certs', str(apk))
    expected = certificate_normalized(certificate)
    if not any(line.split(':', 1)[-1].strip() == expected for line in signature.splitlines() if 'certificate SHA-256 digest:' in line):
        raise ValueError('APK signing certificate changed.')
    with zipfile.ZipFile(apk) as archive:
        if archive.testzip() is not None:
            raise ValueError('APK ZIP integrity failed.')
        logo = archive.read('assets/flutter_assets/assets/branding/wayday-logo.png')
        if logo != (ROOT / 'apps/mobile/assets/branding/wayday-logo.png').read_bytes():
            raise ValueError('APK logo differs from the shared branding source.')
    return {'package': package, 'channel': channel, 'versionCode': number, 'commit': commit,
            'sha256': hashlib.sha256(Path(apk).read_bytes()).hexdigest(),
            'sizeBytes': Path(apk).stat().st_size, 'releaseProfile': release_profile(),
            'signingSha256': expected}


if __name__ == '__main__':
    from release import write, public_defines
    parser = argparse.ArgumentParser()
    parser.add_argument('--apk', required=True)
    parser.add_argument('--channel', choices=('public', 'test'), required=True)
    parser.add_argument('--number', type=int, required=True)
    parser.add_argument('--commit', required=True)
    parser.add_argument('--certificate', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    record = verify(args.apk, args.channel, args.number, args.commit, args.certificate)
    record['configFingerprint'] = config_fingerprint(public_defines(channel=args.channel))
    write(args.output, record)
