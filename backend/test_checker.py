"""
Unit tests for AchievementChecker — one per criteria type + edge cases.

Run with:
    cd backend && python3 test_checker.py
"""

import os
import sys

# Add backend to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from database import Base
from checker import AchievementChecker, CRITERIA_TYPES
from seed import seed, ACHIEVEMENTS
from models import Achievement, UserAchievement

# ── Test DB setup ──

TEST_DB_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "test_checker.db"
)

engine = None
SessionLocal = None

passed = 0
failed = 0


def setup_module():
    """Create fresh test DB and seed achievements."""
    global engine, SessionLocal
    if os.path.exists(TEST_DB_PATH):
        os.remove(TEST_DB_PATH)
    engine = create_engine(f"sqlite:///{TEST_DB_PATH}")
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed(db)  # seed 25 achievements
    finally:
        db.close()


def teardown_module():
    """Clean up test DB."""
    if os.path.exists(TEST_DB_PATH):
        os.remove(TEST_DB_PATH)


def assert_eq(actual, expected, msg=""):
    global passed, failed
    if actual == expected:
        passed += 1
    else:
        failed += 1
        detail = f"  Expected: {expected!r}\n  Got:      {actual!r}"
        if msg:
            detail = f"  {msg}\n{detail}"
        print(f"  ❌ FAIL: {detail}")


def assert_true(condition, msg=""):
    global passed, failed
    if condition:
        passed += 1
    else:
        failed += 1
        print(f"  ❌ FAIL: {msg or 'Expected True, got False'}")


def clean_user(db, user_id):
    """Remove all user_achievements for a test user."""
    db.query(UserAchievement).filter(
        UserAchievement.user_id == user_id
    ).delete()
    db.commit()


# ── Tests ──

def test_offering_count():
    """offering_count criteria: unlock when count >= threshold."""
    db = SessionLocal()
    try:
        checker = AchievementChecker(db, "test_offering")

        # 0 offerings → nothing unlocked
        result = checker.check_and_unlock({"offering_count": 0})
        assert_eq(len(result), 0, "0 offerings → 0 unlocks")

        # 1 offering → first_offering (value=1) unlocked
        result = checker.check_and_unlock({"offering_count": 1})
        assert_eq(len(result), 1, "1 offering → 1 unlock (first_offering)")
        assert_eq(result[0]["key"], "first_offering")

        # 10 offerings → offering_10 unlocked (but first_offering already done)
        result = checker.check_and_unlock({"offering_count": 10})
        assert_eq(len(result), 1, "10 offerings → 1 new unlock (offering_10)")
        assert_eq(result[0]["key"], "offering_10")

        # 50 offerings → offering_50
        result = checker.check_and_unlock({"offering_count": 50})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "offering_50")

        # 100 offerings → offering_100
        result = checker.check_and_unlock({"offering_count": 100})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "offering_100")

        # Idempotent: re-check at 100 → nothing new
        result = checker.check_and_unlock({"offering_count": 100})
        assert_eq(len(result), 0, "Idempotent: re-check → 0 unlocks")

        # Verify DB state
        ids = checker.get_unlocked_ids()
        # offering_count achievements have ids 1-4 (first_offering → offering_100)
        assert_true(1 in ids and 2 in ids and 3 in ids and 4 in ids,
                     "All 4 offering_count achievements unlocked in DB")

        print("  ✅ offering_count: all 6 assertions passed")
    finally:
        clean_user(db, "test_offering")
        db.close()


