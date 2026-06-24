"""
kozuchi 実績（Achievement）モジュール

全実績定義 + ユーザー進捗管理。
三現世（rpg-task / tsundoku / kozuchi）を跨ぐ相互実績に対応。

DB テーブル:
  - achievement_definitions: 実績の静的定義
  - user_achievement_progress: ユーザー別の統計カウンター
  - user_achievements: 解除済み実績の記録
"""

from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

DB_PATH = Path.home() / "Takamagahara" / "utsushiyo" / "kozuchi" / "server" / "kozuchi.db"


# ── 実績定義 ──────────────────────────────────────────────────

@dataclass
class AchievementDefinition:
    """実績の静的定義"""
    id: int
    key: str                 # 一意キー（例: "three_worlds_conquest"）
    title: str               # 表示名（例: "三現世制覇"）
    description: str         # 説明文
    criteria_type: str       # 条件タイプ: "offering_count" | "total_donation" | "streak_days" | "cross_app" など
    criteria_value: int      # 閾値
    icon: str                # アイコン絵文字
    sort_order: int          # 表示順
    # cross_app 用のサブ条件（JSON object）
    sub_criteria: Optional[dict] = None

    def to_dict(self, unlocked: bool = False, unlocked_at: Optional[str] = None,
                progress: Optional[dict] = None) -> dict:
        result = {
            "id": self.id,
            "key": self.key,
            "title": self.title,
            "description": self.description,
            "criteria_type": self.criteria_type,
            "criteria_value": self.criteria_value,
            "icon": self.icon,
            "sort_order": self.sort_order,
            "unlocked": unlocked,
            "unlocked_at": unlocked_at,
        }
        if progress:
            result["progress"] = progress
        return result


# ── 全実績定義 ────────────────────────────────────────────────

# 三現世制覇のサブ条件
THREE_WORLDS_SUB_CRITERIA = {
    "rpg_enemies_defeated": 10,      # rpg-task: 敵を10体倒す
    "tsundoku_books_read": 5,         # tsundoku: 本を5冊読む
    "kozuchi_gold_earned": 1000,      # kozuchi: 1000ゴールド稼ぐ
}

ACHIEVEMENT_DEFINITIONS = [
    # ── kozuchi 単独実績 ──
    AchievementDefinition(
        id=1, key="first_offering", title="初めての喜捨",
        description="初めて喜捨を行った。",
        criteria_type="offering_count", criteria_value=1,
        icon="🙏", sort_order=10,
    ),
    AchievementDefinition(
        id=2, key="offering_10", title="喜捨の修行者",
        description="喜捨を10回行った。",
        criteria_type="offering_count", criteria_value=10,
        icon="📿", sort_order=11,
    ),
    AchievementDefinition(
        id=3, key="offering_50", title="喜捨の求道者",
        description="喜捨を50回行った。",
        criteria_type="offering_count", criteria_value=50,
        icon="🛐", sort_order=12,
    ),
    AchievementDefinition(
        id=5, key="total_10000", title="壱万円突破",
        description="累計喜捨額が1万円を超えた。",
        criteria_type="total_donation", criteria_value=10000,
        icon="💰", sort_order=20,
    ),
    AchievementDefinition(
        id=6, key="total_100000", title="拾万円突破",
        description="累計喜捨額が10万円を超えた。",
        criteria_type="total_donation", criteria_value=100000,
        icon="💎", sort_order=21,
    ),
    AchievementDefinition(
        id=7, key="streak_7", title="七日修行",
        description="7日連続で喜捨を記録。",
        criteria_type="streak_days", criteria_value=7,
        icon="🌅", sort_order=30,
    ),
    AchievementDefinition(
        id=8, key="streak_30", title="月影の修行者",
        description="30日連続で喜捨を記録。",
        criteria_type="streak_days", criteria_value=30,
        icon="🌕", sort_order=31,
    ),
    AchievementDefinition(
        id=9, key="categories_5", title="五道の探求者",
        description="5つの異なるカテゴリで喜捨を記録。",
        criteria_type="categories_used", criteria_value=5,
        icon="🎯", sort_order=40,
    ),
    AchievementDefinition(
        id=10, key="satori_25", title="悟りの初段",
        description="SATORI値が25%に達した。",
        criteria_type="satori_level", criteria_value=25,
        icon="💡", sort_order=50,
    ),
    AchievementDefinition(
        id=11, key="satori_50", title="悟りの中段",
        description="SATORI値が50%に達した。",
        criteria_type="satori_level", criteria_value=50,
        icon="✨", sort_order=51,
    ),
    AchievementDefinition(
        id=12, key="satori_100", title="完全なる悟り",
        description="SATORI値が100%に達した。",
        criteria_type="satori_level", criteria_value=100,
        icon="🔮", sort_order=52,
    ),

    # ── 三現世制覇（cross_app） ──
    AchievementDefinition(
        id=20, key="three_worlds_conquest", title="三現世制覇",
        description=(
            "三つの現世すべてで偉業を成し遂げた："
            "討伐10体（RPG）、読了5冊（ツンドク）、蓄財1000（小槌）"
        ),
        criteria_type="cross_app", criteria_value=3,  # 3条件すべて達成が必要
        icon="👑", sort_order=100,
        sub_criteria=THREE_WORLDS_SUB_CRITERIA,
    ),
]


