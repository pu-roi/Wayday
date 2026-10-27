"""Executable Stage 2 contract specifications, not an API or a planner.

Schema generation and cross-field validation serve future adapters and tests.
No provider is called, no itinerary is calculated and no personal data is saved.
"""

from __future__ import annotations

from datetime import datetime
import json
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "docs/wayday/evidence"
CONTRACT_VERSION = "wayday.planning.v1"
ESTIMATE_POLICY = "pilot-2026-10-27-v1"
VISIT_SECONDS = {"groceries": 1200, "wet_market": 1800, "pharmacy": 600, "bank": 1800, "office": 2700, "food": 1800, "haircut": 2700, "landmark": 900}
BUFFER_SECONDS = 300
LIMITS = {"errands": 12, "candidates_per_errand": 3, "matrix_locations": 38, "solver_seconds": 5, "calculation_seconds": 20}


def obj(properties: dict, required: list[str] | None = None, **extra) -> dict:
    return {"type": "object", "properties": properties, "required": required if required is not None else list(properties), "additionalProperties": False, **extra}


def text(maximum: int = 200) -> dict:
    return {"type": "string", "minLength": 1, "maxLength": maximum}


def ref(name: str) -> dict:
    return {"$ref": f"#/$defs/{name}"}


def nullable(value: dict) -> dict:
    return {"anyOf": [value, {"type": "null"}]}


