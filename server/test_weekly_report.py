#!/usr/bin/env python3
"""
weekly_report.py のテストスイート。

実行: cd server && python3 -m pytest test_weekly_report.py -v
"""
import json
import os
import sys
import tempfile
from datetime import datetime, timedelta
from pathlib import Path

import pytest

# サーバーディレクトリをパスに追加
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from weekly_report import (
    parse_week,
    aggregate_weekly,
    compute_satori_change,
    generate_advice,
    generate_weekly_report,
    get_current_week_str,
    get_week_transactions,
    _ensure_reports_table,
    store_report,
    get_stored_report,
)


# ── Fixtures ────────────────────────────────────────────

@pytest.fixture
def sample_transactions_current():
    """今週のサンプル取引データ"""
    return [
        {"amount": -1200, "purpose": "昼食", "category": "食費", "datetime": "2026-06-15T12:00:00"},
        {"amount": -800, "purpose": "コーヒー", "category": "食費", "datetime": "2026-06-16T08:00:00"},
        {"amount": -2000, "purpose": "ディナー", "category": "外食費", "datetime": "2026-06-17T19:00:00"},
        {"amount": -3500, "purpose": "ゲーム", "category": "娯楽費", "datetime": "2026-06-18T20:00:00"},
        {"amount": -500, "purpose": "電車", "category": "交通費", "datetime": "2026-06-19T09:00:00"},
        {"amount": -1500, "purpose": "本", "category": "書籍費", "datetime": "2026-06-20T14:00:00"},
        {"amount": -3000, "purpose": "飲み会", "category": "交際費", "datetime": "2026-06-20T20:00:00"},
        {"amount": -600, "purpose": "日用品", "category": "日用品費", "datetime": "2026-06-21T10:00:00"},
    ]


@pytest.fixture
def sample_transactions_previous():
    """先週のサンプル取引データ（支出多め）"""
    return [
        {"amount": -1500, "purpose": "昼食", "category": "食費", "datetime": "2026-06-08T12:00:00"},
        {"amount": -1000, "purpose": "コーヒー", "category": "食費", "datetime": "2026-06-09T08:00:00"},
        {"amount": -5000, "purpose": "高級ディナー", "category": "外食費", "datetime": "2026-06-10T19:00:00"},
        {"amount": -8000, "purpose": "旅行", "category": "娯楽費", "datetime": "2026-06-11T10:00:00"},
        {"amount": -3000, "purpose": "服", "category": "被服費", "datetime": "2026-06-12T15:00:00"},
    ]


@pytest.fixture
def sample_transactions_with_income():
    """収入を含む取引データ"""
    return [
        {"amount": 150000, "purpose": "給与", "category": "収入", "datetime": "2026-06-15T00:00:00"},
        {"amount": -1200, "purpose": "昼食", "category": "食費", "datetime": "2026-06-15T12:00:00"},
        {"amount": -3500, "purpose": "ゲーム", "category": "娯楽費", "datetime": "2026-06-18T20:00:00"},
    ]


@pytest.fixture
def empty_transactions():
    """取引なし"""
    return []


# ── parse_week テスト ──────────────────────────────────

class TestParseWeek:
    def test_parse_week_25_2026(self):
        """2026-W25 → 2026-06-15(Mon) ~ 2026-06-21(Sun)"""
        monday, sunday = parse_week("2026-W25")
        assert monday.year == 2026
        assert monday.month == 6
        assert monday.day == 15
        assert monday.weekday() == 0  # Monday

        assert sunday.year == 2026
        assert sunday.month == 6
        assert sunday.day == 21
        assert sunday.hour == 23

    def test_parse_week_1_2026(self):
        """2026-W01 → first week of 2026"""
        monday, sunday = parse_week("2026-W01")
        assert monday.weekday() == 0
        assert sunday.weekday() == 6

    def test_get_current_week_str_returns_valid_format(self):
        """get_current_week_str() が 'YYYY-WWW' 形式を返す"""
        week_str = get_current_week_str()
        parts = week_str.split("-W")
        assert len(parts) == 2
        assert 2020 <= int(parts[0]) <= 2030
        assert 1 <= int(parts[1]) <= 53


# ── aggregate_weekly テスト ────────────────────────────

