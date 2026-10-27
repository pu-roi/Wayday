"""Contract acceptance fixtures; these tests do not execute a route solver."""

from copy import deepcopy
import json
import unittest

from jsonschema import ValidationError

from contract_examples import examples, errand, issue, place, request, successful
from planning_contract import BUFFER_SECONDS, EVIDENCE, SCHEMA, VISIT_SECONDS, validate_input, validate_result


class ContractTests(unittest.TestCase):
    def reject_input(self, payload):
        with self.assertRaises((ValueError, ValidationError)):
            validate_input(payload)

    def reject_result(self, result, payload):
        with self.assertRaises((ValueError, ValidationError)):
            validate_result(result, payload)

    def test_all_authored_acceptance_examples(self):
        for case in examples():
            with self.subTest(case=case['name']):
                validate_result(case['response'], case['request'])

    def test_committed_schema_and_examples_match_executable_spec(self):
        self.assertEqual(json.loads((EVIDENCE/'planning-contract-v1.schema.json').read_text()), SCHEMA)
        self.assertEqual(json.loads((EVIDENCE/'planning-contract-v1.examples.json').read_text())['cases'], examples())

    def test_rejects_swapped_coordinates_unknown_fields_and_oversized_input(self):
        for key in ['coordinates', 'field', 'count']:
            payload = request()
            if key == 'coordinates':
                payload['start']['latitude'], payload['start']['longitude'] = 121.06, 14.58
            elif key == 'field':
                payload['secret_engine_option'] = 'ignore_access'
            else:
                payload['errands'] = [errand(str(index)) for index in range(13)]
            self.reject_input(payload)

    def test_midnight_is_not_implicitly_an_overnight_deadline(self):
        for deadline in ['2026-10-27T07:00:00+08:00', '2026-10-28T01:00:00+08:00', '2026-10-27T18:00:00Z']:
            payload = request()
            payload['final_deadline'] = deadline
            self.reject_input(payload)

    def test_user_duration_is_preserved_and_defaults_are_versioned(self):
        payload = request()
        payload['errands'][0]['visit_seconds'] = 1200
        self.reject_input(payload)
        payload['errands'][0]['visit_source'] = 'user'
        validate_input(payload)
        output = successful(payload)
        self.reject_result(output, payload)  # Fixture still allocates only ten minutes.

    def test_cycles_unknown_ids_and_duplicate_ids_rejected(self):
        for mode in ['cycle', 'unknown', 'duplicate']:
            payload = request()
            if mode == 'cycle': payload['errands'][0]['after_ids'] = ['medicine']
            elif mode == 'unknown': payload['errands'][0]['after_ids'] = ['missing']
            else: payload['errands'].append(deepcopy(payload['errands'][0]))
            self.reject_input(payload)

    def test_truck_subtypes_require_explicit_relevant_parameters(self):
        payload = request()
        payload['profile'] = 'truck'
        self.reject_input(payload)
        vehicle = {'subtype':'pickup_light', 'height_meters':1.85, 'width_meters':1.8, 'length_meters':5.1, 'weight_tonnes':2.1, 'axle_load_tonnes':None, 'axle_count':None, 'hazmat':None, 'ground_clearance_meters':None}
        payload['vehicle'] = vehicle
        validate_input(payload)
        vehicle['subtype'] = 'heavy_delivery'
        self.reject_input(payload)
        vehicle.update({'axle_load_tonnes':6, 'axle_count':2, 'hazmat':False})
        validate_input(payload)

    def test_unknown_hours_cannot_be_confirmed_open(self):
        payload = request()
        output = successful(payload)
        output['status'] = 'feasible'
        self.reject_result(output, payload)
        output['status'] = 'provisional'
        output['plan']['warnings'] = []
        self.reject_result(output, payload)

    def test_fixed_place_with_explicit_duration_does_not_need_an_inferred_category(self):
        payload = request()
        payload['errands'][0].update({'category':None, 'visit_source':'user'})
        payload['errands'][0]['destination'] = {'kind':'fixed', 'place':place('Synthetic explicit appointment')}
        output = successful(payload)
        validate_result(output,payload)

    def test_known_or_corrected_hours_cover_whole_visit_and_buffer(self):
        payload = request()
        output = successful(payload)
        hours = {'state':'user_corrected', 'source':'User-confirmed appointment fixture', 'snapshot_date':'2026-10-27', 'intervals':[{'opens':'2026-10-27T08:00:00+08:00','closes':'2026-10-27T08:20:00+08:00'}]}
        output['plan']['selected_stops'][0]['hours'] = hours
        validate_result(output, payload)
        hours['intervals'][0]['closes'] = '2026-10-27T08:19:00+08:00'
        self.reject_result(output, payload)

    def test_fixed_place_mandatory_omission_and_stale_revision_rejected(self):
        for mode in ['fixed', 'mandatory', 'stale']:
            payload = request()
            output = successful(payload)
            if mode == 'fixed': payload['errands'][0]['destination'] = {'kind':'fixed','place':place('Other branch')}
            elif mode == 'mandatory':
                output['plan']['selected_stops'] = []
                output['plan']['omissions'] = [{'errand_id':'medicine','reason':'Cannot fit'}]
            else: output['input_revision'] -= 1
            self.reject_result(output, payload)

    def test_arrival_is_different_from_completion_deadline(self):
        payload = request()
        output = successful(payload)
        payload['errands'][0]['timing'] = {'rule':'arrive_by','at':'2026-10-27T08:05:00+08:00'}
        validate_result(output, payload)
        payload['errands'][0]['timing']['rule'] = 'finish_before'
        self.reject_result(output, payload)

    def test_optional_prerequisite_cannot_be_dropped_under_selected_dependent(self):
        payload = request()
        earlier = errand('earlier','bank')
        earlier['optional'] = True
        payload['errands'].append(earlier)
        payload['errands'][0]['after_ids'] = ['earlier']
        output = successful(payload)
        output['plan']['omissions'] = [{'errand_id':'earlier','reason':'Optional'}]
        self.reject_result(output, payload)

    def test_replan_preserves_completed_history_and_current_origin(self):
        case = next(case for case in examples() if case['name'] == 'replan_preserves_completed_history')
        case['response']['plan']['completed'] = []
        self.reject_result(case['response'],case['request'])
        case['request']['replan']['now'] = '2026-10-27T08:01:00+08:00'
        self.reject_input(case['request'])

    def test_timeout_never_carries_an_unvalidated_plan_or_proves_conflict(self):
        payload = request()
        output = successful(payload)
        output['status'] = 'timeout'
        self.reject_result(output,payload)
        output['status'] = 'provisional'
        output['plan']['solver']['termination'] = 'time_limit_feasible'
        validate_result(output,payload)
        output['plan']['solver']['globally_optimal'] = True
        self.reject_result(output,payload)


if __name__ == '__main__':
    unittest.main()
