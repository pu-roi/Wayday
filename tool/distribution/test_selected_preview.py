import copy
import hashlib
import zipfile

import pytest
from deliver_website_preview import verify_source, extract


def test_selected_artifact_needs_successful_original_verification_and_exact_provenance():
    selected = {'commit': 'a' * 40, 'artifactId': 10, 'runId': 20, 'artifactSha256': 'b' * 64}
    run = {'head_sha': selected['commit'], 'head_branch': 'main', 'event': 'push'}
    artifact = {'expired': False, 'id': 10, 'name': 'release-candidates',
                'workflow_run': {'id': 20}, 'digest': 'sha256:' + 'b' * 64}
    jobs = [{'name': n, 'conclusion': 'success'} for n in
            ['website', 'api', 'mobile', 'native', 'release-contract', 'release-candidates']]
    verify_source(run, artifact, jobs, selected)
    for patch in [{'expired': True}, {'digest': 'sha256:' + 'c' * 64}, {'workflow_run': {'id': 21}}]:
        with pytest.raises(ValueError): verify_source(run, {**artifact, **patch}, jobs, selected)
    with pytest.raises(ValueError): verify_source({**run, 'head_branch': 'another'}, artifact, jobs, selected)
    failed = copy.deepcopy(jobs)
    failed[3]['conclusion'] = 'failure'
    with pytest.raises(ValueError): verify_source(run, artifact, failed, selected)


def test_selected_archive_rejects_changed_bytes_or_unexpected_paths_before_extraction(tmp_path):
    archive = tmp_path / 'artifact.zip'
    with zipfile.ZipFile(archive, 'w') as z:
        for name in ['wayday.apk', 'wayday-test.apk', 'public-verification.json', 'test-verification.json']:
            z.writestr(name, 'fixture')
    selected = {'artifactSha256': hashlib.sha256(archive.read_bytes()).hexdigest()}
    out = tmp_path / 'out'
    out.mkdir()
    extract(archive, out, selected)
    assert len(list(out.iterdir())) == 4
    with pytest.raises(ValueError): extract(archive, out, {'artifactSha256': 'a' * 64})
    with zipfile.ZipFile(archive, 'a') as z: z.writestr('../outside', 'fixture')
    selected['artifactSha256'] = hashlib.sha256(archive.read_bytes()).hexdigest()
    with pytest.raises(ValueError): extract(archive, out, selected)
    assert not (tmp_path / 'outside').exists()
