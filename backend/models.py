"""
SQLAlchemy models for the Kozuchi achievement system.

Tables:
  - achievements: static achievement definitions (seeded once)
  - user_achievements: per-user unlock state
"""
from datetime import datetime, timezone
from sqlalchemy import (
    Column, Integer, String, DateTime, ForeignKey, UniqueConstraint
)
from sqlalchemy.orm import relationship
from database import Base


class Achievement(Base):
    """Static achievement definition — seeded once, never modified by runtime."""

    __tablename__ = "achievements"

    id = Column(Integer, primary_key=True, autoincrement=True)
    # Unique machine-readable key: "first_offering", "streak_30", etc.
    key = Column(String(64), unique=True, nullable=False, index=True)
    title = Column(String(128), nullable=False)
    description = Column(String(512), nullable=False)
    criteria_type = Column(String(64), nullable=False, index=True)
    # The threshold value to unlock (e.g., 100000 for total_donation=¥100,000)
    criteria_value = Column(Integer, nullable=False)
    # Emoji or icon identifier for UI display
    icon = Column(String(32), nullable=False, default="🏆")
    # Display ordering hint (lower = shown first)
    sort_order = Column(Integer, nullable=False, default=0)
    created_at = Column(
        DateTime, nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )

    # Relationship
    user_achievements = relationship(
        "UserAchievement", back_populates="achievement", cascade="all, delete-orphan"
    )

    def to_dict(self, unlocked_at=None, progress=None):
        """Serialize for API response, optionally with per-user metadata."""
        d = {
            "id": self.id,
            "key": self.key,
            "title": self.title,
            "description": self.description,
            "criteria_type": self.criteria_type,
            "criteria_value": self.criteria_value,
            "icon": self.icon,
            "sort_order": self.sort_order,
            "unlocked": unlocked_at is not None,
            "unlocked_at": unlocked_at.isoformat() if unlocked_at else None,
        }
        if progress is not None:
            d["progress"] = progress
        return d


class UserAchievement(Base):
    """Records which achievements a user has unlocked and when."""

    __tablename__ = "user_achievements"
    __table_args__ = (
        UniqueConstraint("user_id", "achievement_id", name="uq_user_achievement"),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(128), nullable=False, index=True)
    achievement_id = Column(
        Integer, ForeignKey("achievements.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    unlocked_at = Column(
        DateTime, nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )

    # Relationship
    achievement = relationship("Achievement", back_populates="user_achievements")
