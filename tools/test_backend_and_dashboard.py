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
    from backend.main import ingest_telemetry, get_stats, health_check
    import asyncio
    from unittest.mock import AsyncMock

    # Test health check
    hc = health_check()
    assert hc["status"] == "online"
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

    print("\nALL STMS BACKEND MODULE TESTS COMPLETED WITH ZERO ERRORS!")

if __name__ == "__main__":
    run_tests()
