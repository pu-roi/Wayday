"""Create clearly synthetic examples for contract review; no travel calculation."""

from copy import deepcopy
import json

from planning_contract import BUFFER_SECONDS, CONTRACT_VERSION, ESTIMATE_POLICY, EVIDENCE, VISIT_SECONDS, validate_input, validate_result


def place(label="Synthetic start", latitude=14.58, longitude=121.06):
    return {"label": label, "latitude": latitude, "longitude": longitude, "address": None, "source": {"provider": "manual", "id": None, "snapshot_date": None}}


def errand(key="medicine", category="pharmacy", original="Bumili ng gamot"):
    return {"id": key, "original_text": original, "notes": "", "category": category, "interpretation": "confirmed", "destination": {"kind": "flexible", "place": None}, "timing": {"rule": "anytime", "at": None}, "optional": False, "after_ids": [], "visit_seconds": VISIT_SECONDS[category], "visit_source": "category_default", "buffer_seconds": BUFFER_SECONDS, "estimate_policy": ESTIMATE_POLICY}


def request():
    return {"kind": "day_input", "contract_version": CONTRACT_VERSION, "request_id": "synthetic-request-1", "input_revision": 7, "operation": "plan", "plan_date": "2026-10-27", "timezone": "Asia/Manila", "start": place(), "end": place("Synthetic finish", 14.59, 121.07), "departure": "2026-10-27T08:00:00+08:00", "final_deadline": "2026-10-27T18:00:00+08:00", "profile": "walking", "vehicle": None, "errands": [errand()], "replan": None}


def issue(code, message, errand_id=None, field=None):
    return {"code": code, "message": message, "errand_id": errand_id, "field": field}


def result(req, status="provisional"):
    return {"kind": "planning_result", "contract_version": CONTRACT_VERSION, "request_id": req["request_id"], "input_revision": req["input_revision"], "calculated_at": "2026-10-27T07:00:00Z", "status": status, "issues": [], "plan": None}


def successful(req):
    output = result(req)
    item = req["errands"][0]
    chosen = item["destination"]["place"] or place("Synthetic pharmacy branch", 14.585, 121.065)
    output["plan"] = {
        "id": "synthetic-plan-1",
        "selected_stops": [{"errand_id": item["id"], "place": chosen, "qualification_reason": "Synthetic pharmacy category fixture; no inventory claim", "arrival": "2026-10-27T08:05:00+08:00", "service_start": "2026-10-27T08:05:00+08:00", "service_end": "2026-10-27T08:15:00+08:00", "departure": "2026-10-27T08:20:00+08:00", "visit_seconds": item["visit_seconds"], "buffer_seconds": item["buffer_seconds"], "visit_source": item["visit_source"], "hours": {"state": "unknown", "source": None, "snapshot_date": None, "intervals": []}}],
        "omissions": [], "final_arrival": "2026-10-27T08:25:00+08:00", "travel_seconds": 600, "travel_meters": 1000,
        "geometry": {"type": "LineString", "coordinates": [[121.06, 14.58], [121.065, 14.585], [121.07, 14.59]]},
        "completed": [], "warnings": [issue("check_hours", "Opening hours are unknown; check before visiting", item["id"]), issue("synthetic_fixture", "All positions, travel times and business identities are test-only")],
        "provenance": {"engine_version": "synthetic", "graph_id": "synthetic-matrix-v1", "catalog_id": "synthetic-places-v1", "source_snapshot": "2026-10-27T00:00:00Z", "estimate_policy": ESTIMATE_POLICY, "traffic": "none", "ground_clearance_verified": False, "restriction_coverage": "incomplete"},
        "solver": {"termination": "completed", "globally_optimal": False},
    }
    return output


