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
    monkeypatch.setattr(publication, 'publication_authorization', lambda _: {})
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
            if '/releases/tags/' in args[1]: raise RuntimeError('Draft release is not visible through the public tag endpoint')
            if args[1].endswith('/releases'):
                assert args[args.index('--method') + 1] == 'POST'
                state['release'] = {'id': 42, 'tag_name': 'dev-200000', 'target_commitish': 'a' * 40, 'draft': True, 'assets': []}
                return json.dumps(state['release'])
            if args[1].startswith('https://uploads.github.com/'):
                assert '/releases/42/assets?name=' in args[1]
                p = Path(args[args.index('--input') + 1])
                if state['fail'] and len(state['uploads']) == 2:
                    state['fail'] = False
                    raise RuntimeError('fixture interrupted upload')
                assert p.name not in state['uploads']
                state['uploads'][p.name] = p.read_bytes()
                state['release']['assets'].append({'name': p.name})
            else:
                assert args[1].endswith('/releases/42')
                assert args[args.index('--method') + 1] == 'PATCH'
                assert args[args.index('--field') + 1] == 'draft=false'
                assert len(state['uploads']) == 6
                state['release']['draft'] = False
        elif args[1] == 'download':
            name = args[args.index('--pattern') + 1]
            (Path(args[args.index('--dir') + 1]) / name).write_bytes(state['uploads'][name])
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


@pytest.mark.parametrize('invalid', [None, 'source', 'tag', 'published', 'identity'])
def test_new_release_uses_creation_response_even_when_listing_is_stale(monkeypatch, tmp_path, invalid):
    directory = fixture(monkeypatch, tmp_path)
    release = {'id': 42, 'tag_name': 'dev-200000', 'target_commitish': 'a' * 40,
               'draft': True, 'assets': []}
    if invalid == 'source': release['target_commitish'] = 'c' * 40
    if invalid == 'tag': release['tag_name'] = 'dev-200001'
    if invalid == 'published': release['draft'] = False
    if invalid == 'identity': release.pop('id')
    uploads = []
    def gh(*args):
        if args[0] == 'api' and '--method' not in args:
            assert '/releases?' in args[1]
            return '[]'  # Creation has not propagated to the listing yet.
        if args[0] == 'api' and args[1].endswith('/releases'):
            payload = json.loads(Path(args[args.index('--input') + 1]).read_text())
            assert payload['tag_name'] == 'dev-200000'
            assert payload['target_commitish'] == 'a' * 40
            assert payload['draft'] is True and payload['prerelease'] is True
            return json.dumps(release)
        if args[0] == 'api' and args[1].startswith('https://uploads.github.com/'):
            assert '/releases/42/assets?name=' in args[1]
            uploads.append(Path(args[args.index('--input') + 1]).name)
        elif args[0] == 'api' and args[1].endswith('/releases/42'):
            assert args[args.index('--method') + 1] == 'PATCH'
            assert len(uploads) == 6
        else: raise AssertionError(args)
        return ''
    monkeypatch.setattr(publication, 'gh', gh)
    if invalid:
        with pytest.raises(ValueError): publication.publish(directory)
        assert not uploads
    else:
        publication.publish(directory)
        assert len(uploads) == 6
