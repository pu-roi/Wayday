"""Resume a complete immutable release, publishing only after all gates pass."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory

from deploy_gateway import require_current
from release import ROOT, REPOSITORY, publication_authorization, release_profile, verify_gateway, write, latest_release


def gh(*args):
    result = subprocess.run(['gh', *args], capture_output=True, text=True, timeout=240)
    if result.returncode:
        raise RuntimeError('GitHub release operation failed: ' + args[0])
    return result.stdout


def publish(directory, *, candidate_commit=None):
    directory = Path(directory)
    control_commit = os.environ['GITHUB_SHA']
    commit = candidate_commit or control_commit
    records = [json.loads((directory / (channel + '-verification.json')).read_text()) for channel in ('public', 'test')]
    if any(x['commit'] != commit or x['releaseProfile'] != release_profile() for x in records):
        raise ValueError('Candidate source or feature profile changed.')
    if records[0]['versionCode'] != records[1]['versionCode'] or records[0]['signingSha256'] != records[1]['signingSha256']:
        raise ValueError('Both candidates must belong to the same signed release.')
    number = records[0]['versionCode']
    certificate = records[0]['signingSha256']
    authorization = publication_authorization(certificate)
    require_current(control_commit)
    latest = latest_release()
    if latest.get('versionCode', 0) > number or (
            latest.get('versionCode') == number and latest.get('commit') != commit):
        raise ValueError('A newer or conflicting public release already exists.')
    verify_gateway(os.environ['WAYDAY_GATEWAY_URL'])
    verify_gateway(os.environ['WAYDAY_TEST_GATEWAY_URL'])
    tag = 'dev-' + str(number)
    files = []
    for record, name, manifest in zip(records, ['wayday.apk', 'wayday-test.apk'], ['wayday-release.json', 'wayday-test-release.json']):
        apk = directory / name
        if hashlib.sha256(apk.read_bytes()).hexdigest() != record['sha256']:
            raise ValueError('Candidate APK checksum changed after verification.')
        subprocess.run([os.sys.executable, str(ROOT / 'tool/distribution/release.py'), 'manifest',
                        '--apk', str(apk), '--channel', record['channel'], '--number', str(number),
                        '--certificate', certificate, '--output', str(directory / manifest)], check=True,
                       env={**os.environ, 'GITHUB_SHA': commit})
        (directory / (name + '.sha256')).write_text(record['sha256'] + '  ' + name + '\n')
        files.extend([apk, directory / manifest, directory / (name + '.sha256')])
    releases = json.loads(gh('api', f'repos/{REPOSITORY}/releases?per_page=100'))
    existing = next((x for x in releases if x['tag_name'] == tag), None)
    if existing and existing['target_commitish'] != commit:
        raise ValueError('Release tag already belongs to another source commit.')
    if not existing:
        notes = ('Android development preview. Install each APK as an update to its matching app.\n\n'
                         + 'Source commit: ' + commit + '\n\nWayday and Wayday Test share the same logo, interface and navigation features.\n'
                         + ('\nOwner-approved website testing preview. The owner reports testing Wayday Test; official-app phone verification is pending.\n'
                            if authorization.get('mode') == 'website-first-development-preview' else ''))
        request = directory / 'release-request.json'
        write(request, {'tag_name': tag, 'target_commitish': commit, 'draft': True,
                        'prerelease': True, 'name': 'Wayday development ' + str(number), 'body': notes})
        # Validate the creation response itself. Immediate tag and list reads
        # can both omit a newly created draft even though creation succeeded.
        existing = json.loads(gh('api', f'repos/{REPOSITORY}/releases', '--method', 'POST', '--input', str(request)))
        if (not isinstance(existing, dict) or type(existing.get('id')) is not int
                or existing.get('tag_name') != tag or existing.get('target_commitish') != commit
                or existing.get('draft') is not True or existing.get('assets') != []):
            raise ValueError('New draft release could not be verified against its source.')
    # Never overwrite an uploaded APK. Partial uploads are resumed by checksum.
    for path in files:
        remote = next((x for x in existing['assets'] if x['name'] == path.name), None)
        if remote:
            with TemporaryDirectory() as temp:
                gh('release', 'download', tag, '--repo', REPOSITORY, '--pattern', path.name, '--dir', temp)
                data = (Path(temp) / path.name).read_bytes()
                if path.suffix == '.json':
                    old, new = json.loads(data), json.loads(path.read_bytes())
                    old.pop('publishedAt', None)
                    new.pop('publishedAt', None)
                    matches = old == new
                else:
                    matches = hashlib.sha256(data).digest() == hashlib.sha256(path.read_bytes()).digest()
                if not matches:
                    raise ValueError('An immutable uploaded asset differs from this candidate.')
        else:
            if not existing['draft']:
                raise ValueError('Published release is incomplete; refusing to modify it.')
            gh('release', 'upload', tag, str(path), '--repo', REPOSITORY)
    require_current(control_commit)
    if existing['draft']:
        gh('release', 'edit', tag, '--repo', REPOSITORY, '--draft=false')
    write(directory / 'publication.json', {'commit': commit, 'tag': tag, 'complete': True})


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--directory', required=True)
    publish(parser.parse_args().directory)
