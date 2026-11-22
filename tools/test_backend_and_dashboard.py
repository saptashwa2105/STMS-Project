"""
End-to-end verification script for STMS Backend API & SQLite database.
Runs against real SQLite database (traffic.db) directly via SQLAlchemy session
and FastAPI application router.
"""
import sys
import os
import time

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

def run_tests():
    print("==================================================")
    print("Verifying STMS Backend & SQLite Engine")
    print("==================================================")

    from backend.main import app, TrafficLog, SessionLocal, Base, engine
    from sqlalchemy.orm import Session

    # 1. Verify DB connection and schema
    db: Session = SessionLocal()
    try:
        # Clear existing logs for a clean test
        db.query(TrafficLog).delete()
        db.commit()

        # Insert test records
        t1 = time.time()
        log1 = TrafficLog(
            timestamp=t1,
            north=5,
            south=4,
            east=9,
            west=2,
            current_phase="NS_GREEN",
            emergency_active=False
        )
        db.add(log1)

        t2 = t1 + 1.0
        log2 = TrafficLog(
            timestamp=t2,
            north=1,
            south=0,
            east=12,
            west=8,
            current_phase="EW_GREEN",
            emergency_active=True
        )
        db.add(log2)
        db.commit()

        # Query records
        records = db.query(TrafficLog).order_by(TrafficLog.id.desc()).limit(60).all()
        assert len(records) == 2, f"Expected 2 records, found {len(records)}"

        sorted_records = [r.to_dict() for r in reversed(records)]
        assert sorted_records[0]["north"] == 5
        assert sorted_records[1]["emergency_active"] is True
        assert sorted_records[0]["timestamp"] < sorted_records[1]["timestamp"]
        print("[PASS] SQLite CRUD operations verified on traffic.db")
        print(f"Sample Record: {sorted_records[1]}")

    finally:
        db.close()

    # 2. Test Endpoints directly via FastAPI handler functions
    from backend.main import ingest_telemetry, get_stats, health_check, post_command, get_command
    import asyncio
    from unittest.mock import AsyncMock

    # Test health check
    hc = health_check()
    assert hc["status"] == "online"
    assert "/api/command" in hc["endpoints"]["POST"]
    print("[PASS] GET / Health check endpoint:", hc)

    # Test GET /api/stats
    stats_resp = get_stats()
    import json
    stats_data = json.loads(stats_resp.body.decode())
    assert len(stats_data) == 2
    assert stats_data[0]["timestamp"] <= stats_data[1]["timestamp"]
    print(f"[PASS] GET /api/stats returned {len(stats_data)} records sorted ascending by timestamp.")

    # Test POST /api/telemetry with valid Godot payload
    class FakeRequest:
        def __init__(self, data):
            self._data = data
        async def json(self):
            return self._data

    req_valid = FakeRequest({
        "timestamp": time.time() + 2.0,
        "current_phase": "NS_YELLOW",
        "emergency_active": False,
        "lane_densities": {
            "north": 6,
            "south": 3,
            "east": 10,
            "west": 4
        }
    })
    post_resp = asyncio.run(ingest_telemetry(req_valid))
    assert post_resp.status_code == 200
    print("[PASS] POST /api/telemetry (Valid Godot JSON) -> HTTP 200:", json.loads(post_resp.body.decode()))

    # Test POST /api/telemetry with malformed payload (MUST return 400 without crashing)
    class FakeBadJsonRequest:
        async def json(self):
            raise ValueError("Malformed JSON string")

    req_bad = FakeBadJsonRequest()
    post_bad_resp = asyncio.run(ingest_telemetry(req_bad))
    assert post_bad_resp.status_code == 400
    print("[PASS] POST /api/telemetry (Malformed JSON) -> HTTP 400 Graceful:", json.loads(post_bad_resp.body.decode()))

    # 3. Test Cloud-to-Edge Remote Command Endpoints (/api/command)
    print("\n--- Testing Cloud-to-Edge Remote Command API ---")
    
    # 3a. Test FORCE_ALL_RED command dispatch
    cmd_req1 = FakeRequest({"action": "FORCE_ALL_RED"})
    res1 = asyncio.run(post_command(cmd_req1))
    assert res1.status_code == 200
    res1_body = json.loads(res1.body.decode())
    assert res1_body["command"]["action"] == "FORCE_ALL_RED"
    print("[PASS] POST /api/command (FORCE_ALL_RED) -> HTTP 200:", res1_body)

    # 3b. Test GET /api/command retrieves and clears the queued command
    fetch1 = get_command()
    assert fetch1.status_code == 200
    fetch1_body = json.loads(fetch1.body.decode())
    assert fetch1_body["action"] == "FORCE_ALL_RED"
    assert fetch1_body["command_id"] is not None
    print("[PASS] GET /api/command (1st Poll) -> Received queued command:", fetch1_body)

    fetch2 = get_command()
    assert fetch2.status_code == 200
    fetch2_body = json.loads(fetch2.body.decode())
    assert fetch2_body["action"] is None
    print("[PASS] GET /api/command (2nd Poll) -> Command reset verified (action is None)")

    # 3c. Test TRIGGER_EMERGENCY with lane
    cmd_req2 = FakeRequest({"action": "TRIGGER_EMERGENCY", "lane": "West"})
    res2 = asyncio.run(post_command(cmd_req2))
    assert res2.status_code == 200
    res2_body = json.loads(res2.body.decode())
    assert res2_body["command"]["action"] == "TRIGGER_EMERGENCY"
    assert res2_body["command"]["lane"] == "west"

    fetch3 = get_command()
    fetch3_body = json.loads(fetch3.body.decode())
    assert fetch3_body["action"] == "TRIGGER_EMERGENCY"
    assert fetch3_body["lane"] == "west"
    print("[PASS] POST + GET /api/command (TRIGGER_EMERGENCY: West) verified.")

    # 3d. Test SPAWN_TRAFFIC_SURGE and RESUME_AUTO
    res3 = asyncio.run(post_command(FakeRequest({"action": "SPAWN_TRAFFIC_SURGE"})))
    assert res3.status_code == 200
    assert json.loads(get_command().body.decode())["action"] == "SPAWN_TRAFFIC_SURGE"

    res4 = asyncio.run(post_command(FakeRequest({"action": "RESUME_AUTO"})))
    assert res4.status_code == 200
    assert json.loads(get_command().body.decode())["action"] == "RESUME_AUTO"
    print("[PASS] POST + GET /api/command (SPAWN_TRAFFIC_SURGE & RESUME_AUTO) verified.")

    # 3e. Test missing action validation
    res_invalid = asyncio.run(post_command(FakeRequest({})))
    assert res_invalid.status_code == 400
    print("[PASS] POST /api/command (Missing action) -> Graceful HTTP 400")

    print("\nALL STMS BACKEND MODULE TESTS COMPLETED WITH ZERO ERRORS!")

if __name__ == "__main__":
    run_tests()
