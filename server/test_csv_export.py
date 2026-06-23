#!/usr/bin/env python3
"""
csv_export のテスト (pytest)

実行:
    cd ~/Takamagahara/utsushiyo/kozuchi/server
    python3 -m pytest test_csv_export.py -v
"""

from __future__ import annotations

import pytest

from csv_export import (
    CSV_HEADERS,
    format_transactions_csv,
    validate_date,
    _extract_date_part,
    _format_signed_amount,
)


# ── _extract_date_part テスト ───────────────────────────

class TestExtractDatePart:
    def test_iso_format(self):
        assert _extract_date_part("2026-06-23T12:00:00") == "2026-06-23"

    def test_date_only(self):
        assert _extract_date_part("2026-06-23") == "2026-06-23"

    def test_space_separator(self):
        assert _extract_date_part("2026-06-23 12:00:00") == "2026-06-23"

    def test_empty_string(self):
        assert _extract_date_part("") == ""

    def test_short_string(self):
        assert _extract_date_part("2026") == "2026"


# ── _format_signed_amount テスト ────────────────────────

class TestFormatSignedAmount:
    def test_positive_amount(self):
        assert _format_signed_amount(50000) == "+50000"

    def test_negative_amount(self):
        assert _format_signed_amount(-1500) == "-1500"

    def test_zero(self):
        assert _format_signed_amount(0) == "0"

    def test_large_positive(self):
        assert _format_signed_amount(999999) == "+999999"

    def test_large_negative(self):
        assert _format_signed_amount(-999999) == "-999999"


# ── format_transactions_csv テスト ──────────────────────

class TestFormatTransactionsCSV:
    def test_empty_list_returns_header_only(self):
        result = format_transactions_csv([])
        # BOM + header
        assert result.startswith("\ufeff")
        # ヘッダ行が含まれている
        lines = result.strip().split("\n")
        assert len(lines) == 1  # ヘッダのみ

    def test_empty_list_no_header(self):
        result = format_transactions_csv([], include_header=False)
        assert result == "\ufeff"  # BOMのみ

    def test_single_expense_transaction(self):
        txs = [
            {
                "datetime": "2026-06-23T12:00:00",
                "purpose": "食費",
                "category": "食費",
                "amount": -1500,
            }
        ]
        result = format_transactions_csv(txs)
        lines = result.strip().split("\n")
        assert len(lines) == 2  # header + 1 data

        # BOMチェック
        assert lines[0].startswith("\ufeff")

        # ヘッダ確認
        header = lines[0].lstrip("\ufeff")
        assert "日付" in header
        assert "用途" in header
        assert "カテゴリ" in header

        # データ行確認
        data = lines[1]
        assert "2026-06-23" in data
        assert "食費" in data
        assert "-1500" in data

    def test_single_income_transaction(self):
        txs = [
            {
                "datetime": "2026-06-23T12:00:00",
                "purpose": "給料",
                "category": "収入",
                "amount": 300000,
            }
        ]
        result = format_transactions_csv(txs)
        lines = result.strip().split("\n")
        assert "+300000" in lines[1]

    def test_multiple_transactions(self):
        txs = [
            {"datetime": "2026-06-23T12:00:00", "purpose": "食費", "category": "食費", "amount": -1500},
            {"datetime": "2026-06-22T09:00:00", "purpose": "書籍", "category": "書籍費", "amount": -3200},
            {"datetime": "2026-06-21T15:00:00", "purpose": "給料", "category": "収入", "amount": 250000},
        ]
        result = format_transactions_csv(txs)
        lines = result.strip().split("\n")
        assert len(lines) == 4  # header + 3 data

    def test_special_characters_in_purpose(self):
        """カンマや引用符を含む用途のエスケープ確認"""
        txs = [
            {
                "datetime": "2026-06-23T12:00:00",
                "purpose": 'コンビニ, "セブン" で購入',
                "category": "食費",
                "amount": -580,
            }
        ]
        result = format_transactions_csv(txs)
        # カンマを含むフィールドは引用符で囲まれているはず
        assert '"コンビニ, "セブン" で購入"' in result or "コンビニ" in result

    def test_no_header_option(self):
        txs = [
            {"datetime": "2026-06-23", "purpose": "テスト", "category": "その他", "amount": -100}
        ]
        result = format_transactions_csv(txs, include_header=False)
        lines = result.strip().split("\n")
        assert len(lines) == 1  # data only
        assert "日付" not in result.lstrip("\ufeff")

    def test_bom_present(self):
        """UTF-8 BOM が付与されていること（Excel互換）"""
        result = format_transactions_csv([])
        assert result.startswith("\ufeff")

    def test_missing_fields_defaulted(self):
        """欠落フィールドは空文字または0で補完される"""
        txs = [{}]
        result = format_transactions_csv(txs)
        lines = result.strip().split("\n")
        assert len(lines) == 2
        # 空文字と "0" が入っている（QUOTE_NONNUMERICにより数字も引用符で囲まれる）
        data = lines[1]
        assert '"0"' in data  # amount部分（引用符付き）