class TestAggregateWeekly:
    def test_with_expenses_only(self, sample_transactions_current):
        """支出のみの集計"""
        result = aggregate_weekly(sample_transactions_current)
        assert result["total_income"] == 0
        assert result["total_expense"] == 13100
        assert result["savings"] == -13100
        assert result["savings_rate"] == 0.0
        assert result["transaction_count"] == 8

    def test_with_income(self, sample_transactions_with_income):
        """収入を含む集計"""
        result = aggregate_weekly(sample_transactions_with_income)
        assert result["total_income"] == 150000
        assert result["total_expense"] == 4700
        assert result["savings"] == 145300
        assert round(result["savings_rate"], 3) == round(145300 / 150000, 3)
        assert result["transaction_count"] == 3

    def test_empty(self, empty_transactions):
        """取引なし"""
        result = aggregate_weekly(empty_transactions)
        assert result["total_income"] == 0
        assert result["total_expense"] == 0
        assert result["savings"] == 0
        assert result["savings_rate"] == 0.0
        assert result["transaction_count"] == 0

    def test_categories_sorted_by_amount(self, sample_transactions_current):
        """カテゴリが金額降順でソートされる"""
        result = aggregate_weekly(sample_transactions_current)
        cats = result["by_category"]
        assert cats[0]["amount"] >= cats[1]["amount"] >= cats[2]["amount"]

    def test_category_percentages(self, sample_transactions_current):
        """カテゴリのパーセンテージが正しい"""
        result = aggregate_weekly(sample_transactions_current)
        cats = result["by_category"]
        total_pct = sum(c["percentage"] for c in cats)
        assert 99.0 <= total_pct <= 101.0  # 丸め誤差許容

    def test_uncategorized_uses_default(self):
        """カテゴリ未設定は「未分類」になる"""
        txs = [{"amount": -500, "purpose": "???", "category": "", "datetime": "2026-06-15T12:00:00"}]
        result = aggregate_weekly(txs)
        assert result["by_category"][0]["category"] == "未分類"


# ── compute_satori_change テスト ───────────────────────

class TestComputeSatoriChange:
    def test_increase_large(self):
        """貯蓄率が5%以上改善 → ↑↑"""
        current = {"savings_rate": 0.30}
        previous = {"savings_rate": 0.20}
        result = compute_satori_change(current, previous)
        assert result["direction"] == "increase"
        assert result["symbol"] == "↑↑"
        assert result["delta"] == 0.10
        assert result["delta_percent"] == 10.0

    def test_increase_small(self):
        """貯蓄率が1%以上改善 → ↑"""
        current = {"savings_rate": 0.13}
        previous = {"savings_rate": 0.10}
        result = compute_satori_change(current, previous)
        assert result["direction"] == "increase"
        assert result["symbol"] == "↑"
        assert result["delta"] == 0.03

    def test_decrease_large(self):
        """貯蓄率が5%以上低下 → ↓↓"""
        current = {"savings_rate": 0.10}
        previous = {"savings_rate": 0.25}
        result = compute_satori_change(current, previous)
        assert result["direction"] == "decrease"
        assert result["symbol"] == "↓↓"
        assert result["delta"] == -0.15

    def test_decrease_small(self):
        """貯蓄率が1%以上低下 → ↓"""
        current = {"savings_rate": 0.08}
        previous = {"savings_rate": 0.10}
        result = compute_satori_change(current, previous)
        assert result["direction"] == "decrease"
        assert result["symbol"] == "↓"
        assert result["delta"] == -0.02

    def test_stable(self):
        """貯蓄率の変化が1%未満 → →"""
        current = {"savings_rate": 0.10}
        previous = {"savings_rate": 0.105}
        result = compute_satori_change(current, previous)
        assert result["direction"] == "stable"
        assert result["symbol"] == "→"

    def test_stable_zero_previous(self):
        """前期間の貯蓄率が0でも計算可能"""
        current = {"savings_rate": 0.05}
        previous = {"savings_rate": 0.0}
        result = compute_satori_change(current, previous)
        assert result["direction"] == "increase"
        assert result["delta"] == 0.05


# ── generate_advice テスト ────────────────────────────

