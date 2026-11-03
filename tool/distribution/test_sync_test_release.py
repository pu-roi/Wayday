import hashlib
import json

import pytest
import sync_test_release as sync


def manifest():
    return {'qualified': True, 'channel': 'test', 'package': 'dev.wayday.wayday.publictest',
            'tag': 'dev-200000', 'apkUrl': 'https://github.com/pu-roi/Wayday/releases/download/dev-200000/wayday-test.apk',
            'releaseProfile': sync.release_profile(), 'signingSha256': json.loads(sync.QUALIFICATION.read_text())['signingSha256'],
            'versionCode': 200000, 'sizeBytes': 7, 'sha256': hashlib.sha256(b'fixture').hexdigest(), 'commit': 'a' * 40}


@pytest.mark.parametrize('failure', ['checksum', 'signature', 'downgrade', 'identity', 'profile'])
def test_failed_update_keeps_stable_test_binary(tmp_path, failure):
    directory = tmp_path / 'alias'
    directory.mkdir()
    stable = directory / 'wayday-navigation-test.apk'
    stable.write_bytes(b'previous usable binary')
    source = tmp_path / 'download.apk'
    source.write_bytes(b'fixture')
    data = manifest()
    if failure == 'checksum': data['sha256'] = 'b' * 64
    if failure == 'identity': data['package'] = 'dev.wayday.wayday'
    if failure == 'profile': data['releaseProfile'] = {}
    def verify(*args):
        if failure == 'signature': raise ValueError('wrong certificate')
        return {'verified': True}
    with pytest.raises(ValueError):
        sync.replace_binary(source, directory, data, verify_binary=verify,
                            previous_number=200001 if failure == 'downgrade' else 100005)
    assert stable.read_bytes() == b'previous usable binary'


def test_verified_update_replaces_alias_only_after_verification(tmp_path):
    source = tmp_path / 'download.apk'
    source.write_bytes(b'fixture')
    directory = tmp_path / 'alias'
    def verify(*args):
        assert not directory.exists()
        return {'verified': True}
    sync.replace_binary(source, directory, manifest(), verify_binary=verify)
    assert (directory / 'wayday-navigation-test.apk').read_bytes() == b'fixture'
    assert (directory / 'wayday-navigation-test-200000.apk').read_bytes() == b'fixture'
