from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[2]


def test_publication_is_ordered_after_compatible_gateway_and_both_candidates():
    body = yaml.safe_load((ROOT / '.github/workflows/quality.yml').read_text())
    jobs = body['jobs']
    assert set(jobs['gateway']['needs']) == {'website', 'api', 'mobile', 'native', 'release-contract'}
    assert jobs['gateway']['uses'] == './.github/workflows/deploy-gateway.yml'
    assert jobs['release-candidates']['needs'] == ['gateway']
    assert jobs['publish-apk']['needs'] == ['release-candidates']
    assert jobs['publish-website']['needs'] == ['publish-apk']
    assert body['concurrency']['cancel-in-progress'] is False
    script = '\n'.join(s.get('run', '') for s in jobs['release-candidates']['steps'])
    assert 'for channel in public test' in script
    assert 'verify_apk.py' in script and 'check_navigation_reflection.py' in script
    assert 'release.py gateway' in script
    assert 'qualify' not in script  # Candidates remain available before physical qualification.
    publication = '\n'.join(s.get('run', '') for s in jobs['publish-apk']['steps'])
    assert 'publish_release.py' in publication
    assert "github.ref == 'refs/heads/main'" in jobs['gateway']['if']


def test_gateway_deployment_is_reusable_and_reports_partial_stages():
    body = yaml.safe_load((ROOT / '.github/workflows/deploy-gateway.yml').read_text())
    steps = body['jobs']['deploy']['steps']
    script = '\n'.join(s.get('run', '') for s in steps)
    assert 'deploy_gateway.py' in script
    assert '@$digest' in script
    assert any(s.get('if') == 'always()' and s.get('with', {}).get('name') == 'gateway-delivery' for s in steps)
