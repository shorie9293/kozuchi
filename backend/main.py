"""
FastAPI application for Kozuchi achievement system.

Endpoints:
  GET  /api/achievements          — list all achievements (public, no auth)
  GET  /api/achievements/{user_id} — list with per-user unlock status + progress

Start with:
    uvicorn main:app --reload --port 8100
"""
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from database import init_db, get_db
from models import Achievement, UserAchievement
from seed import seed
from checker import AchievementChecker


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup: init DB tables + seed achievements."""
    init_db()
    seed()
    yield


app = FastAPI(
    title="Kozuchi Achievement API",
    description="実績・称号システム for 打ち出の小槌 (Kozuchi)",
    version="1.0.0",
    lifespan=lifespan,
)

# Allow Flutter app (any origin during development)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Schemas (inline for simplicity) ──

from pydantic import BaseModel

class AchievementOut(BaseModel):
    id: int
    key: str
    title: str
    description: str
    criteria_type: str
    criteria_value: int
    icon: str
    sort_order: int
    unlocked: bool = False
    unlocked_at: Optional[str] = None
    progress: Optional[dict] = None

    class Config:
        from_attributes = True


class CheckRequest(BaseModel):
    """Request body for POST /api/achievements/check."""
    user_id: str
    offering_count: int = 0
    total_donation: int = 0
    streak_days: int = 0
    categories_used: int = 0
    satori_level: int = 0
    guardians_tried: int = 0
    receipt_count: int = 0
    budget_set_count: int = 0
    budget_perfect_days: int = 0


class CheckResponse(BaseModel):
    """Response for POST /api/achievements/check."""
    newly_unlocked: list[AchievementOut]
    already_unlocked_count: int
    total_achievements: int


# ── Endpoints ──

@app.get("/api/achievements", response_model=list[AchievementOut])
def list_all_achievements(
    user_id: Optional[str] = Query(None, description="User ID for per-user unlock status"),
    db: Session = Depends(get_db),
):
    """
    Return all achievement definitions.

    If `user_id` is provided, each achievement includes:
      - unlocked (bool)
      - unlocked_at (ISO datetime string or null)
      - progress dict with `current` and `target` values (for threshold-based criteria)
        e.g. {"current": 35000, "target": 100000, "pct": 35.0}

    Without `user_id`, all achievements are returned with unlocked=false and no progress.
    """
    achievements = (
        db.query(Achievement)
        .order_by(Achievement.sort_order, Achievement.id)
        .all()
    )

    if not user_id:
        # No user context — return definitions only
        return [a.to_dict() for a in achievements]

    # Fetch user's unlocks in one query
    unlocked_map = {}
    for ua in (
        db.query(UserAchievement)
        .filter(UserAchievement.user_id == user_id)
        .all()
    ):
        unlocked_map[ua.achievement_id] = ua.unlocked_at

    results = []
    for a in achievements:
        ua = unlocked_map.get(a.id)
        progress = _compute_progress(a, user_id, db) if not ua else None
        results.append(a.to_dict(
            unlocked_at=ua,
            progress=progress,
        ))
    return results


# ── Progress helpers ──

def _compute_progress(achievement: Achievement, user_id: str, db: Session) -> dict | None:
    """
    Compute progress toward an achievement for a given user.

    Returns None if progress cannot be computed (e.g., criteria_type unknown).
    Otherwise returns {"current": int, "target": int, "pct": float}.
    """
    target = achievement.criteria_value
    current = 0

    ct = achievement.criteria_type

    if ct == "offering_count":
        current = (
            db.query(UserAchievement)
            .filter(UserAchievement.user_id == user_id)
            .count()
        )
    elif ct == "total_donation":
        # Aggregate from a hypothetical donation tracking system.
        # For now, return None — the checking engine (Task t_8e104715) will inject
        # real data. This endpoint serves as a read-only mirror.
        return None
    elif ct == "streak_days":
        return None  # Requires time-series data
    elif ct == "categories_used":
        return None  # Requires category tracking
    elif ct == "satori_level":
        return None  # Requires SATORI gauge data
    elif ct == "guardians_tried":
        return None  # Requires guardian tracking
    elif ct == "receipt_count":
        return None  # Requires receipt tracking
    elif ct == "budget_set_count":
        return None  # Requires budget tracking
    elif ct == "budget_perfect_days":
        return None  # Requires budget compliance tracking
    else:
        return None

    pct = min(100.0, (current / target) * 100.0) if target > 0 else 100.0
    return {"current": current, "target": target, "pct": round(pct, 1)}


# ── Check endpoint ──

@app.post("/api/achievements/check", response_model=CheckResponse)
def check_achievements(
    req: CheckRequest,
    db: Session = Depends(get_db),
):
    """
    Evaluate user state against all achievement definitions and unlock
    any newly met achievements.

    Call this whenever a relevant event occurs:
    - donation created → offering_count + total_donation updated
    - streak extended → streak_days updated
    - categories changed → categories_used updated
    - satori gauge changed → satori_level updated
    - etc.

    Returns the list of newly unlocked achievements so the UI
    can display a popup / fanfare.
    """
    user_state = {
        "offering_count": req.offering_count,
        "total_donation": req.total_donation,
        "streak_days": req.streak_days,
        "categories_used": req.categories_used,
        "satori_level": req.satori_level,
        "guardians_tried": req.guardians_tried,
        "receipt_count": req.receipt_count,
        "budget_set_count": req.budget_set_count,
        "budget_perfect_days": req.budget_perfect_days,
    }

    checker = AchievementChecker(db, req.user_id)
    newly_unlocked = checker.check_and_unlock(user_state)

    total = (
        db.query(Achievement).count()
    )
    already = len(checker.get_unlocked_ids()) - len(newly_unlocked)

    return CheckResponse(
        newly_unlocked=newly_unlocked,
        already_unlocked_count=already,
        total_achievements=total,
    )


# ── Health check ──

@app.get("/api/health")
def health():
    return {"status": "ok", "service": "kozuchi-achievements"}