class TestGenerateAdvice:
    def test_high_concentration(self):
        """1カテゴリが50%超 → 偏り警告"""
        current = {"total_income": 0, "total_expense": 10000, "savings_rate": 0.0, "transaction_count": 5}
        satori = {"direction": "stable", "delta": 0.0, "symbol": "→"}
        top = [{"category": "娯楽費", "amount": 6000, "percentage": 60.0}]
        advice = generate_advice(current, satori, top)
        assert "バランス" in advice
        assert "娯楽費" in advice

    def test_satori_decrease(self):
        """SATORI低下 → 自制を促す"""
        current = {"total_income": 0, "total_expense": 30000, "savings_rate": 0.0, "transaction_count": 3}
        satori = {"direction": "decrease", "delta": -0.08, "symbol": "↓↓"}
        top = [{"category": "食費", "amount": 10000, "percentage": 33.3}]
        advice = generate_advice(current, satori, top)
        assert "低下" in advice

    def test_satori_increase(self):
        """SATORI上昇 → 称賛"""
        current = {"total_income": 200000, "total_expense": 40000, "savings_rate": 0.8, "transaction_count": 10}
        satori = {"direction": "increase", "delta": 0.10, "symbol": "↑↑"}
        top = [{"category": "食費", "amount": 15000, "percentage": 37.5}]
        advice = generate_advice(current, satori, top)
        assert "素晴らしい" in advice or "改善" in advice

    def test_high_expense_warning(self):
        """支出総額が8万円超 → 注意喚起"""
        current = {"total_income": 0, "total_expense": 90000, "savings_rate": 0.0, "transaction_count": 15}
        satori = {"direction": "stable", "delta": 0.0, "symbol": "→"}
        top = [{"category": "食費", "amount": 30000, "percentage": 33.3}]
        advice = generate_advice(current, satori, top)
        assert "8万円" in advice or "一晩" in advice

    def test_empty_transactions(self):
        """取引なし → 記録促進"""
        current = {"total_income": 0, "total_expense": 0, "savings_rate": 0.0, "transaction_count": 0}
        satori = {"direction": "stable", "delta": 0.0, "symbol": "→"}
        top = []
        advice = generate_advice(current, satori, top)
        assert "取引データがありません" in advice or "記録" in advice

    def test_returns_string(self):
        """常に文字列を返す"""
        current = {"total_income": 100000, "total_expense": 30000, "savings_rate": 0.7, "transaction_count": 5}
        satori = {"direction": "stable", "delta": 0.0, "symbol": "→"}
        top = [{"category": "食費", "amount": 10000, "percentage": 33.3}]
        advice = generate_advice(current, satori, top)
        assert isinstance(advice, str)
        assert len(advice) > 0


# ── DB 統合テスト ──────────────────────────────────────

class TestDBIntegration:
    """SQLite DB を使った統合テスト"""

    @pytest.fixture
    def test_db(self):
        """テスト用の一時DBを作成"""
        fd, db_path = tempfile.mkstemp(suffix=".db")
        os.close(fd)

        import weekly_report
        original_path = weekly_report.DB_PATH
        weekly_report.DB_PATH = Path(db_path)

        import sqlite3
        conn = sqlite3.connect(db_path)
        conn.execute("""
            CREATE TABLE transactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                amount INTEGER NOT NULL,
                purpose TEXT NOT NULL DEFAULT '',
                category TEXT NOT NULL DEFAULT '',
                datetime TEXT NOT NULL,
                created_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
        """)
        conn.commit()

        # Seed: 2 weeks of data for user_001
        # Week 25: 2026-06-15 ~ 2026-06-21
        txns = [
            ("user_001", -1200, "昼食", "食費", "2026-06-15T12:00:00"),
            ("user_001", -800, "コーヒー", "食費", "2026-06-16T08:00:00"),
            ("user_001", -2000, "ディナー", "外食費", "2026-06-17T19:00:00"),
            ("user_001", -3500, "ゲーム", "娯楽費", "2026-06-18T20:00:00"),
            ("user_001", -1500, "本", "書籍費", "2026-06-20T14:00:00"),
            # Week 24: 2026-06-08 ~ 2026-06-14
            ("user_001", -5000, "高級ディナー", "外食費", "2026-06-10T19:00:00"),
            ("user_001", -8000, "旅行", "娯楽費", "2026-06-11T10:00:00"),
            ("user_001", -3000, "服", "被服費", "2026-06-12T15:00:00"),
            # Income
            ("user_001", 100000, "給与", "収入", "2026-06-15T00:00:00"),
            ("user_001", 100000, "給与", "収入", "2026-06-08T00:00:00"),
        ]
        conn.executemany(
            "INSERT INTO transactions (user_id, amount, purpose, category, datetime) VALUES (?,?,?,?,?)",
            txns,
        )
        conn.commit()
        conn.close()

        yield db_path

        # Teardown
        weekly_report.DB_PATH = original_path
        os.unlink(db_path)

    def test_generate_weekly_report(self, test_db):
        """generate_weekly_report が完全なレポートを返す"""
        report = generate_weekly_report(
            user_id="user_001",
            week_str="2026-W25",
            use_cache=False,
        )
        assert report["user_id"] == "user_001"
        assert report["week"] == "2026-W25"
        assert report["period"]["start"] == "2026-06-15"
        assert report["period"]["end"] == "2026-06-21"
        assert report["summary"]["total_income"] == 100000
        assert report["summary"]["total_expense"] == 9000
        assert report["summary"]["savings"] == 91000
        assert report["summary"]["transaction_count"] == 6  # 5 expenses + 1 income

        # Top categories
        assert len(report["top_categories"]) <= 3

        # Satori
        assert "direction" in report["satori"]
        assert "symbol" in report["satori"]

        # Advice
        assert isinstance(report["advice"], str)
        assert len(report["advice"]) > 0

        # Not cached
        assert report["cached"] is False

    def test_generate_weekly_report_cached(self, test_db):
        """2回目の呼び出しはキャッシュを返す"""
        # First call - generates and stores
        report1 = generate_weekly_report(
            user_id="user_001",
            week_str="2026-W25",
            use_cache=False,
        )
        assert report1["cached"] is False

        # Second call - should return cached
        report2 = generate_weekly_report(
            user_id="user_001",
            week_str="2026-W25",
            use_cache=True,
        )
        assert report2["cached"] is True
        assert report2["week"] == report1["week"]
        assert report2["advice"] == report1["advice"]

    def test_generate_weekly_report_no_transactions(self, test_db):
        """取引のない週のレポート"""
        report = generate_weekly_report(
            user_id="user_001",
            week_str="2026-W20",  # No data
            use_cache=False,
        )
        assert report["summary"]["transaction_count"] == 0
        assert report["summary"]["total_expense"] == 0

    def test_generate_weekly_report_invalid_user(self, test_db):
        """存在しないユーザーでも空レポートを返す"""
        report = generate_weekly_report(
            user_id="nonexistent",
            week_str="2026-W25",
            use_cache=False,
        )
        assert report["user_id"] == "nonexistent"
        assert report["summary"]["transaction_count"] == 0

    def test_store_and_get_report(self, test_db):
        """store_report と get_stored_report の往復"""
        import sqlite3
        conn = sqlite3.connect(test_db)
        conn.row_factory = sqlite3.Row

        _ensure_reports_table(conn)

        from datetime import datetime
        week_start = datetime(2026, 6, 15)

        report = {
            "user_id": "user_001",
            "week": "2026-W25",
            "test_data": "hello world",
        }

        store_report(conn, "user_001", "2026-W25", week_start, report)
        retrieved = get_stored_report(conn, "user_001", "2026-W25")

        assert retrieved is not None
        assert retrieved["test_data"] == "hello world"

        # Non-existent
        assert get_stored_report(conn, "user_001", "2026-W99") is None

        conn.close()