def test_total_donation():
    """total_donation criteria: unlock when cumulative total >= threshold."""
    db = SessionLocal()
    try:
        checker = AchievementChecker(db, "test_donation")

        # Below all thresholds
        result = checker.check_and_unlock({"total_donation": 5000})
        assert_eq(len(result), 0)

        # ¥10,000 → total_10000 (id=5)
        result = checker.check_and_unlock({"total_donation": 10000})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "total_10000")

        # ¥100,000 → total_50000 + total_100000 (cascade)
        result = checker.check_and_unlock({"total_donation": 100000})
        assert_eq(len(result), 2)
        keys = {r["key"] for r in result}
        assert_true("total_50000" in keys and "total_100000" in keys,
                     "Cascade: 100000 unlocks both 50000 and 100000")

        # ¥1,000,000 → total_500000 + total_1000000
        result = checker.check_and_unlock({"total_donation": 1000000})
        assert_eq(len(result), 2)
        keys = {r["key"] for r in result}
        assert_true("total_500000" in keys and "total_1000000" in keys,
                     "Cascade: 1000000 unlocks both 500000 and 1000000")

        # Idempotent
        result = checker.check_and_unlock({"total_donation": 1000000})
        assert_eq(len(result), 0)

        print("  ✅ total_donation: all 6 assertions passed")
    finally:
        clean_user(db, "test_donation")
        db.close()


def test_streak_days():
    """streak_days criteria: unlock when streak >= threshold."""
    db = SessionLocal()
    try:
        checker = AchievementChecker(db, "test_streak")

        result = checker.check_and_unlock({"streak_days": 2})
        assert_eq(len(result), 0)

        result = checker.check_and_unlock({"streak_days": 3})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "streak_3")

        result = checker.check_and_unlock({"streak_days": 7})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "streak_7")

        result = checker.check_and_unlock({"streak_days": 14})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "streak_14")

        result = checker.check_and_unlock({"streak_days": 30})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "streak_30")

        result = checker.check_and_unlock({"streak_days": 100})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "streak_100")

        # Idempotent
        result = checker.check_and_unlock({"streak_days": 100})
        assert_eq(len(result), 0)

        print("  ✅ streak_days: all 8 assertions passed")
    finally:
        clean_user(db, "test_streak")
        db.close()


def test_categories_used():
    """categories_used criteria: unlock when unique categories >= threshold."""
    db = SessionLocal()
    try:
        checker = AchievementChecker(db, "test_categories")

        result = checker.check_and_unlock({"categories_used": 2})
        assert_eq(len(result), 0)

        result = checker.check_and_unlock({"categories_used": 3})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "categories_3")

        # categories_all has criteria_value=999, won't unlock normally
        result = checker.check_and_unlock({"categories_used": 5})
        assert_eq(len(result), 0, "5 categories → no new unlock (all needs 999)")

        # But if we send 999
        result = checker.check_and_unlock({"categories_used": 999})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "categories_all")

        print("  ✅ categories_used: all 4 assertions passed")
    finally:
        clean_user(db, "test_categories")
        db.close()


def test_satori_level():
    """satori_level criteria: unlock when SATORI gauge % >= threshold."""
    db = SessionLocal()
    try:
        checker = AchievementChecker(db, "test_satori")

        result = checker.check_and_unlock({"satori_level": 10})
        assert_eq(len(result), 0)

        result = checker.check_and_unlock({"satori_level": 25})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "satori_25")

        result = checker.check_and_unlock({"satori_level": 50})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "satori_50")

        result = checker.check_and_unlock({"satori_level": 75})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "satori_75")

        result = checker.check_and_unlock({"satori_level": 100})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "satori_100")

        # Idempotent
        result = checker.check_and_unlock({"satori_level": 100})
        assert_eq(len(result), 0)

        print("  ✅ satori_level: all 7 assertions passed")
    finally:
        clean_user(db, "test_satori")
        db.close()


def test_guardians_tried():
    """guardians_tried criteria: unlock when unique guardians >= threshold."""
    db = SessionLocal()
    try:
        checker = AchievementChecker(db, "test_guardians")

        result = checker.check_and_unlock({"guardians_tried": 3})
        assert_eq(len(result), 0)

        result = checker.check_and_unlock({"guardians_tried": 4})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "all_guardians")

        # Idempotent
        result = checker.check_and_unlock({"guardians_tried": 4})
        assert_eq(len(result), 0)

        print("  ✅ guardians_tried: all 3 assertions passed")
    finally:
        clean_user(db, "test_guardians")
        db.close()


