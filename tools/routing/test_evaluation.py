"""Network-free checks for the evaluation's data-integrity boundaries."""

import unittest

from prepare_graph import BOUNDS, PILOT, extract_summary, road_query
from evaluate_routes import matrix_summary


class ExtractTests(unittest.TestCase):
    def test_graph_contains_pilot_with_documented_buffer(self):
        self.assertLess(BOUNDS[0], PILOT[0])
        self.assertLess(BOUNDS[1], PILOT[1])
        self.assertGreater(BOUNDS[2], PILOT[2])
        self.assertGreater(BOUNDS[3], PILOT[3])

    def test_rejects_swapped_or_excessive_bounds(self):
        for bounds in [[121, 14, 120, 15], [121, 14, 122, 15], [181, 14, 182, 15]]:
            with self.subTest(bounds=bounds), self.assertRaises(ValueError):
                road_query(bounds)

    def test_retains_restrictions_and_member_nodes(self):
        query = road_query(BOUNDS)
        self.assertIn('rel(bw)["type"="restriction"]', query)
        self.assertIn('(._;>;)', query)

    def test_rejects_partial_or_empty_extract(self):
        for raw in [b'<osm><remark>runtime error: timeout</remark></osm>', b'<osm/>']:
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                extract_summary(raw)

    def test_missing_restrictions_remain_missing(self):
        summary = extract_summary(b'<osm><node id="1"/><way id="2"><tag k="highway" v="residential"/><tag k="hgv" v="no"/></way></osm>')
        self.assertEqual(summary['highway_tag_counts'], {'hgv': 1})
        self.assertNotIn('maxheight', summary['highway_tag_counts'])


class MatrixTests(unittest.TestCase):
    def test_null_unreachable_cells_are_not_zero_time_legs(self):
        matrix = {"units": "kilometers", "sources_to_targets": [[{"time": 0, "distance": 0}, {"time": None, "distance": None}], [{"time": 80, "distance": 1.2}, {"time": 0, "distance": 0}]]}
        summary = matrix_summary(matrix, 2)
        self.assertEqual(summary['unreachable_cells'], 1)
        self.assertEqual(summary['asymmetric_pairs'], 1)
        self.assertIsNone(summary['cells_row_major'][0][1]['time'])

    def test_rejects_incomplete_units_or_partial_cells(self):
        for matrix in [
            {"units": "miles", "sources_to_targets": [[{"time": 0, "distance": 0}]]},
            {"units": "kilometers", "sources_to_targets": [[]]},
            {"units": "kilometers", "sources_to_targets": [[{"time": None, "distance": 0}]]},
            {"units": "kilometers", "sources_to_targets": [[{"time": -1, "distance": 0}]]},
        ]:
            with self.subTest(matrix=matrix), self.assertRaises(ValueError):
                matrix_summary(matrix, 1)


if __name__ == '__main__':
    unittest.main()
