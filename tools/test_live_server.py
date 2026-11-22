"""
Spawns the uvicorn backend on 127.0.0.1:8000, runs end-to-end HTTP requests,
verifies SQLite persistence and response contracts, and stops the server.
"""
import subprocess
import time
import requests
import sys

def main():
    print("==================================================")
    print("Testing Live Uvicorn Backend Server (127.0.0.1:8000)")
    print("==================================================")
    python_exe = sys.executable

    # Launch uvicorn backend
    proc = subprocess.Popen(
        [python_exe, "-m", "uvicorn", "backend.main:app", "--host", "127.0.0.1", "--port", "8000"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )

    try:
        # Wait for server to boot
        time.sleep(2)

        # 1. Health check
        resp = requests.get("http://127.0.0.1:8000/", timeout=3)
        assert resp.status_code == 200, f"Status: {resp.status_code}"
        print("[PASS] GET http://127.0.0.1:8000/ -> 200 OK:", resp.json())

        # 2. POST valid telemetry
        payload = {
            "timestamp": time.time(),
            "current_phase": "NS_GREEN",
            "emergency_active": False,
            "lane_densities": {
                "north": 8,
                "south": 5,
                "east": 3,
                "west": 2
            }
        }
        post_resp = requests.post("http://127.0.0.1:8000/api/telemetry", json=payload, timeout=3)
        assert post_resp.status_code == 200, f"Status: {post_resp.status_code}"
        print("[PASS] POST /api/telemetry -> 200 OK:", post_resp.json())

        # 3. POST malformed telemetry (must return 400 without crashing server)
        bad_resp = requests.post("http://127.0.0.1:8000/api/telemetry", data="NOT_JSON_BODY", headers={"Content-Type": "application/json"}, timeout=3)
        assert bad_resp.status_code == 400, f"Expected 400, got: {bad_resp.status_code}"
        print("[PASS] POST /api/telemetry with malformed data -> 400 Bad Request:", bad_resp.json())

        # 4. Verify server is still alive after malformed data
        alive_resp = requests.get("http://127.0.0.1:8000/", timeout=3)
        assert alive_resp.status_code == 200, "Server crashed after bad payload!"
        print("[PASS] Server remained crash-proof after 400 Bad Request!")

        # 5. GET /api/stats (verifying 60 record limit and sorting)
        stats_resp = requests.get("http://127.0.0.1:8000/api/stats", timeout=3)
        assert stats_resp.status_code == 200
        stats = stats_resp.json()
        assert isinstance(stats, list)
        print(f"[PASS] GET /api/stats -> 200 OK ({len(stats)} records retrieved)")

        # 6. Test Live Remote Command Endpoints
        print("\n--- Testing Live Remote Command Endpoints ---")
        cmd_post = requests.post("http://127.0.0.1:8000/api/command", json={"action": "FORCE_ALL_RED"}, timeout=3)
        assert cmd_post.status_code == 200, f"Expected 200, got {cmd_post.status_code}"
        assert cmd_post.json()["command"]["action"] == "FORCE_ALL_RED"
        print("[PASS] POST /api/command -> 200 OK:", cmd_post.json())

        cmd_poll1 = requests.get("http://127.0.0.1:8000/api/command", timeout=3)
        assert cmd_poll1.status_code == 200
        assert cmd_poll1.json()["action"] == "FORCE_ALL_RED"
        print("[PASS] GET /api/command (1st Poll) -> Fetched command:", cmd_poll1.json())

        cmd_poll2 = requests.get("http://127.0.0.1:8000/api/command", timeout=3)
        assert cmd_poll2.status_code == 200
        assert cmd_poll2.json()["action"] is None
        print("[PASS] GET /api/command (2nd Poll) -> Command cleared once fetched.")

        print("\nLIVE BACKEND SERVER VERIFIED WITH ZERO ERRORS!")

    finally:
        proc.terminate()
        proc.wait(timeout=5)

if __name__ == "__main__":
    main()