def test_receipt_count():
    """receipt_count criteria: unlock when scanned receipts >= threshold."""
    db = SessionLocal()
    try:
        checker = AchievementChecker(db, "test_receipt")

        result = checker.check_and_unlock({"receipt_count": 4})
        assert_eq(len(result), 0)

        result = checker.check_and_unlock({"receipt_count": 5})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "receipt_5")

        result = checker.check_and_unlock({"receipt_count": 20})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "receipt_20")

        # Idempotent
        result = checker.check_and_unlock({"receipt_count": 20})
        assert_eq(len(result), 0)

        print("  ✅ receipt_count: all 4 assertions passed")
    finally:
        clean_user(db, "test_receipt")
        db.close()


def test_budget_set_count():
    """budget_set_count criteria: unlock when budgets configured >= threshold."""
    db = SessionLocal()
    try:
        checker = AchievementChecker(db, "test_budget_set")

        result = checker.check_and_unlock({"budget_set_count": 2})
        assert_eq(len(result), 0)

        result = checker.check_and_unlock({"budget_set_count": 3})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "budget_master")

        # Idempotent
        result = checker.check_and_unlock({"budget_set_count": 3})
        assert_eq(len(result), 0)

        print("  ✅ budget_set_count: all 3 assertions passed")
    finally:
        clean_user(db, "test_budget_set")
        db.close()


def test_budget_perfect_days():
    """budget_perfect_days criteria: unlock when perfect days >= threshold."""
    db = SessionLocal()
    try:
        checker = AchievementChecker(db, "test_perfect")

        result = checker.check_and_unlock({"budget_perfect_days": 6})
        assert_eq(len(result), 0)

        result = checker.check_and_unlock({"budget_perfect_days": 7})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "budget_perfect_7")

        # Idempotent
        result = checker.check_and_unlock({"budget_perfect_days": 7})
        assert_eq(len(result), 0)

        print("  ✅ budget_perfect_days: all 3 assertions passed")
    finally:
        clean_user(db, "test_perfect")
        db.close()


def test_multi_criteria_simultaneous():
    """Multiple criteria types unlocked in one call."""
    db = SessionLocal()
    try:
        checker = AchievementChecker(db, "test_multi")

        result = checker.check_and_unlock({
            "offering_count": 100,
            "total_donation": 100000,
            "streak_days": 30,
            "categories_used": 3,
            "satori_level": 50,
            "guardians_tried": 4,
            "receipt_count": 20,
            "budget_set_count": 3,
            "budget_perfect_days": 7,
        })
        # Should unlock many at once
        assert_true(len(result) >= 10, f"Multi-criteria: expected >=10 unlocks, got {len(result)}")

        # Verify specific keys present
        keys = {r["key"] for r in result}
        for expected in [
            "offering_100", "total_100000", "streak_30",
            "categories_3", "satori_50", "all_guardians",
            "receipt_20", "budget_master", "budget_perfect_7",
        ]:
            assert_true(expected in keys, f"Multi: {expected} should be in result")

        # Idempotent
        result = checker.check_and_unlock({
            "offering_count": 100,
            "total_donation": 100000,
        })
        assert_eq(len(result), 0, "Multi: idempotent re-check → 0 unlocks")

        print("  ✅ multi_criteria_simultaneous: all assertions passed")
    finally:
        clean_user(db, "test_multi")
        db.close()


