from copy import deepcopy

import pytest
from wayday_api.gateway.config import GatewayFailure
from wayday_api.gateway.navigation import route_request, route_response


def request():
    return {"points": [[14.5, 121.0], [14.501, 121.001]], "profile": "walk"}


def response():
    return {"features": [{"geometry": {"type": "MultiLineString", "coordinates": [
        [[121.0, 14.5], [121.001, 14.501]]]}, "properties": {
        "distance_units": "meters", "time": 20, "distance": 140,
        "legs": [{"distance": 140, "time": 20, "steps": [
            {"from_index": 0, "to_index": 1, "distance": 140, "time": 20,
             "instruction": {"text": "Continue north."}},
            {"from_index": 1, "to_index": 1, "distance": 0, "time": 0,
             "instruction": {"text": "You have arrived."}}]}]}}]}


def test_ordered_request_has_no_matrix_or_optimization():
    params, credits = route_request(request())
    assert params["waypoints"] == "14.5,121.0|14.501,121.001"
    assert params["mode"] == "walk"
    assert params["optimize_stops"] == "false"
    assert params["traffic"] == "free_flow"
    assert credits >= 1
    assert "route_details" not in params["details"]


def test_motorized_routes_request_approximate_not_live_traffic():
    body = request()
    body["profile"] = "motor"
    params, _ = route_request(body)
    assert params["mode"] == "motorcycle"
    assert params["traffic"] == "approximated"


@pytest.mark.parametrize("change", ["nan", "mode", "many", "extra", "truck"])
def test_invalid_or_unqualified_requests_never_dispatch(change):
    body = request()
    if change == "nan": body["points"][0][0] = float("nan")
    if change == "mode": body["profile"] = "bike"
    if change == "many": body["points"] *= 14
    if change == "extra": body["url"] = "https://example.com"
    if change == "truck": body["profile"] = "truck"
    with pytest.raises(GatewayFailure): route_request(body)


def test_response_preserves_geometry_and_instructions():
    result = route_response(response(), request()["points"])
    assert result["legs"][0]["coordinates"] == [[14.5, 121.0], [14.501, 121.001]]
    assert result["legs"][0]["steps"][0]["instruction"] == "Continue north."


@pytest.mark.parametrize("change", ["index", "units", "missing_leg", "nan", "gap", "empty", "far"])
def test_malformed_routes_are_rejected_without_substitute(change):
    data = deepcopy(response())
    feature = data["features"][0]
    if change == "index": feature["properties"]["legs"][0]["steps"][0]["to_index"] = 50
    if change == "units": feature["properties"]["distance_units"] = "miles"
    if change == "missing_leg": feature["properties"]["legs"] = []
    if change == "nan": feature["geometry"]["coordinates"][0][0][0] = float("nan")
    if change == "gap": feature["properties"]["legs"][0]["steps"][0]["from_index"] = 1
    if change == "empty": data["features"] = []
    if change == "far": feature["geometry"]["coordinates"][0][1] = [0, 0]
    with pytest.raises(GatewayFailure): route_response(data, request()["points"])
