#!/usr/bin/env python3
"""
kozuchi 週間クエスト生成ロジック (Quest Generator)

毎週月曜に、ユーザーの支出履歴を分析し、カテゴリ別の支出制限
チャレンジを3〜5候補自動生成する。

設計方針:
- 過去4週間のカテゴリ別支出を分析
- 平均支出に対する割合で難易度を決定
- 守護神（四天）テーマに紐づくカテゴリ
- 候補のバリエーション確保（カテゴリ重複禁止・難易度分散）
- 外部APIとして呼び出し可能（関数インターフェース）

Usage:
    from quest_generator import generate_weekly_quests
    quests = generate_weekly_quests(transactions, user_id="user_001")
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Optional, Sequence

# ── データ型 ──────────────────────────────────────────────


@dataclass
class Transaction:
    """1件の取引（Flutter TransactionModel に対応）"""
    amount: int          # 負=支出, 正=収入
    purpose: str         # 用途
    category: str        # カテゴリ
    datetime: str        # ISO 8601 形式


@dataclass
class QuestCandidate:
    """生成されたクエスト候補"""
    id: str                      # 候補ID (例: "quest_001")
    title: str                   # クエスト名（日本語）
    description: str             # 説明文
    category: str                # 対象カテゴリ
    target_amount: int           # 目標支出上限額（円）
    difficulty: str              # "easy" | "medium" | "hard" | "stretch"
    guardian_deity: str          # 守護神名（大黒天/弁財天/毘沙門天/吉祥天）
    flavor_text: str             # RPG風味付けテキスト
    recent_weekly_avg: int       # 直近週平均（参考情報）
    reduction_pct: int           # 削減率（%）


# ── 定数 ──────────────────────────────────────────────────

# 守護神と紐づくカテゴリ
DEITY_CATEGORIES: dict[str, list[str]] = {
    "大黒天":  ["食費", "外食費", "日用品費", "生活費", "食材費", "家賃", "光熱費"],
    "弁財天":  ["書籍費", "教育費", "学習費", "教養費", "趣味費", "習い事"],
    "毘沙門天": ["投資", "自己投資", "ビジネス費", "通信費", "交通費", "医療費"],
    "吉祥天":  ["交際費", "娯楽費", "贈答費", "被服費", "美容費", "プレゼント"],
}

# 難易度別の削減率（直近平均に対する割合）
DIFFICULTY_REDUCTION: dict[str, float] = {
    "easy":    0.85,   # 平均の85% → 15%削減
    "medium":  0.70,   # 平均の70% → 30%削減
    "hard":    0.50,   # 平均の50% → 50%削減
    "stretch": 0.35,   # 平均の35% → 65%削減
}

# 難易度の表示名
DIFFICULTY_LABELS: dict[str, str] = {
    "easy":    "初級",
    "medium":  "中級",
    "hard":    "上級",
    "stretch": "達人",
}

# クエスト生成時の最小カテゴリ週平均（これ以下のカテゴリは対象外）
MIN_CATEGORY_WEEKLY_AVG = 500  # 円

# 生成するクエスト候補数
MIN_QUESTS = 3
MAX_QUESTS = 5


# ── 味付けテキスト生成 ───────────────────────────────────

FLAVOR_TEMPLATES: dict[str, list[str]] = {
    "大黒天": [
        "大黒天の試練「腹八分目の智慧」──満ち足りつつも慎ましく。",
        "福の神が告ぐ「糧を分かち、余剰を省みよ」──今週は食の節制を。",
        "打出の小槌は戒めと共に──大黒天が食の均衡を試す。",
    ],
    "弁財天": [
        "弁財天の琴線「智慧は選びてこそ輝く」──厳選の一冊を。",
        "芸術の女神が問う「汝、真に求むる智慧は何か」──学びの質を見極めよ。",
        "弁財天の試練「知の断捨離」──散財より深き一学を。",
    ],
    "毘沙門天": [
        "毘沙門天の戦訓「闘志は策と共に」──己への投資、狙いを定めよ。",
        "武神が試す「散漫なる投資は敗北なり」──一点集中の勝負金を。",
        "毘沙門天の掲ぐる旗「勝機は絞る者に宿る」──今週は戦略的支出を。",
    ],
    "吉祥天": [
        "吉祥天の微笑み「美は節度に宿る」──華美より真の美を。",
        "幸福の女神が諭す「与える悦びに溺るるなかれ」──贈る心と金を分かて。",
        "吉祥天の試練「心の豊かさは金にあらず」──今週は心尽くしの贈り物を。",
    ],
}


# ── コアロジック ──────────────────────────────────────────


def _parse_week(date_str: str) -> str:
    """ISO日時文字列から週識別子 (YYYY-Www) を返す"""
    try:
        dt = datetime.fromisoformat(date_str)
    except (ValueError, TypeError):
        return "unknown"
    iso = dt.isocalendar()
    return f"{iso[0]}-W{iso[1]:02d}"


def _get_recent_weeks(n: int = 4) -> list[str]:
    """直近n週の週識別子リストを返す"""
    today = datetime.now()
    weeks = []
    for i in range(n):
        d = today - timedelta(weeks=i)
        iso = d.isocalendar()
        weeks.append(f"{iso[0]}-W{iso[1]:02d}")
    return weeks


def analyze_spending(
    transactions: Sequence[Transaction],
    weeks: int = 4,
) -> dict[str, dict]:
    """
    取引履歴からカテゴリ別・週別の支出集計を行う。

    Returns:
        {
            "食費": {
                "weekly_totals": {"2026-W23": 12000, "2026-W24": 8000, ...},
                "weekly_avg": 9500,
                "recent_weeks_count": 4,
                "total_spent": 38000,
            },
            ...
        }
    """
    recent_weeks = set(_get_recent_weeks(weeks))

    # 支出のみ（amount < 0）を対象
    expenses = [t for t in transactions if t.amount < 0]

    # カテゴリ別に週ごと集計
    cat_weekly: dict[str, dict[str, int]] = {}
    for tx in expenses:
        cat = tx.category.strip()
        if not cat:
            cat = "その他"
        week = _parse_week(tx.datetime)
        if week not in recent_weeks:
            continue
        cat_weekly.setdefault(cat, {})
        cat_weekly[cat][week] = cat_weekly[cat].get(week, 0) + abs(tx.amount)

    # 集計結果を整形
    result = {}
    for cat, weekly in cat_weekly.items():
        totals = [weekly.get(w, 0) for w in recent_weeks]
        active_weeks = sum(1 for v in totals if v > 0)
        if active_weeks == 0:
            continue
        total_spent = sum(totals)
        weekly_avg = total_spent / active_weeks
        result[cat] = {
            "weekly_totals": {w: weekly.get(w, 0) for w in recent_weeks},
            "weekly_avg": round(weekly_avg),
            "recent_weeks_count": active_weeks,
            "total_spent": total_spent,
        }
    return result


def _find_deity(category: str) -> str:
    """カテゴリから関連する守護神を推定"""
    for deity, cats in DEITY_CATEGORIES.items():
        if category in cats:
            return deity
    # 部分一致で探索
    for deity, cats in DEITY_CATEGORIES.items():
        for c in cats:
            if c in category or category in c:
                return deity
    return "大黒天"  # デフォルト


def _gen_flavor(deity: str) -> str:
    """守護神に応じた味付けテキストをランダム生成"""
    templates = FLAVOR_TEMPLATES.get(deity, FLAVOR_TEMPLATES["大黒天"])
    return random.choice(templates)


def generate_weekly_quests(
    transactions: Sequence[Transaction],
    user_id: str = "default",
    num_quests: int = 0,
    seed: Optional[int] = None,
) -> list[QuestCandidate]:
    """
    週間クエスト候補を生成する。

    Args:
        transactions: 取引履歴（直近4週間分が推奨）
        user_id: ユーザー識別子
        num_quests: 生成数（0の場合は3〜5で自動決定）
        seed: 乱数シード（テスト再現性のため）

    Returns:
        3〜5件の QuestCandidate リスト
    """
    if seed is not None:
        random.seed(seed)

    if num_quests <= 0:
        # 利用可能なカテゴリ数に応じて動的に決定
        num_quests = MIN_QUESTS  # デフォルト

    # 1. 支出分析
    analysis = analyze_spending(transactions)

    if not analysis:
        # データが不足している場合のフォールバック
        return _generate_fallback_quests(user_id, num_quests)

    # 2. 対象カテゴリを選定（週平均が最低額以上のもの）
    eligible = {
        cat: data
        for cat, data in analysis.items()
        if data["weekly_avg"] >= MIN_CATEGORY_WEEKLY_AVG
    }

    if not eligible:
        eligible = analysis  # 全カテゴリ対象

    # 3. 利用可能なカテゴリ数に応じて生成数を調整
    available_cats = len(eligible)
    if available_cats <= 2:
        num_quests = min(available_cats, MIN_QUESTS)
    elif available_cats <= 4:
        num_quests = min(available_cats, MAX_QUESTS - 1)
    else:
        num_quests = min(num_quests, MAX_QUESTS) if num_quests > 0 else random.randint(MIN_QUESTS, min(available_cats, MAX_QUESTS))

    # 4. カテゴリを週平均の高い順にソート
    ranked = sorted(eligible.items(), key=lambda x: x[1]["weekly_avg"], reverse=True)

    # 5. 難易度をバリエーション豊かに割り当て
    difficulties = list(DIFFICULTY_REDUCTION.keys())
    # 最低1つは easy、1つは hard/stretch を含める
    difficulty_pool = ["easy", "medium", "medium", "hard", "stretch"]

    quests: list[QuestCandidate] = []
    used_categories: set[str] = set()
    used_difficulties: list[str] = []

    for i in range(min(num_quests, len(ranked))):
        cat_name, cat_data = ranked[i]

        # 重複カテゴリを避ける
        if cat_name in used_categories:
            continue

        # 難易度を選択（使われていないものを優先）
        available_diffs = [d for d in difficulty_pool if d not in used_difficulties]
        if not available_diffs:
            available_diffs = difficulty_pool
        difficulty = random.choice(available_diffs)

        reduction = DIFFICULTY_REDUCTION[difficulty]
        target = max(300, round(cat_data["weekly_avg"] * reduction))
        # 100円単位に丸める
        target = (target // 100) * 100

        deity = _find_deity(cat_name)
        flavor = _gen_flavor(deity)

        difficulty_label = DIFFICULTY_LABELS[difficulty]
        reduction_pct = round((1 - reduction) * 100)

        quest_id = f"quest_{user_id}_{i+1:02d}"
        title = f"【{difficulty_label}】今週の{cat_name}制限"

        description = (
            f"今週の{cat_name}を¥{target:,}以内に収めよ。"
            f"直近の週平均¥{cat_data['weekly_avg']:,}から"
            f"{reduction_pct}%の削減に挑む。"
        )

        quest = QuestCandidate(
            id=quest_id,
            title=title,
            description=description,
            category=cat_name,
            target_amount=target,
            difficulty=difficulty,
            guardian_deity=deity,
            flavor_text=flavor,
            recent_weekly_avg=cat_data["weekly_avg"],
            reduction_pct=reduction_pct,
        )
        quests.append(quest)
        used_categories.add(cat_name)
        used_difficulties.append(difficulty)

    # 6. 足りない場合はフォールバック
    if len(quests) < MIN_QUESTS:
        fallback = _generate_fallback_quests(
            user_id,
            MIN_QUESTS - len(quests),
            exclude_categories=used_categories,
        )
        quests.extend(fallback)

    # 7. 最終的に3〜5件に調整
    quests = quests[:MAX_QUESTS]
    if len(quests) < MIN_QUESTS and len(quests) > 0:
        # 足りなくても最低1件は返す
        pass

    return quests


def _generate_fallback_quests(
    user_id: str,
    count: int,
    exclude_categories: set[str] | None = None,
) -> list[QuestCandidate]:
    """データが不足している場合の汎用クエスト候補"""
    exclude = exclude_categories or set()

    fallback_templates = [
        ("食費", "大黒天", 5000, "easy", "今週の食費を見直し、無駄を省く試練。"),
        ("娯楽費", "吉祥天", 3000, "medium", "娯楽はほどほどに。心の豊かさは金にあらず。"),
        ("外食費", "大黒天", 4000, "medium", "自炊の智慧を磨く一週間。外食は控えめに。"),
        ("書籍費", "弁財天", 2000, "hard", "真に価値ある一冊を見極めよ。"),
        ("交際費", "吉祥天", 5000, "easy", "心尽くしの交際を。金を使わぬもてなしを。"),
        ("交通費", "毘沙門天", 3000, "medium", "移動を見直し、効率的な戦略を練れ。"),
        ("趣味費", "弁財天", 3000, "hard", "趣味の質を高め、無駄な散財を避けよ。"),
        ("被服費", "吉祥天", 5000, "easy", "衣は清潔であれば十分。華美より実を取れ。"),
    ]

    result = []
    fb_idx = 0
    template_idx = 0
    attempts = 0
    max_attempts = len(fallback_templates) * 3  # 無限ループ防止

    while fb_idx < count and attempts < max_attempts:
        template = fallback_templates[template_idx % len(fallback_templates)]
        cat, deity, target, diff, flavor = template

        if cat not in exclude:
            quest = QuestCandidate(
                id=f"quest_{user_id}_fb{fb_idx+1:02d}",
                title=f"【{DIFFICULTY_LABELS[diff]}】今週の{cat}制限",
                description=f"今週の{cat}を¥{target:,}以内に。{flavor}",
                category=cat,
                target_amount=target,
                difficulty=diff,
                guardian_deity=deity,
                flavor_text=flavor,
                recent_weekly_avg=target * 2,
                reduction_pct=50,
            )
            result.append(quest)
            exclude.add(cat)
            fb_idx += 1

        template_idx += 1
        attempts += 1

    return result


def quests_to_dict(quests: Sequence[QuestCandidate]) -> list[dict]:
    """QuestCandidateリストをJSON互換のdictリストに変換"""
    return [
        {
            "id": q.id,
            "title": q.title,
            "description": q.description,
            "category": q.category,
            "target_amount": q.target_amount,
            "difficulty": q.difficulty,
            "difficulty_label": DIFFICULTY_LABELS.get(q.difficulty, q.difficulty),
            "guardian_deity": q.guardian_deity,
            "flavor_text": q.flavor_text,
            "recent_weekly_avg": q.recent_weekly_avg,
            "reduction_pct": q.reduction_pct,
        }
        for q in quests
    ]
