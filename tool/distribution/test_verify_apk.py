import zipfile
import json

import pytest
import verify_apk as apk


@pytest.mark.parametrize('changed', [None, 'package', 'version', 'profile', 'source', 'certificate', 'logo', 'registered_certificate'])
def test_actual_binary_metadata_signature_and_logo_must_match(monkeypatch, tmp_path, changed):
    commit, cert = 'a' * 40, 'b' * 64
    registry = tmp_path / 'registered.json'
    registry.write_text(json.dumps({'signingSha256': 'c' * 64 if changed == 'registered_certificate' else cert}))
    monkeypatch.setattr(apk, 'QUALIFICATION', registry)
    digest = apk.config_fingerprint(apk.release_profile())
    values = {'package': 'dev.wayday.wayday.publictest', 'version': '200000', 'profile': digest,
              'source': commit, 'certificate': cert}
    if changed and changed not in ('logo', 'registered_certificate'): values[changed] = 'wrong'
    xml = f'''<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="{values['package']}" android:versionCode="{values['version']}">
      <uses-sdk android:minSdkVersion="24" android:targetSdkVersion="36" />
      <application android:label="Wayday Test">
        <meta-data android:name="wayday.sourceCommit" android:value="{values['source']}" />
        <meta-data android:name="wayday.releaseProfile" android:value="{values['profile']}" />
      </application></manifest>'''
    monkeypatch.setattr(apk, 'command', lambda *args: xml if 'manifest' in args else 'Signer #1 certificate SHA-256 digest: ' + values['certificate'])
    path = tmp_path / 'test.apk'
    with zipfile.ZipFile(path, 'w') as archive:
        archive.writestr('assets/flutter_assets/assets/branding/wayday-logo.png',
                         b'wrong' if changed == 'logo' else (apk.ROOT / 'apps/mobile/assets/branding/wayday-logo.png').read_bytes())
    if changed:
        with pytest.raises(ValueError): apk.verify(path, 'test', 200000, commit, cert, sdk=tmp_path)
    else:
        assert apk.verify(path, 'test', 200000, commit, cert, sdk=tmp_path)['package'] == 'dev.wayday.wayday.publictest'
