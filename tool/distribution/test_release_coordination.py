import json

import pytest

import release


def test_effective_profile_requires_both_contracts_and_shared_navigation():
    profile = release.release_profile()
    assert set(profile['contracts']) == {'d66-v1', 'errand-v2'}
    assert profile['features'] == {
        'WAYDAY_ALTERNATIVE_NAVIGATION': 'true',
        'WAYDAY_UI_KIT_NAVIGATION_TARGETS': 'true',
        'WAYDAY_SHARING': 'true',
    }


def test_gateway_gate_rejects_old_health_wrong_hash_and_disabled_features():
    profile = release.release_profile()
    health = {'status': 'configured', 'providerCalls': False,
              'contracts': profile['contracts'],
              'capabilities': {'alternativeNavigation': True, 'dailyCeilings': False, 'tripSharing': True}}
    release.validate_gateway(health)
    for patch in [
        {'contracts': {}}, {'contracts': {**profile['contracts'], 'errand-v2': 'a' * 64}},
        {'capabilities': {'alternativeNavigation': False, 'dailyCeilings': False}},
        {'capabilities': {'alternativeNavigation': True, 'dailyCeilings': True}},
        {'providerCalls': True},
    ]:
        with pytest.raises(ValueError):
            release.validate_gateway({**health, **patch})


def test_both_build_channels_use_shared_features_and_separate_identity(monkeypatch):
    for key in release.PUBLIC_KEYS:
        monkeypatch.setenv(key, 'fixture')
    monkeypatch.setenv('WAYDAY_GATEWAY_URL', 'https://production.example')
    monkeypatch.setenv('WAYDAY_TEST_GATEWAY_URL', 'https://test.example')
    monkeypatch.setenv('WAYDAY_TEST_FIREBASE_APP_ID', 'test-identity')
    public = release.public_defines(channel='public')
    test = release.public_defines(channel='test')
    assert public['WAYDAY_FIREBASE_APP_ID'] != test['WAYDAY_FIREBASE_APP_ID']
    assert public['WAYDAY_GATEWAY_URL'] != test['WAYDAY_GATEWAY_URL']
    assert 'WAYDAY_PUBLIC_TEST' not in public
    assert test['WAYDAY_PUBLIC_TEST'] == 'true'
    for name, value in release.release_profile()['features'].items():
        assert public[name] == test[name] == value


def test_qualification_is_bound_to_current_feature_and_contract_profile(monkeypatch, tmp_path):
    record = json.loads(release.QUALIFICATION.read_text())
    for key in release.PUBLIC_KEYS:
        monkeypatch.setenv(key, 'fixture')
    monkeypatch.setenv('WAYDAY_GATEWAY_URL', 'https://production.example')
    monkeypatch.setenv('WAYDAY_TEST_GATEWAY_URL', 'https://test.example')
    monkeypatch.setenv('WAYDAY_TEST_FIREBASE_APP_ID', 'test-identity')
    record['configFingerprint'] = release.config_fingerprint(release.public_defines())
    path = tmp_path / 'qualification.json'
    path.write_text(json.dumps(record))
    monkeypatch.setattr(release, 'QUALIFICATION', path)
    with pytest.raises(ValueError, match='profile'):
        release.qualification(record['signingSha256'])
    record['releaseProfile'] = release.release_profile()
    record['channelConfigFingerprints'] = {
        channel: release.config_fingerprint(release.public_defines(channel=channel))
        for channel in ('public', 'test')
    }
    path.write_text(json.dumps(record))
    assert release.qualification(record['signingSha256']) == record
    monkeypatch.setenv('WAYDAY_TEST_FIREBASE_APP_ID', 'changed-identity')
    with pytest.raises(ValueError, match='channel configurations'):
        release.qualification(record['signingSha256'])