ID = text(100)
INSTANT = {"type": "string", "format": "date-time"}
SECONDS = {"type": "integer", "minimum": 0, "maximum": 86400}
PLACE = obj({"label": text(), "latitude": {"type": "number", "minimum": -90, "maximum": 90}, "longitude": {"type": "number", "minimum": -180, "maximum": 180}, "address": nullable(text(500)), "source": obj({"provider": {"enum": ["osm", "overture", "manual"]}, "id": nullable(ID), "snapshot_date": nullable({"type": "string", "format": "date"})})})
VEHICLE = obj({"subtype": {"enum": ["pickup_light", "heavy_delivery"]}, "height_meters": {"type": "number", "exclusiveMinimum": 0, "maximum": 10}, "width_meters": {"type": "number", "exclusiveMinimum": 0, "maximum": 10}, "length_meters": {"type": "number", "exclusiveMinimum": 0, "maximum": 40}, "weight_tonnes": {"type": "number", "exclusiveMinimum": 0, "maximum": 100}, "axle_load_tonnes": nullable({"type": "number", "minimum": 0, "maximum": 40}), "axle_count": nullable({"type": "integer", "minimum": 2, "maximum": 20}), "hazmat": nullable({"type": "boolean"}), "ground_clearance_meters": nullable({"type": "number", "exclusiveMinimum": 0, "maximum": 2})})
ERRAND = obj({
    "id": ID, "original_text": text(2000), "notes": {"type": "string", "maxLength": 4000},
    "category": nullable({"enum": list(VISIT_SECONDS)}), "interpretation": {"enum": ["confirmed", "suggested", "needs_clarification"]},
    "destination": obj({"kind": {"enum": ["flexible", "fixed"]}, "place": nullable(ref("confirmed_place"))}),
    "timing": obj({"rule": {"enum": ["anytime", "at", "arrive_by", "finish_before"]}, "at": nullable(INSTANT)}),
    "optional": {"type": "boolean"}, "after_ids": {"type": "array", "items": ID, "maxItems": 11, "uniqueItems": True},
    "visit_seconds": {"type": "integer", "minimum": 1, "maximum": 28800}, "visit_source": {"enum": ["user", "category_default"]},
    "buffer_seconds": {"type": "integer", "minimum": 0, "maximum": 3600}, "estimate_policy": {"const": ESTIMATE_POLICY},
})
DAY = obj({
    "kind": {"const": "day_input"}, "contract_version": {"const": CONTRACT_VERSION}, "request_id": ID,
    "input_revision": {"type": "integer", "minimum": 0}, "operation": {"enum": ["plan", "replan"]},
    "plan_date": {"type": "string", "format": "date"}, "timezone": {"const": "Asia/Manila"},
    "start": nullable(ref("confirmed_place")), "end": nullable(ref("confirmed_place")),
    "departure": INSTANT, "final_deadline": INSTANT,
    "profile": {"enum": ["walking", "biking", "motorcycle", "sedan", "truck"]}, "vehicle": nullable(ref("vehicle")),
    "errands": {"type": "array", "minItems": 1, "maxItems": LIMITS["errands"], "items": ref("errand")},
    "replan": nullable(obj({"previous_plan_id": ID, "current_place": ref("confirmed_place"), "now": INSTANT, "completed": {"type": "array", "maxItems": 12, "items": obj({"errand_id": ID, "completed_at": INSTANT, "place": ref("confirmed_place")})}})),
})
ISSUE = obj({"code": text(80), "message": text(500), "errand_id": nullable(ID), "field": nullable(text(120))})
HOURS = obj({"state": {"enum": ["known", "unknown", "user_corrected"]}, "source": nullable(text(500)), "snapshot_date": nullable({"type": "string", "format": "date"}), "intervals": {"type": "array", "maxItems": 10, "items": obj({"opens": INSTANT, "closes": INSTANT})}})
STOP = obj({"errand_id": ID, "place": ref("confirmed_place"), "qualification_reason": text(500), "arrival": INSTANT, "service_start": INSTANT, "service_end": INSTANT, "departure": INSTANT, "visit_seconds": SECONDS, "buffer_seconds": SECONDS, "visit_source": {"enum": ["user", "category_default"]}, "hours": ref("hours")})
PLAN = obj({
    "id": ID, "selected_stops": {"type": "array", "maxItems": 12, "items": ref("stop")},
    "omissions": {"type": "array", "maxItems": 12, "items": obj({"errand_id": ID, "reason": text(500)})},
    "final_arrival": INSTANT, "travel_seconds": SECONDS, "travel_meters": {"type": "number", "minimum": 0},
    "geometry": obj({"type": {"const": "LineString"}, "coordinates": {"type": "array", "minItems": 2, "maxItems": 20000, "items": {"type": "array", "prefixItems": [{"type": "number", "minimum": -180, "maximum": 180}, {"type": "number", "minimum": -90, "maximum": 90}], "minItems": 2, "maxItems": 2}}}),
    "completed": {"type": "array", "maxItems": 12, "items": obj({"errand_id": ID, "completed_at": INSTANT, "place": ref("confirmed_place")})},
    "warnings": {"type": "array", "items": ref("issue"), "maxItems": 100},
    "provenance": obj({"engine_version": ID, "graph_id": ID, "catalog_id": ID, "source_snapshot": INSTANT, "estimate_policy": {"const": ESTIMATE_POLICY}, "traffic": {"const": "none"}, "ground_clearance_verified": {"const": False}, "restriction_coverage": {"const": "incomplete"}}),
    "solver": obj({"termination": {"enum": ["completed", "time_limit_feasible"]}, "globally_optimal": {"const": False}}),
})
RESULT = obj({"kind": {"const": "planning_result"}, "contract_version": {"const": CONTRACT_VERSION}, "request_id": ID, "input_revision": {"type": "integer", "minimum": 0}, "calculated_at": INSTANT,
    "status": {"enum": ["feasible", "provisional", "invalid_input", "needs_clarification", "no_candidates", "no_route", "conflict", "timeout", "unavailable", "unsupported_profile"]}, "issues": {"type": "array", "maxItems": 100, "items": ref("issue")}, "plan": nullable(ref("plan_snapshot"))})
