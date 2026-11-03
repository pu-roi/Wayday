import copy
import json

import pytest
import release


def approved(monkeypatch, tmp_path):
    for key in release.PUBLIC_KEYS:
        monkeypatch.setenv(key, 'fixture')
    monkeypatch.setenv('WAYDAY_GATEWAY_URL', 'https://production.example')
    monkeypatch.setenv('WAYDAY_TEST_GATEWAY_URL', 'https://test.example')
    monkeypatch.setenv('WAYDAY_TEST_FIREBASE_APP_ID', 'test-identity')
    value = {
        'mode': 'website-first-development-preview', 'ownerApproved': True,
        'officialPhoneVerified': False, 'testAppUserReportedTested': True,
        'signingSha256': 'b' * 64, 'releaseProfile': release.release_profile(),
        'channelConfigFingerprints': {c: release.config_fingerprint(release.public_defines(channel=c)) for c in ('public', 'test')},
        'compatibility': 'Android 7.0+; official phone verification pending.',
        'evidence': 'owner-request',
    }
    path = tmp_path / 'preview.json'
    path.write_text(json.dumps(value))
    monkeypatch.setattr(release, 'PREVIEW_AUTHORIZATION', path)
    return value, path


def test_owner_preview_allows_website_testing_without_claiming_phone_qualification(monkeypatch, tmp_path):
    value, _ = approved(monkeypatch, tmp_path)
    record = release.publication_authorization('b' * 64)
    assert record['mode'] == value['mode']
    assert record['officialPhoneVerified'] is False


@pytest.mark.parametrize('change', ['approval', 'profile', 'identity', 'certificate'])
def test_preview_keeps_explicit_approval_exact_profile_config_and_signing_gates(monkeypatch, tmp_path, change):
    value, path = approved(monkeypatch, tmp_path)
    if change == 'approval': value['ownerApproved'] = False
    if change == 'profile': value['releaseProfile'] = {}
    if change == 'identity': monkeypatch.setenv('WAYDAY_TEST_FIREBASE_APP_ID', 'changed')
    path.write_text(json.dumps(value))
    with pytest.raises(ValueError):
        release.publication_authorization('c' * 64 if change == 'certificate' else 'b' * 64)


def test_unqualified_manifest_needs_explicit_preview_status():
    value = {'qualified': False, 'previewApproved': True, 'verificationStatus': 'official-phone-pending',
             'tag': 'dev-103401', 'version': '0.1.0+103401', 'versionCode': 103401,
             'publishedAt': '2026-11-03T06:00:00Z', 'sizeBytes': 123, 'sha256': 'a' * 64,
             'apkUrl': 'https://github.com/pu-roi/Wayday/releases/download/dev-103401/wayday.apk',
             'notesUrl': 'https://github.com/pu-roi/Wayday/releases/tag/dev-103401', 'compatibility': 'Phone test pending'}
    assert release.valid_manifest(value)
    for field in ['previewApproved', 'verificationStatus']:
        changed = copy.deepcopy(value)
        changed.pop(field)
        assert not release.valid_manifest(changed)