def examples():
    cases = []
    base = request()
    cases.append({"name": "automatic_pharmacy_with_unknown_hours", "request": base, "response": successful(base)})
    fixed = deepcopy(base)
    fixed["errands"][0]["destination"] = {"kind": "fixed", "place": place("Synthetic user-selected branch", 14.585, 121.065)}
    cases.append({"name": "explicit_branch_override", "request": fixed, "response": successful(fixed)})
    duration = deepcopy(base)
    duration["errands"][0].update({"visit_seconds": 1200, "visit_source": "user"})
    duration_output = successful(duration)
    duration_output["plan"]["selected_stops"][0].update({"service_end": "2026-10-27T08:25:00+08:00", "departure": "2026-10-27T08:30:00+08:00"})
    duration_output["plan"]["final_arrival"] = "2026-10-27T08:35:00+08:00"
    cases.append({"name": "editable_visit_duration", "request": duration, "response": duration_output})
    unclear = deepcopy(base)
    unclear["errands"][0].update({"original_text": "lunch with her after", "category": None, "interpretation": "needs_clarification", "visit_seconds": 1800, "visit_source": "user"})
    clarification = result(unclear, "needs_clarification")
    clarification["issues"] = [issue("ambiguous_errand", "Confirm destination/category and what 'after' refers to", "medicine", "errands.medicine")]
    cases.append({"name": "unclear_errand_preserves_original_text", "request": unclear, "response": clarification})
    optional = deepcopy(base)
    coffee = errand("coffee", "food", "Coffee if there is time")
    coffee["optional"] = True
    coffee["after_ids"] = ["medicine"]
    optional["errands"].append(coffee)
    optional_output = successful(optional)
    optional_output["plan"]["omissions"] = [{"errand_id": "coffee", "reason": "Synthetic example: insufficient time for the optional stop"}]
    cases.append({"name": "optional_omission_with_dependency", "request": optional, "response": optional_output})
    timed = deepcopy(base)
    timed["errands"][0]["timing"] = {"rule": "at", "at": "2026-10-27T08:10:00+08:00"}
    timed_output = successful(timed)
    timed_output["plan"]["selected_stops"][0].update({"service_start": "2026-10-27T08:10:00+08:00", "service_end": "2026-10-27T08:20:00+08:00", "departure": "2026-10-27T08:25:00+08:00"})
    timed_output["plan"]["final_arrival"] = "2026-10-27T08:30:00+08:00"
    cases.append({"name": "appointment_waiting", "request": timed, "response": timed_output})
    for status, code in [("no_candidates", "no_matching_category"), ("no_route", "unreachable_leg"), ("conflict", "proven_deadline_conflict"), ("timeout", "solve_time_limit"), ("unavailable", "routing_service_unavailable"), ("unsupported_profile", "unsupported_vehicle_capability")]:
        failure = result(base, status)
        failure["issues"] = [issue(code, f"Synthetic {status} example; retain the last saved plan")]
        cases.append({"name": status, "request": deepcopy(base), "response": failure})
    missing = deepcopy(base)
    missing["start"] = None
    failure = result(missing, "needs_clarification")
    failure["issues"] = [issue("missing_start", "Choose a confirmed starting point", field="start")]
    cases.append({"name": "missing_endpoint", "request": missing, "response": failure})
    replan = deepcopy(base)
    completed_item = errand("earlier", "bank", "Synthetic completed errand")
    replan["errands"].append(completed_item)
    replan["operation"] = "replan"
    history = [{"errand_id": "earlier", "completed_at": "2026-10-27T07:55:00+08:00", "place": place("Synthetic completed bank")}]
    replan["replan"] = {"previous_plan_id": "synthetic-previous-plan", "current_place": replan["start"], "now": replan["departure"], "completed": history}
    replan_output = successful(replan)
    replan_output["plan"]["completed"] = history
    cases.append({"name": "replan_preserves_completed_history", "request": replan, "response": replan_output})
    return cases


if __name__ == "__main__":
    cases = examples()
    for case in cases:
        validate_input(case["request"])
        validate_result(case["response"], case["request"])
    output = {"notice": "Synthetic contract fixtures only: no real business, road geometry, route time or optimizer result is asserted", "cases": cases}
    (EVIDENCE / "planning-contract-v1.examples.json").write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(f"Validated and wrote {len(cases)} synthetic contract examples")
