"""
Achievement checking engine for Kozuchi (打ち出の小槌).

Evaluates user state against achievement definitions and unlocks
newly met achievements. Designed to be called whenever a relevant
event occurs (donation created, total updated, streak extended,
all categories used, etc.).

Usage:
    from checker import AchievementChecker

    checker = AchievementChecker(db_session, user_id)
    newly_unlocked = checker.check_and_unlock(user_state)
    # user_state = {
    #     "offering_count": 12,
    #     "total_donation": 35000,
    #     "streak_days": 5,
    #     "categories_used": 3,
    #     "satori_level": 45,
    #     "guardians_tried": 2,
    #     "receipt_count": 6,
    #     "budget_set_count": 1,
    #     "budget_perfect_days": 3,
    # }

Returns a list of Achievement dicts that were just unlocked.
Idempotent — already-unlocked achievements are skipped.
"""

from typing import Dict, List, Optional
from sqlalchemy.orm import Session
from models import Achievement, UserAchievement

# All known criteria types that the checker can evaluate
CRITERIA_TYPES = [
    "offering_count",
    "total_donation",
    "streak_days",
    "categories_used",
    "satori_level",
    "guardians_tried",
    "receipt_count",
    "budget_set_count",
    "budget_perfect_days",
]


class AchievementChecker:
    """Evaluates user state against achievements and unlocks newly met ones."""

    def __init__(self, db: Session, user_id: str):
        """
        Args:
            db: SQLAlchemy session (injected by caller).
            user_id: The user to evaluate achievements for.
        """
        self.db = db
        self.user_id = user_id

    def check_and_unlock(self, user_state: Dict[str, int]) -> List[dict]:
        """
        Evaluate all locked achievements against user_state.
        Insert newly met ones into user_achievements.

        Args:
            user_state: Dict mapping criteria_type -> current value.
                        Missing keys default to 0.

        Returns:
            List of achievement dicts (with unlocked_at) that were just unlocked.
            Empty list if nothing new was unlocked.
        """
        # Normalize user_state — fill missing keys with 0
        state = {ct: user_state.get(ct, 0) for ct in CRITERIA_TYPES}

        # Load all achievement definitions, ordered by sort_order
        all_achievements = (
            self.db.query(Achievement)
            .order_by(Achievement.sort_order, Achievement.id)
            .all()
        )

        # Load already-unlocked achievement IDs for this user
        unlocked_ids = set(
            row[0]
            for row in self.db.query(UserAchievement.achievement_id)
            .filter(UserAchievement.user_id == self.user_id)
            .all()
        )

        newly_unlocked = []

        for ach in all_achievements:
            if ach.id in unlocked_ids:
                continue  # Already unlocked — skip

            current_value = state.get(ach.criteria_type, 0)
            if current_value >= ach.criteria_value:
                # Unlock!
                ua = UserAchievement(
                    user_id=self.user_id,
                    achievement_id=ach.id,
                )
                self.db.add(ua)
                newly_unlocked.append(ach)

        if newly_unlocked:
            self.db.commit()

        return [
            a.to_dict(
                unlocked_at=next(
                    ua.unlocked_at
                    for ua in a.user_achievements
                    if ua.user_id == self.user_id
                ),
            )
            if a.user_achievements
            else a.to_dict(unlocked_at=None)
            for a in newly_unlocked
        ]

    def get_unlocked_ids(self) -> set:
        """Return set of achievement IDs already unlocked by this user."""
        return set(
            row[0]
            for row in self.db.query(UserAchievement.achievement_id)
            .filter(UserAchievement.user_id == self.user_id)
            .all()
        )