# ── API 結合テスト ─────────────────────────────────────

class TestAPIEndpoint:
    """Flask API エンドポイントの結合テスト"""

    @pytest.fixture
    def client(self):
        """Flask テストクライアント（DB初期化済み）"""
        import random
        random.seed(42)

        from server.server import app, init_db, seed_demo_data
        init_db()
        seed_demo_data()
        app.config["TESTING"] = True
        with app.test_client() as client:
            yield client

    def test_health(self, client):
        """ヘルスチェック（既存）"""
        resp = client.get("/api/health")
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["status"] == "ok"

    def test_weekly_report_default(self, client):
        """デフォルトパラメータでレポート取得"""
        resp = client.get("/api/weekly-report")
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["user_id"] == "user_001"
        assert "week" in data
        assert "summary" in data
        assert "top_categories" in data
        assert "satori" in data
        assert "advice" in data
        assert "generated_at" in data
        # デモデータがあるので取引あり
        assert data["summary"]["transaction_count"] > 0

    def test_weekly_report_specific_week(self, client):
        """特定週を指定してレポート取得"""
        resp = client.get("/api/weekly-report?week=2026-W25&user_id=user_001&cache=false")
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["week"] == "2026-W25"

    def test_weekly_report_invalid_week(self, client):
        """無効な週文字列 → 400"""
        resp = client.get("/api/weekly-report?week=invalid")
        assert resp.status_code == 400
        data = resp.get_json()
        assert "error" in data

    def test_weekly_report_caching(self, client):
        """キャッシュ動作の確認"""
        # 1回目（生成）
        resp1 = client.get("/api/weekly-report?week=2026-W25&cache=false")
        assert resp1.status_code == 200
        data1 = resp1.get_json()
        assert data1["cached"] is False

        # 2回目（キャッシュ）
        resp2 = client.get("/api/weekly-report?week=2026-W25&cache=true")
        assert resp2.status_code == 200
        data2 = resp2.get_json()
        assert data2["cached"] is True

    def test_weekly_report_has_top_3_categories(self, client):
        """top_categories が最大3件"""
        resp = client.get("/api/weekly-report?cache=false")
        assert resp.status_code == 200
        data = resp.get_json()
        assert len(data["top_categories"]) <= 3
        for i, cat in enumerate(data["top_categories"]):
            assert cat["rank"] == i + 1
            assert "category" in cat
            assert "amount" in cat
            assert "percentage" in cat

    def test_weekly_report_satori_structure(self, client):
        """satori が完全な構造を持つ"""
        resp = client.get("/api/weekly-report?cache=false")
        assert resp.status_code == 200
        data = resp.get_json()
        satori = data["satori"]
        for key in ["current_rate", "previous_rate", "delta", "delta_percent", "direction", "symbol", "message"]:
            assert key in satori, f"Missing key: {key}"
        assert satori["direction"] in ("increase", "decrease", "stable")
        assert satori["symbol"] in ("↑↑", "↑", "→", "↓", "↓↓")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
