"""Deploy one immutable image to both channels; never dispatch a provider call."""
import argparse
import json
import os
import re
import subprocess

from release import write, verify_gateway, release_profile


def run(*args, decode=True):
    result = subprocess.run(list(args), capture_output=True, text=True, timeout=240)
    if result.returncode:
        raise RuntimeError('Release command failed: ' + ' '.join(args[:3]))
    return json.loads(result.stdout) if decode else result.stdout.strip()


def require_current(commit):
    remote = run('git', 'ls-remote', 'origin', 'refs/heads/main', decode=False)
    if remote.split()[0] != commit:
        raise ValueError('A newer main commit superseded this release.')


def revision_environment(base, *, test):
    values, secrets = {}, {}
    for entry in base['spec']['containers'][0]['env']:
        if 'value' in entry:
            values[entry['name']] = entry['value']
        else:
            ref = entry['valueFrom']['secretKeyRef']
            secrets[entry['name']] = ref['name'] + ':' + ref['key']
    required = {'GEMINI_API_KEY', 'GOOGLE_ROUTES_SERVER_API_KEY', 'GEOAPIFY_API_KEY', 'LOCATIONIQ_API_KEY'}
    if set(secrets) != required:
        raise ValueError('Reviewed provider secret references changed.')
    values = {k: values[k] for k in ('GOOGLE_CLOUD_PROJECT', 'WAYDAY_FIREBASE_APP_IDS', 'WAYDAY_PUBLIC_LEDGER_DOCUMENT')}
    if test and values['WAYDAY_FIREBASE_APP_IDS'] != os.environ['WAYDAY_TEST_FIREBASE_APP_ID']:
        raise ValueError('Test identity differs from the registered test channel.')
    values.update(WAYDAY_ALTERNATIVE_NAVIGATION='true', WAYDAY_DAILY_CEILINGS='false', WAYDAY_GEOAPIFY_TEST_LIMITS='false')
    if release_profile()['features'].get('WAYDAY_SHARING') == 'true':
        browser_key = os.environ.get('WAYDAY_SHARE_BROWSER_KEY', '').strip()
        if not browser_key:
            raise ValueError('The restricted sharing browser map configuration is missing.')
        values.update(WAYDAY_SHARING_ENABLED='true', WAYDAY_SHARE_BROWSER_KEY=browser_key,
                      WAYDAY_SHARE_COLLECTION='tripShares',
                      WAYDAY_SHARE_PACKAGE='dev.wayday.wayday.publictest' if test else 'dev.wayday.wayday',
                      WAYDAY_SHARE_CERTIFICATE='8B:02:32:DD:12:85:3D:9B:D3:5B:19:8F:A9:C1:D3:65:6E:14:BA:E1:ED:0B:50:ED:EF:3F:A9:FA:D3:55:41:51')
    return values, secrets


def verify_revision(revision, image, commit, values, secrets, runtime):
    actual_values, actual_secrets = {}, {}
    for entry in revision['spec']['containers'][0]['env']:
        if 'value' in entry:
            actual_values[entry['name']] = entry['value']
        else:
            ref = entry['valueFrom']['secretKeyRef']
            actual_secrets[entry['name']] = ref['name'] + ':' + ref['key']
    if (revision['metadata'].get('labels', {}).get('commit-sha') != commit
            or revision['spec']['containers'][0]['image'] != image
            or revision['spec']['serviceAccountName'] != runtime
            or actual_values != values or actual_secrets != secrets):
        raise ValueError('Deployed revision differs from the reviewed source/configuration.')


def deploy(image, commit, output):
    if not re.fullmatch(r'[0-9a-f]{40}', commit) or not re.fullmatch(r'[^\s]+@sha256:[0-9a-f]{64}', image):
        raise ValueError('An immutable source commit and image digest are required.')
    project = os.environ['WAYDAY_GOOGLE_CLOUD_PROJECT']
    scope = ['--project=' + project, '--region=asia-southeast1']
    def cloud(*args):
        return run('gcloud', 'run', *args, *scope, '--format=json', '--quiet')
    service = cloud('services', 'describe', 'wayday-gateway')
    traffic = service['status']['traffic']
    production = next(x['revisionName'] for x in traffic if x.get('percent') == 100)
    test = next(x['revisionName'] for x in traffic if x.get('tag') == 'navigation-test')
    report = {'commit': commit, 'image': image, 'previousProduction': production, 'previousTest': test, 'stages': []}
    write(output, report)
    revisions = {}
    for channel, base_name in [('pub', production), ('test', test)]:
        base = cloud('revisions', 'describe', base_name)
        values, secrets = revision_environment(base, test=channel == 'test')
        runtime = base['spec']['serviceAccountName']
        name = 'wayday-gateway-' + channel + '-' + commit[:12]
        # A repeated run reuses a verified immutable revision.
        listed = cloud('revisions', 'list', '--service=wayday-gateway', '--filter=metadata.name=' + name)
        if not listed:
            require_current(commit)
            cloud('deploy', 'wayday-gateway', '--image=' + image, '--revision-suffix=' + channel + '-' + commit[:12],
                  '--no-traffic', '--tag=release-candidate-' + channel,
                  '--set-env-vars=^|^' + '|'.join(k + '=' + v for k, v in sorted(values.items())),
                  '--set-secrets=' + ','.join(k + '=' + v for k, v in sorted(secrets.items())),
                  '--labels=managed-by=github-actions,commit-sha=' + commit,
                  '--service-account=' + runtime, '--min-instances=0', '--max-instances=1',
                  '--concurrency=4', '--cpu=1', '--memory=512Mi', '--timeout=60s', '--cpu-throttling')
        revision = cloud('revisions', 'describe', name)
        verify_revision(revision, image, commit, values, secrets, runtime)
        # Ensure the candidate tag also exists when resuming a partial run.
        cloud('services', 'update-traffic', 'wayday-gateway', '--update-tags=release-candidate-' + channel + '=' + name)
        service = cloud('services', 'describe', 'wayday-gateway')
        url = next(x['url'] for x in service['status']['traffic'] if x.get('tag') == 'release-candidate-' + channel)
        verify_gateway(url)
        revisions[channel] = name
        report['stages'].append(channel + '-verified')
        write(output, report)
    require_current(commit)
    cloud('services', 'update-traffic', 'wayday-gateway', '--to-revisions=' + revisions['pub'] + '=100',
          '--update-tags=navigation-test=' + revisions['test'])
    try:
        verify_gateway(os.environ['WAYDAY_GATEWAY_URL'])
        verify_gateway(os.environ['WAYDAY_TEST_GATEWAY_URL'])
        service = cloud('services', 'describe', 'wayday-gateway')
        actual = service['status']['traffic']
        if not any(x.get('revisionName') == revisions['pub'] and x.get('percent') == 100 for x in actual):
            raise ValueError('Production traffic did not move to the verified revision.')
        if not any(x.get('tag') == 'navigation-test' and x['revisionName'] == revisions['test'] for x in actual):
            raise ValueError('Test traffic did not move to the verified revision.')
    except Exception:
        # No new client has been published at this stage. Keep previous clients usable.
        cloud('services', 'update-traffic', 'wayday-gateway', '--to-revisions=' + production + '=100',
              '--update-tags=navigation-test=' + test)
        report['stages'].append('promotion-rolled-back')
        write(output, report)
        raise
    report.update(production=revisions['pub'], test=revisions['test'])
    report['stages'].append('promoted-and-verified')
    write(output, report)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--image', required=True)
    parser.add_argument('--commit', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    deploy(args.image, args.commit, args.output)
