import copy
import hashlib
from pathlib import Path

from test_gateway import fixture_request, setup


def test_health_reports_loaded_contracts_and_effective_features_without_dispatch(setup):
    client, provider = setup
    body = client.get('/health').json()
    root = Path(__file__).parents[1] / 'src/wayday_api/gateway'
    assert body['contracts'] == {
        version: hashlib.sha256((root / filename).read_bytes()).hexdigest()
        for version, filename in [('d66-v1', 'contracts.json'), ('errand-v2', 'contracts-v2.json')]
    }
    assert body['capabilities']['alternativeNavigation'] is False
    assert body['capabilities']['dailyCeilings'] is True
    assert not provider.calls


def test_contract_errors_identify_gateway_rejection_and_never_dispatch(setup):
    client, provider = setup
    headers = {'X-Firebase-AppCheck': 'fixture-token'}
    body = fixture_request()
    body['contractVersion'] = 'future-version'
    response = client.post('/v1/interpretations', json=body, headers=headers)
    assert response.status_code == 422
    assert response.json() == {'error': {'code': 'unsupported_contract'}}
    changed = copy.deepcopy(fixture_request())
    changed['request']['generationConfig']['maxOutputTokens'] = 1
    response = client.post('/v1/interpretations', json=changed, headers=headers)
    assert response.status_code == 422
    assert response.json() == {'error': {'code': 'contract_mismatch'}}
    assert not provider.calls
