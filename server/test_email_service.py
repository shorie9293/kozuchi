#!/usr/bin/env python3
"""
email_service のテスト (pytest)

実行:
    cd ~/Takamagahara/utsushiyo/kozuchi/server
    python3 -m pytest test_email_service.py -v
"""

from __future__ import annotations

import pytest

from email_service import (
    validate_email,
    check_rate_limit,
    send_csv_email,
    EmailSendError,
    RATE_LIMIT_MAX,
    RATE_LIMIT_WINDOW,
    _count_csv_rows,
    _rate_limit_store,
)


# ── validate_email テスト ────────────────────────────────

class TestValidateEmail:
    def test_valid_simple(self):
        assert validate_email("user@example.com") is True

    def test_valid_jp_domain(self):
        assert validate_email("horie@sholliencohol.jp") is True

    def test_valid_gmail(self):
        assert validate_email("Horie.shunta@gmail.com") is True

    def test_valid_plus_tag(self):
        assert validate_email("user+tag@example.com") is True

    def test_invalid_empty(self):
        assert validate_email("") is False

    def test_invalid_none(self):
        assert validate_email(None) is False  # type: ignore

    def test_invalid_no_at(self):
        assert validate_email("userexample.com") is False

    def test_invalid_double_at(self):
        assert validate_email("user@@example.com") is False

    def test_invalid_no_domain(self):
        assert validate_email("user@") is False

    def test_invalid_too_long(self):
        long_email = "a" * 250 + "@example.com"
        assert validate_email(long_email) is False

    def test_invalid_special_chars(self):
        assert validate_email("user name@example.com") is False


# ── check_rate_limit テスト ─────────────────────────────

class TestRateLimit:
    def setup_method(self):
        """各テスト前にレート制限ストアをクリア"""
        _rate_limit_store.clear()

    def test_first_request_allowed(self):
        assert check_rate_limit("192.168.1.1") is True

    def test_multiple_requests_within_limit(self):
        for _ in range(RATE_LIMIT_MAX - 1):
            assert check_rate_limit("192.168.1.1") is True

    def test_rate_limit_exceeded(self):
        for _ in range(RATE_LIMIT_MAX):
            assert check_rate_limit("192.168.1.1") is True
        # 上限超過
        assert check_rate_limit("192.168.1.1") is False

    def test_different_keys_independent(self):
        # IP 1 を使い切る
        for _ in range(RATE_LIMIT_MAX):
            check_rate_limit("192.168.1.1")
        # IP 2 はまだ使える
        assert check_rate_limit("192.168.1.2") is True

    def test_email_key_independent_from_ip(self):
        # IPベースを使い切る
        for _ in range(RATE_LIMIT_MAX):
            check_rate_limit("192.168.1.1")
        # メールベースは別キー
        assert check_rate_limit("email:user@example.com") is True


# ── _count_csv_rows テスト ───────────────────────────────

class TestCountCsvRows:
    def test_header_only(self):
        csv = "\ufeff日付,用途,カテゴリ,金額\n"
        assert _count_csv_rows(csv) == 0

    def test_one_row(self):
        csv = "\ufeff日付,用途,カテゴリ,金額\n2026-06-23,食費,食費,-800\n"
        assert _count_csv_rows(csv) == 1

    def test_multiple_rows(self):
        csv = (
            "\ufeff日付,用途,カテゴリ,金額\n"
            "2026-06-23,食費,食費,-800\n"
            "2026-06-22,交通費,交通費,-1200\n"
            "2026-06-21,書籍費,書籍費,-4000\n"
        )
        assert _count_csv_rows(csv) == 3

    def test_no_bom(self):
        csv = "日付,用途,カテゴリ,金額\n2026-06-23,食費,食費,-800\n"
        assert _count_csv_rows(csv) == 1

    def test_trailing_newline(self):
        csv = "\ufeff日付,用途,カテゴリ,金額\n2026-06-23,食費,食費,-800\n\n"
        assert _count_csv_rows(csv) == 1

    def test_empty_string(self):
        assert _count_csv_rows("") == 0


# ── send_csv_email テスト（SMTPなし） ─────────────────────

class TestSendCsvEmailValidation:
    """SMTP接続なしでバリデーション系のみテスト"""

    def test_invalid_email_raises_value_error(self):
        with pytest.raises(ValueError, match="無効なメールアドレス"):
            send_csv_email("invalid-email", "csv,content")

    def test_empty_csv_raises_value_error(self):
        with pytest.raises(ValueError, match="CSVデータが空"):
            send_csv_email("user@example.com", "")
