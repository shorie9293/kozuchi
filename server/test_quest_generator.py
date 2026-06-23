#!/usr/bin/env python3
"""
quest_generator のテスト (pytest)

実行:
    cd ~/Takamagahara/utsushiyo/kozuchi/server
    python3 -m pytest test_quest_generator.py -v
"""

from __future__ import annotations

import json
import random
from datetime import datetime, timedelta

import pytest

from quest_generator import (
    DIFFICULTY_REDUCTION,
    MIN_CATEGORY_WEEKLY_AVG,
    MIN_QUESTS,
    MAX_QUESTS,
    QuestCandidate,
    Transaction,
    analyze_spending,
    generate_weekly_quests,
    quests_to_dict,
    _find_deity,
    _generate_fallback_quests,
)


# ── テスト用ヘルパー ──────────────────────────────────────


def _make_transactions(
    categories: dict[str, list[int]],
    base_date: datetime | None = None,
) -> list[Transaction]:
    """カテゴリ別の支出リストから Transaction リストを生成"""
    if base_date is None:
        base_date = datetime.now()

    transactions = []
    for cat, weekly_amounts in categories.items():
        for week_idx, amount in enumerate(weekly_amounts):
            # 各週の月曜日
            d = base_date - timedelta(weeks=week_idx)
            date_str = d.strftime("%Y-%m-%dT12:00:00")
            if amount > 0:
                transactions.append(
                    Transaction(
                        amount=-amount,
                        purpose=f"{cat}の支出",
                        category=cat,
                        datetime=date_str,
                    )
                )
    return transactions


# ── analyze_spending テスト ──────────────────────────────


class TestAnalyzeSpending:
    def test_empty_transactions(self):
        result = analyze_spending([])
        assert result == {}

    def test_single_category_single_week(self):
        txs = _make_transactions({"食費": [5000, 0, 0, 0]})
        result = analyze_spending(txs)
        assert "食費" in result
        assert result["食費"]["weekly_avg"] == 5000

    def test_multi_category_multi_week(self):
        txs = _make_transactions({
            "食費": [4000, 6000, 5000, 5000],
            "娯楽費": [3000, 4000, 0, 2000],
        })
        result = analyze_spending(txs)
        assert "食費" in result
        assert "娯楽費" in result
        # 食費: (4000+6000+5000+5000)/4 = 5000
        assert result["食費"]["weekly_avg"] == 5000
        # 娯楽費: (3000+4000+2000)/3 = 3000
        assert result["娯楽費"]["weekly_avg"] == 3000

    def test_income_filtered_out(self):
        txs = [
            Transaction(amount=10000, purpose="給料", category="収入", datetime="2026-06-01T12:00:00"),
            Transaction(amount=-3000, purpose="食費", category="食費", datetime="2026-06-01T12:00:00"),
        ]
        result = analyze_spending(txs)
        assert "収入" not in result
        assert "食費" in result

    def test_old_transactions_excluded(self):
        old_date = (datetime.now() - timedelta(weeks=8)).strftime("%Y-%m-%dT12:00:00")
        txs = [
            Transaction(amount=-5000, purpose="古い支出", category="食費", datetime=old_date),
        ]
        result = analyze_spending(txs)
        assert result == {}  # 4週間以上前は除外

    def test_empty_category_handled(self):
        txs = [
            Transaction(amount=-1000, purpose="何か", category="  ", datetime="2026-06-15T12:00:00"),
        ]
        result = analyze_spending(txs)
        assert "その他" in result


# ── _find_deity テスト ──────────────────────────────────


class TestFindDeity:
    def test_exact_match(self):
        assert _find_deity("食費") == "大黒天"
        assert _find_deity("書籍費") == "弁財天"
        assert _find_deity("投資") == "毘沙門天"
        assert _find_deity("交際費") == "吉祥天"

    def test_unknown_category_defaults(self):
        assert _find_deity("不明カテゴリ") == "大黒天"

    def test_partial_match(self):
        # "趣味・娯楽" → "趣味費" に部分マッチ
        assert _find_deity("趣味・娯楽") in ("弁財天", "大黒天")


# ── generate_weekly_quests テスト ────────────────────────


