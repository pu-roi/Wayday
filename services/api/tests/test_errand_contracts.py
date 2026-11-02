import copy
import json
import pytest
from wayday_api.gateway.config import GatewayFailure
from wayday_api.gateway.validation import CONTRACT_VERSIONS, interpretation


@pytest.mark.parametrize('version', ['d66-v1', 'errand-v2'])
@pytest.mark.parametrize('purpose', ['interpretation', 'clarification'])
def test_both_client_generations_keep_exact_pinned_contracts(version, purpose):
    content = ([{'id': 'fixture', 'title': 'Laundry', 'notes': ''}]
               if purpose == 'interpretation' else
               {'facts': {'id': 'fixture'}, 'previousAnswers': [], 'answer': 'Dry cleaning'})
    request = copy.deepcopy(CONTRACT_VERSIONS[version][purpose])
    request['contents'] = [{'role': 'user', 'parts': [{'text': json.dumps(content)}]}]
    body = {'purpose': purpose, 'contractVersion': version, 'request': request}
    assert interpretation(body) == request
    changed = copy.deepcopy(body)
    changed['request']['systemInstruction']['parts'][0]['text'] += ' altered'
    with pytest.raises(GatewayFailure):
        interpretation(changed)
    changed = copy.deepcopy(body)
    changed['contractVersion'] = 'errand-v2' if version == 'd66-v1' else 'd66-v1'
    with pytest.raises(GatewayFailure):
        interpretation(changed)
