"""Offline regressions for audit errors; these do not measure real POI coverage."""

import hashlib
import json
import unittest

from pilot_audit import candidates, name_matches, validate_extract


class AuditRegressionTests(unittest.TestCase):
    def test_short_agency_aliases_do_not_match_unrelated_businesses(self):
        self.assertFalse(name_matches("NBI", "Konbini Store"))
        self.assertFalse(name_matches("SSS", "Prince N' Princess School"))
        self.assertFalse(name_matches("LTO", "Calton Datx"))
        self.assertTrue(name_matches("NBI", "NBI Clearance Center"))
        self.assertTrue(name_matches("SSS", "SSS - Galleria"))
        self.assertTrue(name_matches("McDonald's", "McDonald’s"))

    def test_candidates_retain_distinct_same_brand_branches_for_manual_review(self):
        result = candidates(
            {"aliases": ["UnionBank"]},
            [
                {"type": "node", "id": 1, "lat": 14.58, "lon": 121.06,
                 "tags": {"name": "UnionBank", "branch": "Julia Vargas"}},
                {"type": "node", "id": 2, "lat": 14.59, "lon": 121.07,
                 "tags": {"name": "UnionBank", "branch": "UnionBank Plaza"}},
            ],
        )
        self.assertEqual([item["osm_id"] for item in result], ["node/1", "node/2"])

    def test_failed_query_file_cannot_be_associated_with_successful_extract(self):
        sample = b'{"samples":[]}'
        body = json.dumps({"osm3s": {"timestamp_osm_base": "2026-10-27T00:00:00Z"}, "elements": []}).encode()
        query = "[out:json];node(14,121,15,122);out;"
        manifest = {
            "query": query,
            "raw_sha256": hashlib.sha256(body).hexdigest(),
            "frozen_sample_sha256": hashlib.sha256(sample).hexdigest(),
            "osm_base_timestamp": "2026-10-27T00:00:00Z",
        }
        self.assertEqual(validate_extract(body, manifest, query, sample)["elements"], [])
        with self.assertRaisesRegex(ValueError, "Query"):
            validate_extract(body, manifest, query + "changed", sample)
        with self.assertRaisesRegex(ValueError, "hash"):
            validate_extract(body + b" ", manifest, query, sample)
        with self.assertRaisesRegex(ValueError, "Frozen"):
            validate_extract(body, manifest, query, sample + b" ")


if __name__ == "__main__":
    unittest.main()