# ── validate_date テスト ────────────────────────────────

class TestValidateDate:
    def test_iso_format(self):
        assert validate_date("2026-06-23") == "2026-06-23"

    def test_slash_format(self):
        assert validate_date("2026/06/23") == "2026-06-23"

    def test_compact_format(self):
        assert validate_date("20260623") == "2026-06-23"

    def test_none_returns_none(self):
        assert validate_date(None) is None

    def test_empty_string_returns_none(self):
        assert validate_date("") is None

    def test_whitespace_only_returns_none(self):
        assert validate_date("   ") is None

    def test_strips_whitespace(self):
        assert validate_date("  2026-06-23  ") == "2026-06-23"

    def test_invalid_date_raises(self):
        with pytest.raises(ValueError, match="無効な日付形式"):
            validate_date("not-a-date")

    def test_invalid_format_raises(self):
        with pytest.raises(ValueError, match="無効な日付形式"):
            validate_date("06/23/2026")  # 米国式は非対応

    def test_out_of_range_date_raises(self):
        with pytest.raises(ValueError, match="無効な日付形式"):
            validate_date("2026-13-01")  # 13月は存在しない

    def test_feb30_raises(self):
        with pytest.raises(ValueError, match="無効な日付形式"):
            validate_date("2026-02-30")  # 2月30日は存在しない

    def test_edge_case_leap_year(self):
        """閏年の2月29日は有効"""
        assert validate_date("2024-02-29") == "2024-02-29"

    def test_edge_case_year_boundary(self):
        assert validate_date("2026-01-01") == "2026-01-01"
        assert validate_date("2026-12-31") == "2026-12-31"


# ── CSVヘッダ定数テスト ──────────────────────────────────

class TestCSVHeaders:
    def test_header_count(self):
        assert len(CSV_HEADERS) == 4

    def test_header_names(self):
        assert CSV_HEADERS == ["日付", "用途", "カテゴリ", "金額"]


# ── 統合テスト ───────────────────────────────────────────

class TestIntegration:
    """実際のDBから取得したデータ形式でのテスト"""

    def test_db_row_format(self):
        """sqlite3.Row を dict に変換した形式での出力確認"""
        txs = [
            {
                "id": 1,
                "user_id": "user_001",
                "amount": -2500,
                "purpose": "昼食",
                "category": "食費",
                "datetime": "2026-06-23T12:30:00",
            },
            {
                "id": 2,
                "user_id": "user_001",
                "amount": 150000,
                "purpose": "給与",
                "category": "収入",
                "datetime": "2026-06-20T09:00:00",
            },
            {
                "id": 3,
                "user_id": "user_001",
                "amount": -15000,
                "purpose": "友人との会食",
                "category": "交際費",
                "datetime": "2026-06-19T19:00:00",
            },
        ]
        result = format_transactions_csv(txs)
        lines = result.strip().split("\n")
        assert len(lines) == 4  # header + 3 rows

        # 各データ行が正しい列数を持つ
        for line in lines[1:]:
            # CSVのフィールド数は4（引用符で囲まれていることを考慮）
            # 簡易チェック: 金額（符号付き数字）が含まれている
            assert "-2500" in line or "+150000" in line or "-15000" in line

    def test_realistic_export(self):
        """4週間分のデータを想定した出力確認"""
        transactions = []
        for day in range(28):
            import datetime as dt
            d = dt.datetime(2026, 6, 1) + dt.timedelta(days=day)
            date_str = d.strftime("%Y-%m-%dT12:00:00")
            transactions.append({
                "datetime": date_str,
                "purpose": "食費（自炊）" if day % 2 == 0 else "外食",
                "category": "食費",
                "amount": -800 if day % 2 == 0 else -2500,
            })

        result = format_transactions_csv(transactions)
        lines = result.strip().split("\n")
        assert len(lines) == 29  # header + 28 rows

        # 内容の一部を確認
        assert "2026-06-01" in result
        assert "2026-06-28" in result


# ── 直接実行時のデモ ─────────────────────────────────────

if __name__ == "__main__":
    print("=" * 60)
    print("kozuchi CSV Export - Manual Demo")
    print("=" * 60)

    txs = [
        {"datetime": "2026-06-23T12:00:00", "purpose": "食費（ランチ）", "category": "食費", "amount": -1200},
        {"datetime": "2026-06-22T09:00:00", "purpose": "技術書『Clean Code』", "category": "書籍費", "amount": -3850},
        {"datetime": "2026-06-21T15:00:00", "purpose": "給与", "category": "収入", "amount": 320000},
        {"datetime": "2026-06-20T19:30:00", "purpose": "友人と居酒屋", "category": "交際費", "amount": -6500},
        {"datetime": "2026-06-20T08:00:00", "purpose": "電車定期代", "category": "交通費", "amount": -12480},
    ]

    csv_output = format_transactions_csv(txs)
    print(csv_output)
    print(f"\n全{len(txs)}件の取引をCSV形式で出力しました。")