class TestGenerateWeeklyQuests:
    def test_empty_transactions_returns_fallback(self):
        quests = generate_weekly_quests([], user_id="test", seed=42)
        assert 3 <= len(quests) <= 5

    def test_single_category(self):
        txs = _make_transactions({"食費": [5000, 5000, 5000, 5000]})
        quests = generate_weekly_quests(txs, user_id="test", seed=42)
        assert len(quests) >= 3
        # 食費カテゴリのクエストが含まれている
        categories = {q.category for q in quests}
        assert "食費" in categories

    def test_multi_category_generates_variety(self):
        txs = _make_transactions({
            "食費": [5000, 6000, 4000, 5000],
            "娯楽費": [3000, 4000, 2000, 5000],
            "書籍費": [2000, 0, 3000, 1000],
            "交際費": [4000, 3000, 5000, 2000],
            "交通費": [1000, 1500, 800, 1200],
        })
        quests = generate_weekly_quests(txs, user_id="test", seed=42)
        assert 3 <= len(quests) <= 5

        # カテゴリ重複がないこと
        cats = [q.category for q in quests]
        assert len(cats) == len(set(cats)), f"カテゴリ重複あり: {cats}"

    def test_all_quests_have_required_fields(self):
        txs = _make_transactions({"食費": [5000, 6000, 4000, 5000]})
        quests = generate_weekly_quests(txs, user_id="test", seed=42)

        for q in quests:
            assert q.id
            assert q.title
            assert q.description
            assert q.category
            assert q.target_amount > 0
            assert q.difficulty in DIFFICULTY_REDUCTION
            assert q.guardian_deity
            assert q.flavor_text
            assert q.recent_weekly_avg > 0
            assert 0 <= q.reduction_pct <= 100

    def test_target_amount_below_recent_avg(self):
        txs = _make_transactions({"食費": [10000, 10000, 10000, 10000]})
        quests = generate_weekly_quests(txs, user_id="test", seed=42)

        for q in quests:
            assert q.target_amount < q.recent_weekly_avg, (
                f"target={q.target_amount} >= avg={q.recent_weekly_avg}"
            )

    def test_minimum_3_quests(self):
        txs = _make_transactions({
            "食費": [5000, 5000, 5000, 5000],
            "娯楽費": [3000, 3000, 3000, 3000],
            "書籍費": [2000, 2000, 2000, 2000],
            "交際費": [4000, 4000, 4000, 4000],
            "交通費": [1000, 1000, 1000, 1000],
            "趣味費": [3000, 3000, 3000, 3000],
        })
        quests = generate_weekly_quests(txs, user_id="test", num_quests=5, seed=42)
        assert 3 <= len(quests) <= 5

    def test_reproducible_with_seed(self):
        txs = _make_transactions({"食費": [5000, 6000, 4000, 5000]})
        q1 = generate_weekly_quests(txs, user_id="test", seed=42)
        q2 = generate_weekly_quests(txs, user_id="test", seed=42)
        # ID と target_amount が一致することを確認
        assert [q.id for q in q1] == [q.id for q in q2]
        assert [q.target_amount for q in q1] == [q.target_amount for q in q2]

    def test_different_seeds_produce_different_results(self):
        txs = _make_transactions({
            "食費": [5000, 5000, 5000, 5000],
            "娯楽費": [3000, 3000, 3000, 3000],
            "書籍費": [2000, 2000, 2000, 2000],
            "交際費": [4000, 4000, 4000, 4000],
            "交通費": [1000, 1000, 1000, 1000],
        })
        q1 = generate_weekly_quests(txs, user_id="test", seed=1)
        q2 = generate_weekly_quests(txs, user_id="test", seed=2)
        # difficultyの組み合わせが異なる可能性が高い
        diffs1 = tuple(sorted(q.difficulty for q in q1))
        diffs2 = tuple(sorted(q.difficulty for q in q2))
        # 完全一致することもあるが、flavor_textは異なるはず
        flavors1 = {q.flavor_text for q in q1}
        flavors2 = {q.flavor_text for q in q2}
        assert flavors1 != flavors2 or diffs1 != diffs2

    def test_very_small_spending_excluded(self):
        """閾値(500円)未満のカテゴリはデータ駆動クエストの対象外"""
        txs = _make_transactions({
            "食費": [300, 300, 300, 300],   # 300円/週 → 分析対象外
            "娯楽費": [5000, 5000, 5000, 5000],
        })
        quests = generate_weekly_quests(txs, user_id="test", num_quests=5, seed=42)
        # 実際の支出データに基づくクエスト（fb接頭辞なし）に食費が含まれないこと
        data_driven = [q for q in quests if "_fb" not in q.id]
        data_categories = {q.category for q in data_driven}
        assert "食費" not in data_categories, (
            f"食費は閾値未満のためデータ駆動クエストに含まれるべきでない: {data_categories}"
        )
        # 娯楽費はデータ駆動クエストに含まれる
        assert "娯楽費" in data_categories


# ── quests_to_dict テスト ────────────────────────────────


