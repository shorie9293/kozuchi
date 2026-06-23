#!/usr/bin/env python3
"""
kozuchi CSV export formatter

取引データをCSV形式に変換するモジュール。
使用文字コードは UTF-8（BOM付き）で、Excelでも文字化けしない。
"""

from __future__ import annotations

import csv
import io
from datetime import datetime
from typing import Optional, Sequence


# CSVカラム名（日本語ヘッダ）
CSV_HEADERS = ["日付", "用途", "カテゴリ", "金額"]

# 入出金の符号付き書式用プレフィックス
INCOME_PREFIX = "+"
EXPENSE_PREFIX = "-"


def format_transactions_csv(
    transactions: Sequence[dict],
    *,
    include_header: bool = True,
) -> str:
    """
    取引データのリストをCSV文字列に変換する。

    Args:
        transactions: dictのリスト。各dictは keys: datetime, purpose, category, amount
        include_header: ヘッダ行を含めるか（デフォルト: True）

    Returns:
        UTF-8 BOM付きCSV文字列
    """
    output = io.StringIO()
    writer = csv.writer(output, quoting=csv.QUOTE_NONNUMERIC, lineterminator="\n")

    if include_header:
        writer.writerow(CSV_HEADERS)

    for tx in transactions:
        # 日付: ISO形式から日付部分のみ抽出
        dt_str = tx.get("datetime", "")
        date_part = _extract_date_part(dt_str)

        # 用途
        purpose = tx.get("purpose", "")

        # カテゴリ
        category = tx.get("category", "")

        # 金額（符号付き: 正=収入, 負=支出）
        amount = tx.get("amount", 0)
        signed_amount = _format_signed_amount(amount)

        writer.writerow([date_part, purpose, category, signed_amount])

    # BOM付きUTF-8で返す
    return "\ufeff" + output.getvalue()


def _extract_date_part(datetime_str: str) -> str:
    """
    ISO 8601 日時文字列から日付部分 (YYYY-MM-DD) を抽出する。
    失敗時は元の文字列をそのまま返す。
    """
    if not datetime_str:
        return ""
    # "2026-06-23T12:00:00" → "2026-06-23"
    # "2026-06-23" → "2026-06-23"
    if "T" in datetime_str:
        return datetime_str.split("T")[0]
    if " " in datetime_str:
        return datetime_str.split(" ")[0]
    return datetime_str[:10] if len(datetime_str) >= 10 else datetime_str


def _format_signed_amount(amount: int) -> str:
    """
    金額を符号付き文字列に変換する。
    例: -1500 → "-1500", 50000 → "+50000", 0 → "0"
    """
    if amount > 0:
        return f"+{amount}"
    elif amount < 0:
        return str(amount)  # 負号はそのまま（例: "-1500"）
    return "0"


def validate_date(date_str: Optional[str]) -> Optional[str]:
    """
    日付文字列をバリデーションし、正規化された YYYY-MM-DD 形式で返す。
    無効な日付の場合は ValueError を送出する。
    None または空文字列の場合は None を返す（パラメータ未指定）。
    """
    if date_str is None or date_str.strip() == "":
        return None

    date_str = date_str.strip()

    # 許容する形式:
    #   YYYY-MM-DD
    #   YYYY/MM/DD
    #   YYYYMMDD
    for fmt in ("%Y-%m-%d", "%Y/%m/%d", "%Y%m%d"):
        try:
            dt = datetime.strptime(date_str, fmt)
            return dt.strftime("%Y-%m-%d")
        except ValueError:
            continue

    raise ValueError(
        f"無効な日付形式です: '{date_str}'. "
        f"YYYY-MM-DD 形式で指定してください。"
    )
