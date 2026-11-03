import hashlib
import json
from pathlib import Path
from types import SimpleNamespace

import pytest
import publish_release as publication


def fixture(monkeypatch, tmp_path):
    commit = 'a' * 40
    monkeypatch.setenv('GITHUB_SHA', commit)
    monkeypatch.setenv('WAYDAY_GATEWAY_URL', 'https://production.example')
    monkeypatch.setenv('WAYDAY_TEST_GATEWAY_URL', 'https://test.example')
    monkeypatch.setattr(publication, 'qualification', lambda _: None)
    monkeypatch.setattr(publication, 'require_current', lambda _: None)
    monkeypatch.setattr(publication, 'verify_gateway', lambda _: None)
    monkeypatch.setattr(publication, 'latest_release', lambda: {'qualified': False})
    for channel, name in [('public', 'wayday.apk'), ('test', 'wayday-test.apk')]:
        (tmp_path / name).write_bytes(channel.encode())
        data = {'commit': commit, 'releaseProfile': publication.release_profile(), 'versionCode': 200000,
                'signingSha256': 'b' * 64, 'channel': channel,
                'sha256': hashlib.sha256(channel.encode()).hexdigest()}
        (tmp_path / (channel + '-verification.json')).write_text(json.dumps(data))
    def manifest(args, **kwargs):
        channel = args[args.index('--channel') + 1]
        path = Path(args[args.index('--output') + 1])
        path.write_text(json.dumps({'qualified': True, 'channel': channel, 'commit': commit, 'publishedAt': path.name}))
        return SimpleNamespace(returncode=0)
    monkeypatch.setattr(publication.subprocess, 'run', manifest)
    return tmp_path


def test_partial_release_resumes_without_overwriting_and_publishes_only_complete_assets(monkeypatch, tmp_path):
    directory = fixture(monkeypatch, tmp_path)
    state = {'release': None, 'uploads': {}, 'fail': True}
    def gh(*args):
        if args[0] == 'api':
            if '/releases?' in args[1]: return json.dumps([state['release']] if state['release'] else [])
            return json.dumps(state['release'])
        if args[1] == 'create':
            state['release'] = {'tag_name': args[2], 'target_commitish': 'a' * 40, 'draft': True, 'assets': []}
        elif args[1] == 'upload':
            p = Path(args[3])
            if state['fail'] and len(state['uploads']) == 2:
                state['fail'] = False
                raise RuntimeError('fixture interrupted upload')
            assert p.name not in state['uploads']
            state['uploads'][p.name] = p.read_bytes()
            state['release']['assets'].append({'name': p.name})
        elif args[1] == 'download':
            name = args[args.index('--pattern') + 1]
            (Path(args[args.index('--dir') + 1]) / name).write_bytes(state['uploads'][name])
        elif args[1] == 'edit':
            assert len(state['uploads']) == 6
            state['release']['draft'] = False
        else: raise AssertionError(args)
        return ''
    monkeypatch.setattr(publication, 'gh', gh)
    with pytest.raises(RuntimeError): publication.publish(directory)
    assert state['release']['draft'] is True
    assert len(state['uploads']) == 2
    publication.publish(directory)
    assert state['release']['draft'] is False
    assert len(state['uploads']) == 6
    publication.publish(directory)  # A completed rerun only verifies existing assets.
    assert len(state['uploads']) == 6


@pytest.mark.parametrize('cause', ['newer_release', 'gateway'])
def test_failed_readiness_never_creates_or_uploads_release(monkeypatch, tmp_path, cause):
    directory = fixture(monkeypatch, tmp_path)
    calls = []
    monkeypatch.setattr(publication, 'gh', lambda *args: calls.append(args))
    if cause == 'newer_release':
        monkeypatch.setattr(publication, 'latest_release', lambda: {'versionCode': 200001})
    else:
        def reject(_): raise ValueError('incompatible gateway')
        monkeypatch.setattr(publication, 'verify_gateway', reject)
    with pytest.raises(ValueError): publication.publish(directory)
    assert not calls