class TestQuestsToDict:
    def test_converts_all_fields(self):
        q = QuestCandidate(
            id="quest_test_01",
            title="テストクエスト",
            description="説明文",
            category="食費",
            target_amount=5000,
            difficulty="medium",
            guardian_deity="大黒天",
            flavor_text="味付け",
            recent_weekly_avg=7000,
            reduction_pct=30,
        )
        result = quests_to_dict([q])
        assert len(result) == 1
        d = result[0]
        assert d["id"] == "quest_test_01"
        assert d["title"] == "テストクエスト"
        assert d["difficulty_label"] == "中級"
        assert d["category"] == "食費"
        assert d["target_amount"] == 5000


# ── _generate_fallback_quests テスト ─────────────────────


class TestFallbackQuests:
    def test_returns_requested_count(self):
        quests = _generate_fallback_quests("test", 3)
        assert len(quests) == 3

    def test_excludes_categories(self):
        quests = _generate_fallback_quests("test", 3, exclude_categories={"食費", "娯楽費"})
        cats = {q.category for q in quests}
        assert "食費" not in cats
        assert "娯楽費" not in cats


# ── 統合テスト ───────────────────────────────────────────


class TestIntegration:
    """実際のユースケースを模した統合テスト"""

    def test_realistic_user_scenario(self):
        """典型的なユーザーの4週間の支出データでテスト"""
        today = datetime.now()
        transactions = []

        # 食費: 毎日1000〜3000円（週平均約12000円）
        # 娯楽費: 週末に5000〜10000円（週平均約7000円）
        # 書籍費: 隔週で3000円程度（週平均約1500円）
        # 交際費: 月1回15000円（週平均約3750円）

        for week_offset in range(4):
            for day_offset in range(7):
                d = today - timedelta(weeks=week_offset, days=(6 - day_offset))
                date_str = d.strftime("%Y-%m-%dT12:00:00")

                # 食費（平日は安め、週末は高め）
                food = 1500 if day_offset >= 5 else 800
                transactions.append(Transaction(-food, "食費", "食費", date_str))

                # 娯楽費（週末のみ）
                if day_offset == 5 and week_offset % 2 == 0:
                    transactions.append(Transaction(-8000, "映画・ゲーム", "娯楽費", date_str))

                # 書籍費（月2回）
                if day_offset == 2 and week_offset % 2 == 0:
                    transactions.append(Transaction(-3500, "技術書", "書籍費", date_str))

            # 交際費（月1回）
            if week_offset == 1:
                transactions.append(Transaction(
                    -15000, "友人との食事会", "交際費",
                    (today - timedelta(weeks=1, days=2)).strftime("%Y-%m-%dT20:00:00"),
                ))

        quests = generate_weekly_quests(transactions, user_id="realistic_user", seed=42)

        # 検証
        assert 3 <= len(quests) <= 5
        assert len(quests) == len(set(q.category for q in quests)), "カテゴリ重複禁止"

        for q in quests:
            assert q.target_amount > 0
            assert q.target_amount < q.recent_weekly_avg
            assert q.guardian_deity
            assert q.flavor_text
            print(f"  {q.difficulty:8s} | {q.category:6s} | "
                  f"¥{q.target_amount:>6,} (avg ¥{q.recent_weekly_avg:>6,}) | "
                  f"{q.guardian_deity}")

        print(f"\n  Generated {len(quests)} quests successfully.")


# ── 直接実行時のデモ ─────────────────────────────────────

if __name__ == "__main__":
    print("=" * 60)
    print("kozuchi Quest Generator - Manual Demo")
    print("=" * 60)

    # デモ用データ
    today = datetime.now()
    demo_txs = []
    for week in range(4):
        d = today - timedelta(weeks=week, days=3)
        demo_txs.extend([
            Transaction(-5000, "食費", "食費", d.strftime("%Y-%m-%dT12:00:00")),
            Transaction(-8000, "娯楽費", "娯楽費", d.strftime("%Y-%m-%dT15:00:00")),
            Transaction(-3000, "書籍", "書籍費", d.strftime("%Y-%m-%dT18:00:00")),
            Transaction(-6000, "友人と食事", "交際費", d.strftime("%Y-%m-%dT20:00:00")),
        ])

    print(f"\n入力: {len(demo_txs)}件の取引 (4週間分)")
    print()

    quests = generate_weekly_quests(demo_txs, user_id="demo", seed=2026)
    for q in quests:
        print(f"  [{q.id}] {q.title}")
        print(f"    守護神: {q.guardian_deity} | 難易度: {q.difficulty}")
        print(f"    目標: ¥{q.target_amount:,} (直近週平均: ¥{q.recent_weekly_avg:,})")
        print(f"    {q.description}")
        print(f"    「{q.flavor_text}」")
        print()

    print(f"生成数: {len(quests)}")