SCHEMA = {"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "urn:wayday:planning:v1", "title": "Wayday pilot planning contract v1", "oneOf": [ref("day_input"), ref("planning_result")], "$defs": {"confirmed_place": PLACE, "vehicle": VEHICLE, "errand": ERRAND, "day_input": DAY, "issue": ISSUE, "hours": HOURS, "stop": STOP, "plan_snapshot": PLAN, "planning_result": RESULT}}
VALIDATOR = Draft202012Validator(SCHEMA, format_checker=FormatChecker())


def instant(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.utcoffset() is None or parsed.utcoffset().total_seconds() != 28800:
        raise ValueError("Pilot local timestamps require explicit +08:00 offset")
    return parsed


def validate_input(payload: dict) -> None:
    VALIDATOR.validate(payload)
    if payload["kind"] != "day_input":
        raise ValueError("Expected day_input")
    departure, deadline = instant(payload["departure"]), instant(payload["final_deadline"])
    if departure.date().isoformat() != payload["plan_date"] or deadline.date() != departure.date() or deadline <= departure:
        raise ValueError("v1 requires departure and later final deadline on the same explicit local date")
    if (payload["profile"] == "truck") != (payload["vehicle"] is not None):
        raise ValueError("Truck requires explicit subtype/vehicle parameters; other profiles have no truck vehicle")
    if payload["vehicle"] and payload["vehicle"]["subtype"] == "heavy_delivery" and any(payload["vehicle"][key] is None for key in ["axle_load_tonnes", "axle_count", "hazmat"]):
        raise ValueError("Heavy delivery requires explicit axle and hazardous-material values")
    errands = {item["id"]: item for item in payload["errands"]}
    if len(errands) != len(payload["errands"]):
        raise ValueError("Duplicate errand IDs")
    for errand in errands.values():
        destination = errand["destination"]
        if destination["kind"] == "flexible" and destination["place"] is not None:
            raise ValueError("Flexible destinations cannot silently retain a fixed place")
        timing = errand["timing"]
        if (timing["rule"] == "anytime") != (timing["at"] is None):
            raise ValueError("Anytime has no appointment; timed rules require one")
        if timing["at"] and instant(timing["at"]).date() != departure.date():
            raise ValueError("Timed errand must use the explicit planning date")
        if errand["visit_source"] == "category_default" and (errand["category"] not in VISIT_SECONDS or errand["visit_seconds"] != VISIT_SECONDS[errand["category"]] or errand["buffer_seconds"] != BUFFER_SECONDS):
            raise ValueError("Category default must match the versioned policy; preserve overrides as user values")
        if any(item not in errands for item in errand["after_ids"]):
            raise ValueError("Unknown dependency ID")
    visited, active = set(), set()
    def visit(key: str):
        if key in active:
            raise ValueError("Dependency cycle")
        if key in visited:
            return
        active.add(key)
        for dependency in errands[key]["after_ids"]:
            visit(dependency)
        active.remove(key)
        visited.add(key)
    for key in errands:
        visit(key)
    replan = payload["replan"]
    if (payload["operation"] == "replan") != (replan is not None):
        raise ValueError("Replan context must match operation")
    if replan:
        now = instant(replan["now"])
        if now != departure or payload["start"] != replan["current_place"]:
            raise ValueError("Replan starts at the confirmed current place/time")
        completed = [item["errand_id"] for item in replan["completed"]]
        if len(set(completed)) != len(completed) or any(key not in errands for key in completed):
            raise ValueError("Invalid completed history")
        if any(instant(item["completed_at"]) > now for item in replan["completed"]):
            raise ValueError("Completed history cannot occur after now")


def validate_result(payload: dict, request: dict) -> None:
    VALIDATOR.validate(payload)
    if payload["status"] != "invalid_input":
        validate_input(request)
    if payload["kind"] != "planning_result" or payload["request_id"] != request["request_id"] or payload["input_revision"] != request["input_revision"]:
        raise ValueError("Result does not match the submitted input revision")
    success = payload["status"] in {"feasible", "provisional"}
    plan = payload["plan"]
    if success != (plan is not None):
        raise ValueError("Only accepted feasible/provisional outcomes carry a plan")
    if not success:
        if not payload["issues"]:
            raise ValueError("Failure/clarification needs actionable issues")
        return
    errands = {item["id"]: item for item in request["errands"]}
    if request["start"] is None or request["end"] is None:
        raise ValueError("Successful plan requires confirmed endpoints")
    if any(item["interpretation"] != "confirmed" or (item["category"] is None and item["destination"]["kind"] == "flexible") for item in errands.values()):
        raise ValueError("Unconfirmed interpretation requires clarification")
    completed = request["replan"]["completed"] if request["replan"] else []
    if plan["completed"] != completed:
        raise ValueError("Replanning must preserve completed history exactly")
    completed_ids = {item["errand_id"] for item in completed}
    selected = [stop["errand_id"] for stop in plan["selected_stops"]]
    omitted = [item["errand_id"] for item in plan["omissions"]]
    if len(set(selected)) != len(selected) or len(set(omitted)) != len(omitted) or set(selected) & (set(omitted) | completed_ids) or set(omitted) & completed_ids or set(selected) | set(omitted) | completed_ids != set(errands):
        raise ValueError("Each unfinished errand needs one selected branch or explicit omission")
    if any(not errands[key]["optional"] for key in omitted):
        raise ValueError("Mandatory errands cannot be omitted")
    previous = instant(request["departure"])
    done = set(completed_ids)
    unknown_hours = False
    for stop in plan["selected_stops"]:
        errand = errands[stop["errand_id"]]
        if not set(errand["after_ids"]) <= done:
            raise ValueError("Selected dependent requires every prerequisite, including optional prerequisites")
        if errand["destination"]["kind"] == "fixed" and stop["place"] != errand["destination"]["place"]:
            raise ValueError("Fixed branch override must be preserved")
        arrival, start, end, leave = [instant(stop[key]) for key in ["arrival", "service_start", "service_end", "departure"]]
        if not previous <= arrival <= start < end <= leave or (end - start).total_seconds() != errand["visit_seconds"] or (leave - end).total_seconds() != errand["buffer_seconds"] or stop["visit_seconds"] != errand["visit_seconds"] or stop["buffer_seconds"] != errand["buffer_seconds"] or stop["visit_source"] != errand["visit_source"]:
            raise ValueError("Schedule must preserve explicit visit/buffer values and chronological order")
        timing = errand["timing"]
        at = instant(timing["at"]) if timing["at"] else None
        if (timing["rule"] == "at" and start != at) or (timing["rule"] == "arrive_by" and arrival > at) or (timing["rule"] == "finish_before" and leave > at):
            raise ValueError("Arrival/start/completion timing meanings differ")
        hours = stop["hours"]
        if hours["state"] == "unknown":
            unknown_hours = True
            if hours["intervals"]:
                raise ValueError("Unknown hours cannot invent intervals")
        elif not hours["source"] or not hours["snapshot_date"] or not any(instant(interval["opens"]) <= start and leave <= instant(interval["closes"]) for interval in hours["intervals"]):
            raise ValueError("Known/corrected hours need provenance and must cover the full visit and buffer")
        previous = leave
        done.add(stop["errand_id"])
    if not previous <= instant(plan["final_arrival"]) <= instant(request["final_deadline"]):
        raise ValueError("Final destination deadline must hold")
    if unknown_hours and (payload["status"] != "provisional" or not any(issue["code"] == "check_hours" for issue in plan["warnings"])):
        raise ValueError("Unknown hours require a provisional outcome and check-hours notice")


if __name__ == "__main__":
    Draft202012Validator.check_schema(SCHEMA)
    (EVIDENCE / "planning-contract-v1.schema.json").write_text(json.dumps(SCHEMA, indent=2) + "\n", encoding="utf-8")
    print("Wrote the contract schema; no application/API implementation created")