def test_missing_keys_default_to_zero():
    """Missing criteria keys in user_state default to 0."""
    db = SessionLocal()
    try:
        checker = AchievementChecker(db, "test_defaults")

        # Only provide offering_count, nothing else
        result = checker.check_and_unlock({"offering_count": 1})
        assert_eq(len(result), 1)
        assert_eq(result[0]["key"], "first_offering")

        # Nothing else should unlock because other values default to 0
        # (which is below all thresholds)
        ids = checker.get_unlocked_ids()
        # first_offering is id=1
        assert_true(1 in ids, "first_offering unlocked")
        assert_eq(len(ids), 1, f"Only 1 achievement unlocked, got {len(ids)}")

        print("  ✅ missing_keys_default_to_zero: all assertions passed")
    finally:
        clean_user(db, "test_defaults")
        db.close()


def test_no_achievements_with_zero_state():
    """All-zero state unlocks nothing."""
    db = SessionLocal()
    try:
        checker = AchievementChecker(db, "test_zero")
        result = checker.check_and_unlock({
            "offering_count": 0,
            "total_donation": 0,
            "streak_days": 0,
        })
        assert_eq(len(result), 0, "All-zero → 0 unlocks")
        print("  ✅ no_achievements_with_zero_state: passed")
    finally:
        clean_user(db, "test_zero")
        db.close()


def test_result_has_unlocked_at():
    """Returned dicts must include unlocked_at when achievement is unlocked."""
    db = SessionLocal()
    try:
        checker = AchievementChecker(db, "test_timestamp")
        result = checker.check_and_unlock({"offering_count": 1})
        assert_eq(len(result), 1)
        assert_true(result[0]["unlocked"], "Should be unlocked=True")
        assert_true(result[0]["unlocked_at"] is not None,
                     "unlocked_at should be set")
        assert_true(result[0]["unlocked"] is True)

        print("  ✅ result_has_unlocked_at: all assertions passed")
    finally:
        clean_user(db, "test_timestamp")
        db.close()


def test_checker_get_unlocked_ids():
    """get_unlocked_ids() returns correct set after unlocks."""
    db = SessionLocal()
    try:
        checker = AchievementChecker(db, "test_ids")
        assert_eq(len(checker.get_unlocked_ids()), 0, "Initially empty")

        checker.check_and_unlock({"offering_count": 10})
        ids = checker.get_unlocked_ids()
        assert_eq(len(ids), 2, "first_offering + offering_10 = 2")
        assert_true(1 in ids and 2 in ids, "IDs 1 and 2 should be present")

        print("  ✅ checker_get_unlocked_ids: all assertions passed")
    finally:
        clean_user(db, "test_ids")
        db.close()


# ── Test runner ──

def run_all():
    global passed, failed
    passed = 0
    failed = 0

    print("=== AchievementChecker Unit Tests ===\n")

    tests = [
        ("offering_count", test_offering_count),
        ("total_donation", test_total_donation),
        ("streak_days", test_streak_days),
        ("categories_used", test_categories_used),
        ("satori_level", test_satori_level),
        ("guardians_tried", test_guardians_tried),
        ("receipt_count", test_receipt_count),
        ("budget_set_count", test_budget_set_count),
        ("budget_perfect_days", test_budget_perfect_days),
        ("multi_criteria_simultaneous", test_multi_criteria_simultaneous),
        ("missing_keys_default_to_zero", test_missing_keys_default_to_zero),
        ("no_achievements_with_zero_state", test_no_achievements_with_zero_state),
        ("result_has_unlocked_at", test_result_has_unlocked_at),
        ("get_unlocked_ids", test_checker_get_unlocked_ids),
    ]

    for name, fn in tests:
        print(f"\n[Test: {name}]")
        try:
            fn()
        except Exception as e:
            failed += 1
            import traceback
            traceback.print_exc()
            print(f"  ❌ Exception in {name}: {e}")

    print(f"\n{'='*50}")
    print(f"Results: {passed} passed, {failed} failed, {len(tests)} suites")
    print(f"{'='*50}")

    return failed == 0


if __name__ == "__main__":
    setup_module()
    try:
        ok = run_all()
    finally:
        teardown_module()
    sys.exit(0 if ok else 1)
