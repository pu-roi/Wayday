"""Publish the owner's selected immutable APKs for testing via the website."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile

from release import PREVIEW_AUTHORIZATION, config_fingerprint, public_defines, write
from publish_release import gh, publish
from verify_apk import verify


def verify_source(run, artifact, jobs, selected):
    if (run.get('head_sha') != selected['commit'] or run.get('head_branch') != 'main'
            or run.get('event') != 'push' or artifact.get('expired') is not False
            or artifact.get('id') != selected['artifactId']
            or artifact.get('name') != 'release-candidates'
            or artifact.get('workflow_run', {}).get('id') != selected['runId']
            or artifact.get('digest') != 'sha256:' + selected['artifactSha256']):
        raise ValueError('Selected candidate provenance differs from the approved artifact.')
    required = {'website', 'api', 'mobile', 'native', 'release-contract', 'release-candidates'}
    passed = {j['name'] for j in jobs if j.get('conclusion') == 'success'}
    if not required <= passed:
        raise ValueError('Selected source has not passed every required verification stage.')


def extract(archive, directory, selected):
    if hashlib.sha256(Path(archive).read_bytes()).hexdigest() != selected['artifactSha256']:
        raise ValueError('Downloaded candidate artifact checksum differs from approval.')
    expected = {'wayday.apk', 'wayday-test.apk', 'public-verification.json', 'test-verification.json'}
    with zipfile.ZipFile(archive) as z:
        if len(z.namelist()) != 4 or set(z.namelist()) != expected or z.testzip() is not None:
            raise ValueError('Unexpected candidate archive contents.')
        for name in expected:
            target = Path(directory) / name
            target.write_bytes(z.read(name))


def main():
    authorization = json.loads(PREVIEW_AUTHORIZATION.read_text(encoding='utf-8'))
    selected = authorization['selectedCandidate']
    run = json.loads(gh('api', f'repos/pu-roi/Wayday/actions/runs/{selected["runId"]}'))
    jobs = json.loads(gh('api', f'repos/pu-roi/Wayday/actions/runs/{selected["runId"]}/jobs?per_page=100'))['jobs']
    artifact = json.loads(gh('api', f'repos/pu-roi/Wayday/actions/artifacts/{selected["artifactId"]}'))
    verify_source(run, artifact, jobs, selected)
    with tempfile.TemporaryDirectory() as temp:
        directory = Path(temp)
        archive = directory / 'candidates.zip'
        with archive.open('wb') as output:
            subprocess.run(['gh', 'api', f'repos/pu-roi/Wayday/actions/artifacts/{selected["artifactId"]}/zip'],
                           stdout=output, check=True, timeout=240)
        extract(archive, directory, selected)
        for channel, name in [('public', 'wayday.apk'), ('test', 'wayday-test.apk')]:
            record = json.loads((directory / (channel + '-verification.json')).read_text())
            actual = verify(directory / name, channel, selected['versionCode'], selected['commit'], authorization['signingSha256'])
            for key in actual:
                if record.get(key) != actual[key]:
                    raise ValueError('Candidate verification record differs from the actual APK.')
            if (actual['sha256'] != selected['apks'][name]
                    or record['configFingerprint'] != config_fingerprint(public_defines(channel=channel))):
                raise ValueError('Selected APK hash or channel configuration differs from approval.')
        publish(directory, candidate_commit=selected['commit'])
        write(os.environ['WAYDAY_PREVIEW_REPORT'], {'publishedVersion': selected['versionCode'],
              'candidateCommit': selected['commit'], 'officialPhoneVerified': False})


if __name__ == '__main__':
    main()