# ── DB 操作 ───────────────────────────────────────────────────

def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn


def init_achievement_tables(conn: Optional[sqlite3.Connection] = None):
    """実績関連テーブルを作成し、定義データを投入する"""
    should_close = conn is None
    if conn is None:
        conn = get_db()

    conn.execute("""
        CREATE TABLE IF NOT EXISTS achievement_definitions (
            id INTEGER PRIMARY KEY,
            key TEXT NOT NULL UNIQUE,
            title TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            criteria_type TEXT NOT NULL,
            criteria_value INTEGER NOT NULL DEFAULT 1,
            icon TEXT NOT NULL DEFAULT '🏆',
            sort_order INTEGER NOT NULL DEFAULT 0,
            sub_criteria TEXT
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS user_achievement_progress (
            user_id TEXT NOT NULL,
            stat_key TEXT NOT NULL,
            stat_value INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (user_id, stat_key)
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS user_achievements (
            user_id TEXT NOT NULL,
            achievement_id INTEGER NOT NULL,
            unlocked_at TEXT NOT NULL,
            PRIMARY KEY (user_id, achievement_id),
            FOREIGN KEY (achievement_id) REFERENCES achievement_definitions(id)
        )
    """)

    # seed achievement definitions (INSERT OR IGNORE)
    for a in ACHIEVEMENT_DEFINITIONS:
        conn.execute(
            """INSERT OR IGNORE INTO achievement_definitions
               (id, key, title, description, criteria_type, criteria_value, icon, sort_order, sub_criteria)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (a.id, a.key, a.title, a.description, a.criteria_type,
             a.criteria_value, a.icon, a.sort_order,
             json.dumps(a.sub_criteria, ensure_ascii=False) if a.sub_criteria else None),
        )

    conn.commit()
    if should_close:
        conn.close()


# ── 進捗更新 ──────────────────────────────────────────────────

def update_user_stat(user_id: str, stat_key: str, value: int,
                     conn: Optional[sqlite3.Connection] = None) -> None:
    """ユーザーの統計値を更新（max で上書き。app間で値が上がるだけ）"""
    should_close = conn is None
    if conn is None:
        conn = get_db()

    now = datetime.now(timezone.utc).isoformat()
    conn.execute(
        """INSERT INTO user_achievement_progress (user_id, stat_key, stat_value, updated_at)
           VALUES (?, ?, ?, ?)
           ON CONFLICT(user_id, stat_key) DO UPDATE SET
             stat_value = MAX(stat_value, excluded.stat_value),
             updated_at = excluded.updated_at""",
        (user_id, stat_key, value, now),
    )
    conn.commit()
    if should_close:
        conn.close()


# ── 実績チェック ─────────────────────────────────────────────

def check_achievements(user_id: str, incoming_stats: dict,
                       conn: Optional[sqlite3.Connection] = None) -> dict:
    """
    ユーザーの統計を受け取り、新たに解除された実績を返す。

    Args:
        user_id: ユーザーID
        incoming_stats: { stat_key: value } — 各アプリから送られる統計
        conn: 既存のDB接続（任意）

    Returns:
        {
            "newly_unlocked": [...],
            "already_unlocked_count": int,
            "total_achievements": int,
        }
    """
    should_close = conn is None
    if conn is None:
        conn = get_db()

    # 1. 統計を更新
    for key, value in incoming_stats.items():
        update_user_stat(user_id, key, value, conn=conn)

    # 2. 現在の全統計を取得
    stats = _get_user_stats(user_id, conn)

    # 3. 既存の解除済み実績を取得
    unlocked_ids = _get_unlocked_ids(user_id, conn)

    # 4. 全実績定義を取得
    rows = conn.execute(
        "SELECT * FROM achievement_definitions ORDER BY sort_order"
    ).fetchall()
    definitions = [_row_to_definition(r) for r in rows]

    # 5. 各実績をチェック
    newly_unlocked = []
    now = datetime.now(timezone.utc).isoformat()

    for a in definitions:
        if a.id in unlocked_ids:
            continue

        if _check_single(stats, a):
            conn.execute(
                "INSERT OR IGNORE INTO user_achievements (user_id, achievement_id, unlocked_at) VALUES (?, ?, ?)",
                (user_id, a.id, now),
            )
            newly_unlocked.append(a.to_dict(unlocked=True, unlocked_at=now))

    conn.commit()

    result = {
        "newly_unlocked": newly_unlocked,
        "already_unlocked_count": len(unlocked_ids),
        "total_achievements": len(definitions),
    }

    if should_close:
        conn.close()
    return result


def fetch_achievements(user_id: Optional[str] = None,
                       conn: Optional[sqlite3.Connection] = None) -> list[dict]:
    """
    全実績定義を取得し、user_id指定時は進捗と解除状態を含める。

    Args:
        user_id: ユーザーID（None の場合は全実績が unlocked=false で返る）
        conn: 既存のDB接続（任意）

    Returns:
        [AchievementApiModel 互換の dict リスト]
    """
    should_close = conn is None
    if conn is None:
        conn = get_db()

    rows = conn.execute(
        "SELECT * FROM achievement_definitions ORDER BY sort_order"
    ).fetchall()

    stats = {}
    unlocked_ids = set()
    unlocked_map = {}  # achievement_id -> unlocked_at

    if user_id:
        stats = _get_user_stats(user_id, conn)
        unlocked_ids = _get_unlocked_ids(user_id, conn)
        # 解除日時も取得
        ua_rows = conn.execute(
            "SELECT achievement_id, unlocked_at FROM user_achievements WHERE user_id = ?",
            (user_id,),
        ).fetchall()
        unlocked_map = {r["achievement_id"]: r["unlocked_at"] for r in ua_rows}

    result = []
    for r in rows:
        a = _row_to_definition(r)
        unlocked = a.id in unlocked_ids
        progress = _compute_progress(a, stats) if not unlocked and user_id else None

        result.append(a.to_dict(
            unlocked=unlocked,
            unlocked_at=unlocked_map.get(a.id),
            progress=progress,
        ))

    if should_close:
        conn.close()
    return result


# ── 内部ヘルパー ──────────────────────────────────────────────

def _row_to_definition(row: sqlite3.Row) -> AchievementDefinition:
    sub = row["sub_criteria"]
    return AchievementDefinition(
        id=row["id"],
        key=row["key"],
        title=row["title"],
        description=row["description"],
        criteria_type=row["criteria_type"],
        criteria_value=row["criteria_value"],
        icon=row["icon"],
        sort_order=row["sort_order"],
        sub_criteria=json.loads(sub) if sub else None,
    )


def _get_user_stats(user_id: str, conn: sqlite3.Connection) -> dict:
    rows = conn.execute(
        "SELECT stat_key, stat_value FROM user_achievement_progress WHERE user_id = ?",
        (user_id,),
    ).fetchall()
    return {r["stat_key"]: r["stat_value"] for r in rows}


def _get_unlocked_ids(user_id: str, conn: sqlite3.Connection) -> set:
    rows = conn.execute(
        "SELECT achievement_id FROM user_achievements WHERE user_id = ?",
        (user_id,),
    ).fetchall()
    return {r["achievement_id"] for r in rows}


def _check_single(stats: dict, a: AchievementDefinition) -> bool:
    """単一の実績定義に対して解除条件をチェック"""
    if a.criteria_type == "cross_app":
        return _check_cross_app(stats, a)
    else:
        current = stats.get(a.criteria_type, 0)
        return current >= a.criteria_value


def _check_cross_app(stats: dict, a: AchievementDefinition) -> bool:
    """cross_app 型実績のチェック。sub_criteria の全条件を満たす必要がある。"""
    if not a.sub_criteria:
        return False
    for key, threshold in a.sub_criteria.items():
        current = stats.get(key, 0)
        if current < threshold:
            return False
    return True


def _compute_progress(a: AchievementDefinition, stats: dict) -> Optional[dict]:
    """進捗情報を計算"""
    if a.criteria_type == "cross_app":
        if not a.sub_criteria:
            return None
        completed = sum(
            1 for key, threshold in a.sub_criteria.items()
            if stats.get(key, 0) >= threshold
        )
        total = len(a.sub_criteria)
        return {
            "current": completed,
            "target": total,
            "pct": round(completed / total * 100, 1) if total > 0 else 0.0,
        }
    else:
        current = stats.get(a.criteria_type, 0)
        target = a.criteria_value
        if target <= 0:
            return None
        return {
            "current": current,
            "target": target,
            "pct": round(min(current / target, 1.0) * 100, 1),
        }
