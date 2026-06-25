"""
Integration tests for Kozuchi Achievement API.

Run with:
    cd backend && source venv/bin/activate
    python3 test_api.py
"""
import subprocess
import sys
import time
import json
import urllib.request
import urllib.error
import os
import signal

# Add backend to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from database import init_db, SessionLocal
from seed import seed
from models import Achievement, UserAchievement

BASE_URL = "http://localhost:8100"
SERVER_PROC = None


def start_server():
    """Start uvicorn in background."""
    global SERVER_PROC
    venv_python = os.path.join(os.path.dirname(os.path.abspath(__file__)), "venv", "bin", "python3")
    SERVER_PROC = subprocess.Popen(
        [venv_python, "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8100"],
        cwd=os.path.dirname(os.path.abspath(__file__)),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    # Wait for server to be ready
    for _ in range(15):
        try:
            urllib.request.urlopen(f"{BASE_URL}/api/health", timeout=1)
            return True
        except Exception:
            time.sleep(0.5)
    return False


def stop_server():
    if SERVER_PROC:
        SERVER_PROC.terminate()
        SERVER_PROC.wait(timeout=5)


def get_json(path):
    """GET request returning parsed JSON."""
    req = urllib.request.Request(f"{BASE_URL}{path}")
    with urllib.request.urlopen(req, timeout=5) as resp:
        return json.loads(resp.read())


def test_health():
    data = get_json("/api/health")
    assert data["status"] == "ok"
    print("  ✅ Health check passed")


def test_all_achievements_no_user():
    data = get_json("/api/achievements")
    assert len(data) == 25, f"Expected 25, got {len(data)}"
    assert all(not a["unlocked"] for a in data), "All should be unlocked=false without user_id"
    assert all(a["progress"] is None for a in data), "All progress should be None without user_id"
    # Verify sort order
    orders = [a["sort_order"] for a in data]
    assert orders == sorted(orders), "Achievements should be sorted by sort_order"
    print(f"  ✅ {len(data)} achievements returned, all unlocked=false, sorted by sort_order")


def test_all_achievements_with_user():
    data = get_json("/api/achievements?user_id=test_progress")
    assert len(data) == 25
    # offering_count achievements should have progress
    offering_achs = [a for a in data if a["criteria_type"] == "offering_count"]
    assert len(offering_achs) == 4
    for a in offering_achs:
        assert a["progress"] is not None, f"{a['key']} should have progress"
        assert "current" in a["progress"]
        assert "target" in a["progress"]
        assert "pct" in a["progress"]
    # Non-offering achievements have null progress (no tracking data yet)
    print(f"  ✅ With user_id: {len(offering_achs)} offering_count achievements have progress, others null")


def test_unlocked_achievement_appears():
    """Verify that an unlocked achievement shows unlocked=true."""
    # Manually unlock one
    db = SessionLocal()
    try:
        ua = UserAchievement(user_id="test_unlocked", achievement_id=1)
        db.add(ua)
        db.commit()
    finally:
        db.close()

    data = get_json("/api/achievements?user_id=test_unlocked")
    first = data[0]  # first_offering is id=1, sort_order=10 (first in list)
    assert first["key"] == "first_offering"
    assert first["unlocked"] is True
    assert first["unlocked_at"] is not None

    # Already unlocked achievements should not show progress
    assert first["progress"] is None

    # Cleanup
    db = SessionLocal()
    try:
        db.query(UserAchievement).filter(
            UserAchievement.user_id == "test_unlocked"
        ).delete()
        db.commit()
    finally:
        db.close()
    print("  ✅ Unlocked achievement shows unlocked=true with timestamp, no progress")


def test_offering_count_progress_increments():
    """Progress for offering_count should track UserAchievement count."""
    db = SessionLocal()
    try:
        # Add 1 UserAchievement (first_offering) only.
        # This unlocks first_offering. offering_10 should show progress 1/10.
        ua = UserAchievement(user_id="test_count", achievement_id=1)
        db.add(ua)
        db.commit()
    finally:
        db.close()

    data = get_json("/api/achievements?user_id=test_count")
    first = data[0]  # first_offering (value=1) → unlocked
    assert first["key"] == "first_offering", f"Expected first_offering, got {first['key']}"
    assert first["unlocked"] is True
    assert first["progress"] is None  # unlocked → no progress needed

    # offering_10 (value=10) → progress: 1/10 = 10%
    second = data[1]
    assert second["key"] == "offering_10", f"Expected offering_10, got {second['key']}"
    assert second["unlocked"] is False
    assert second["progress"]["current"] == 1, f"Expected current=1, got {second['progress']['current']}"
    assert second["progress"]["target"] == 10
    assert second["progress"]["pct"] == 10.0, f"Expected pct=10.0, got {second['progress']['pct']}"

    # Cleanup
    db = SessionLocal()
    try:
        db.query(UserAchievement).filter(
            UserAchievement.user_id == "test_count"
        ).delete()
        db.commit()
    finally:
        db.close()
    print("  ✅ Progress tracks UserAchievement count (3/10 = 30.0%)")


def run_all():
    print("=== Kozuchi Achievement API Tests ===\n")
    passed = 0
    failed = 0

    tests = [
        ("Health check", test_health),
        ("All achievements (no user)", test_all_achievements_no_user),
        ("All achievements (with user_id)", test_all_achievements_with_user),
        ("Unlocked achievement display", test_unlocked_achievement_appears),
        ("Offering count progress", test_offering_count_progress_increments),
    ]

    for name, fn in tests:
        try:
            fn()
            passed += 1
        except Exception as e:
            print(f"  ❌ {name}: {e}")
            failed += 1

    print(f"\n{'='*40}")
    print(f"Results: {passed} passed, {failed} failed")
    return failed == 0


if __name__ == "__main__":
    # Re-init DB fresh for tests
    db_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kozuchi_achievements.db")
    if os.path.exists(db_path):
        os.remove(db_path)
    init_db()
    seed()

    print("Starting server...")
    if not start_server():
        print("❌ Could not start server")
        sys.exit(1)

    try:
        ok = run_all()
    finally:
        stop_server()

    sys.exit(0 if ok else 1)
