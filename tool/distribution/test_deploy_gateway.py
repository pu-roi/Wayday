import copy
import json

import pytest
import deploy_gateway as deployment


def base(test=False):
    values = {'GOOGLE_CLOUD_PROJECT': 'fixture', 'WAYDAY_FIREBASE_APP_IDS': 'test-id' if test else 'public-id,test-id',
              'WAYDAY_PUBLIC_LEDGER_DOCUMENT': 'accounting/preserved'}
    env = [{'name': k, 'value': v} for k, v in values.items()]
    env += [{'name': k, 'valueFrom': {'secretKeyRef': {'name': k.lower(), 'key': '1'}}}
            for k in ['GEMINI_API_KEY', 'GOOGLE_ROUTES_SERVER_API_KEY', 'GEOAPIFY_API_KEY', 'LOCATIONIQ_API_KEY']]
    return {'metadata': {'labels': {}}, 'spec': {'serviceAccountName': 'preserved-runtime', 'containers': [{'image': 'old', 'env': env}]}}


def test_revision_config_preserves_secrets_accounting_and_channel_identity(monkeypatch):
    monkeypatch.setenv('WAYDAY_TEST_FIREBASE_APP_ID', 'test-id')
    for test in [False, True]:
        values, secrets = deployment.revision_environment(base(test), test=test)
        assert values['WAYDAY_PUBLIC_LEDGER_DOCUMENT'] == 'accounting/preserved'
        assert values['WAYDAY_DAILY_CEILINGS'] == 'false'
        assert len(secrets) == 4 and all(x.endswith(':1') for x in secrets.values())
    wrong = base(True)
    wrong['spec']['containers'][0]['env'][1]['value'] = 'unregistered'
    with pytest.raises(ValueError):
        deployment.revision_environment(wrong, test=True)


@pytest.mark.parametrize('fail_smoke', [False, True])
def test_deploy_verifies_both_candidates_then_promotes_or_restores_prior_traffic(monkeypatch, tmp_path, fail_smoke):
    commit, image = 'a' * 40, 'registry/gateway@sha256:' + 'b' * 64
    for key, value in {'WAYDAY_GOOGLE_CLOUD_PROJECT': 'fixture', 'WAYDAY_TEST_FIREBASE_APP_ID': 'test-id',
                       'WAYDAY_GATEWAY_URL': 'https://production.example', 'WAYDAY_TEST_GATEWAY_URL': 'https://test.example'}.items():
        monkeypatch.setenv(key, value)
    revisions = {'old-public': base(), 'old-test': base(True)}
    traffic = [{'revisionName': 'old-public', 'percent': 100}, {'revisionName': 'old-test', 'tag': 'navigation-test', 'url': 'https://test.example'}]
    commands, checked = [], []

    def run(*args, **kwargs):
        args = list(args)
        commands.append(args)
        if args[:2] == ['git', 'ls-remote']:
            return commit + '\trefs/heads/main'
        if args[2:4] == ['services', 'describe']:
            return {'status': {'traffic': copy.deepcopy(traffic)}}
        if args[2:4] == ['revisions', 'describe']:
            return revisions[args[4]]
        if args[2:4] == ['revisions', 'list']:
            return []
        if args[2] == 'deploy':
            assert '--no-traffic' in args
            channel = 'test' if any(x.startswith('--revision-suffix=test-') for x in args) else 'pub'
            record = copy.deepcopy(base(channel == 'test'))
            values, secrets = deployment.revision_environment(record, test=channel == 'test')
            record['metadata']['labels']['commit-sha'] = commit
            record['spec']['containers'][0]['image'] = image
            record['spec']['containers'][0]['env'] = [{'name': k, 'value': v} for k, v in values.items()] + [
                {'name': k, 'valueFrom': {'secretKeyRef': {'name': v.split(':')[0], 'key': '1'}}} for k, v in secrets.items()]
            revisions['wayday-gateway-' + channel + '-' + commit[:12]] = record
            return {}
        if args[2:4] == ['services', 'update-traffic']:
            for arg in args:
                if arg.startswith('--update-tags='):
                    tag, name = arg.split('=', 1)[1].split('=')
                    traffic[:] = [x for x in traffic if x.get('tag') != tag]
                    traffic.append({'tag': tag, 'revisionName': name, 'url': 'https://' + tag + '.example'})
                if arg.startswith('--to-revisions='):
                    name = arg.split('=', 1)[1].rsplit('=', 1)[0]
                    for row in traffic:
                        row.pop('percent', None)
                    traffic.append({'revisionName': name, 'percent': 100})
            return {}
        raise AssertionError(args)

    def verify(url):
        checked.append(url)
        if fail_smoke and url == 'https://production.example':
            raise ValueError('fixture failed live readiness')

    monkeypatch.setattr(deployment, 'run', run)
    monkeypatch.setattr(deployment, 'verify_gateway', verify)
    output = tmp_path / 'delivery.json'
    if fail_smoke:
        with pytest.raises(ValueError):
            deployment.deploy(image, commit, output)
        assert any(x.get('percent') == 100 and x['revisionName'] == 'old-public' for x in traffic)
        assert json.loads(output.read_text())['stages'][-1] == 'promotion-rolled-back'
    else:
        deployment.deploy(image, commit, output)
        assert json.loads(output.read_text())['stages'][-1] == 'promoted-and-verified'
    assert checked[:2] == ['https://release-candidate-pub.example', 'https://release-candidate-test.example']
