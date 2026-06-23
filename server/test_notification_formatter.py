#!/usr/bin/env python3
"""
notification_formatter のテスト (pytest)

Push通知のコンテンツフォーマッターのTDDテスト。
APNs / FCM の両プラットフォーム向けペイロードを生成する。

実行:
    cd ~/Takamagahara/utsushiyo/kozuchi/server
    python3 -m pytest test_notification_formatter.py -v
"""

from __future__ import annotations

import pytest

from notification_formatter import (
    WeeklyReport,
    CategorySummary,
    SatoriChange,
    format_notification_body,
    format_apns_payload,
    format_fcm_payload,
    DEEP_LINK_TEMPLATE,
    NOTIFICATION_TITLE,
)


# ── テスト用ヘルパー ──────────────────────────────────────


def _make_sample_report(
    week: str = "2026-W25",
    categories: list[CategorySummary] | None = None,
    satori_direction: str = "up",
    satori_amount: int = 3200,
    advice: str = "今週は食費が多めです。来週は自炊を増やしてみましょう。",
) -> WeeklyReport:
    """テスト用の週次レポートを生成"""
    if categories is None:
        categories = [
            CategorySummary(name="食費", amount=12500),
            CategorySummary(name="外食費", amount=9800),
            CategorySummary(name="娯楽費", amount=7500),
        ]
    return WeeklyReport(
        week=week,
        categories=categories,
        satori_change=SatoriChange(direction=satori_direction, amount=satori_amount),
        advice=advice,
    )


# ── format_notification_body テスト ───────────────────────


class TestFormatNotificationBody:
    """通知本文のフォーマット"""

    def test_body_includes_top3_categories_with_amounts(self):
        """本文に上位3カテゴリが金額付きで含まれること"""
        report = _make_sample_report()
        body = format_notification_body(report)

        assert "食費" in body
        assert "外食費" in body
        assert "娯楽費" in body
        # 金額がカンマ区切りで表示されていること
        assert "12,500" in body or "12500" in body
        assert "9,800" in body or "9800" in body
        assert "7,500" in body or "7500" in body

    def test_body_includes_satori_change_up(self):
        """SATORI上昇（↑）が表示されること"""
        report = _make_sample_report(satori_direction="up", satori_amount=5000)
        body = format_notification_body(report)

        assert "↑" in body or "上昇" in body
        assert "5,000" in body or "5000" in body

    def test_body_includes_satori_change_down(self):
        """SATORI下降（↓）が表示されること"""
        report = _make_sample_report(satori_direction="down", satori_amount=2300)
        body = format_notification_body(report)

        assert "↓" in body or "下降" in body
        assert "2,300" in body or "2300" in body

    def test_body_includes_advice_sentence(self):
        """助言文が本文に含まれること"""
        advice = "節約の神が微笑んでいます。この調子で継続しましょう。"
        report = _make_sample_report(advice=advice)
        body = format_notification_body(report)

        assert advice in body

    def test_body_uses_japanese_section_labels(self):
        """日本語のセクションラベルが使われていること"""
        report = _make_sample_report()
        body = format_notification_body(report)

        # 日本語のセクション見出し
        assert "支出" in body
        assert "SATORI" in body
        assert "助言" in body or "アドバイス" in body

    def test_body_with_fewer_than_3_categories(self):
        """カテゴリが3件未満の場合も正しく動作すること"""
        report = _make_sample_report(
            categories=[
                CategorySummary(name="食費", amount=5000),
                CategorySummary(name="交通費", amount=2000),
            ]
        )
        body = format_notification_body(report)

        assert "食費" in body
        assert "交通費" in body

    def test_body_no_categories(self):
        """カテゴリが空の場合も例外なく動作すること"""
        report = _make_sample_report(categories=[])
        body = format_notification_body(report)

        # 空でもエラーなく文字列が返ること
        assert isinstance(body, str)
        assert len(body) > 0

    def test_body_satori_no_change(self):
        """SATORI変化がゼロの場合"""
        report = _make_sample_report(satori_direction="down", satori_amount=0)
        body = format_notification_body(report)

        assert "0" in body


# ── format_apns_payload テスト ────────────────────────────


class TestFormatApnsPayload:
    """APNs (iOS) ペイロードのフォーマット"""

    def test_apns_payload_has_required_structure(self):
        """APNsペイロードの基本構造が正しいこと"""
        report = _make_sample_report()
        payload = format_apns_payload(report)

        assert "aps" in payload
        assert "alert" in payload["aps"]
        assert "title" in payload["aps"]["alert"]
        assert "body" in payload["aps"]["alert"]

    def test_apns_title_is_japanese(self):
        """タイトルが日本語の規定文言であること"""
        report = _make_sample_report()
        payload = format_apns_payload(report)

        assert payload["aps"]["alert"]["title"] == NOTIFICATION_TITLE

    def test_apns_body_uses_formatted_body(self):
        """本文がフォーマット済みの通知本文であること"""
        report = _make_sample_report()
        payload = format_apns_payload(report)

        expected_body = format_notification_body(report)
        assert payload["aps"]["alert"]["body"] == expected_body

    def test_apns_includes_deep_link(self):
        """ディープリンクがdataに含まれること"""
        report = _make_sample_report(week="2026-W25")
        payload = format_apns_payload(report)

        assert "deepLink" in payload
        assert payload["deepLink"] == "app://weekly-report?week=2026-W25"

    def test_apns_has_sound_and_badge(self):
        """通知音とバッジが設定されていること"""
        report = _make_sample_report()
        payload = format_apns_payload(report)

        assert payload["aps"]["sound"] == "default"
        assert payload["aps"]["badge"] == 1

    def test_apns_different_week_deep_link(self):
        """異なる週でディープリンクが正しく変化すること"""
        report = _make_sample_report(week="2026-W30")
        payload = format_apns_payload(report)

        assert payload["deepLink"] == "app://weekly-report?week=2026-W30"


# ── format_fcm_payload テスト ─────────────────────────────


class TestFormatFcmPayload:
    """FCM (Android) ペイロードのフォーマット"""

    def test_fcm_payload_has_required_structure(self):
        """FCMペイロードの基本構造が正しいこと"""
        report = _make_sample_report()
        payload = format_fcm_payload(report)

        assert "notification" in payload
        assert "title" in payload["notification"]
        assert "body" in payload["notification"]
        assert "data" in payload

    def test_fcm_title_is_japanese(self):
        """タイトルが日本語の規定文言であること"""
        report = _make_sample_report()
        payload = format_fcm_payload(report)

        assert payload["notification"]["title"] == NOTIFICATION_TITLE

    def test_fcm_body_uses_formatted_body(self):
        """本文がフォーマット済みの通知本文であること"""
        report = _make_sample_report()
        payload = format_fcm_payload(report)

        expected_body = format_notification_body(report)
        assert payload["notification"]["body"] == expected_body

    def test_fcm_includes_deep_link(self):
        """ディープリンクがdataに含まれること"""
        report = _make_sample_report(week="2026-W25")
        payload = format_fcm_payload(report)

        assert payload["data"]["deepLink"] == "app://weekly-report?week=2026-W25"

    def test_fcm_has_android_priority_high(self):
        """Android優先度がhighに設定されていること"""
        report = _make_sample_report()
        payload = format_fcm_payload(report)

        assert "android" in payload
        assert payload["android"]["priority"] == "high"

    def test_fcm_different_week_deep_link(self):
        """異なる週でディープリンクが正しく変化すること"""
        report = _make_sample_report(week="2026-W40")
        payload = format_fcm_payload(report)

        assert payload["data"]["deepLink"] == "app://weekly-report?week=2026-W40"


# ── 定数テスト ─────────────────────────────────────────────


class TestConstants:
    """定数値の検証"""

    def test_notification_title(self):
        """通知タイトルが規定の日本語であること"""
        assert NOTIFICATION_TITLE == "今週の支出まとめ＋アドバイザー諫評"

    def test_deep_link_template(self):
        """ディープリンクテンプレートが正しいこと"""
        assert DEEP_LINK_TEMPLATE == "app://weekly-report?week={week}"


# ── 日本語ローカライゼーションテスト ───────────────────────


class TestJapaneseLocalization:
    """日本語表現の検証"""

    def test_amount_formatting_with_comma(self):
        """金額が日本式（カンマ区切り）で表示されること"""
        report = _make_sample_report(
            categories=[CategorySummary(name="食費", amount=12500)]
        )
        body = format_notification_body(report)

        # カンマ区切りであること
        assert "12,500" in body

    def test_amount_formatting_large_number(self):
        """大きな金額も正しくカンマ区切りされること"""
        report = _make_sample_report(
            categories=[CategorySummary(name="家賃", amount=85000)]
        )
        body = format_notification_body(report)

        assert "85,000" in body

    def test_unicode_safety(self):
        """日本語文字（全角・記号）が正しくエンコードされること"""
        report = _make_sample_report(
            advice="【重要】来週は「節約」を意識してください！"
        )
        body = format_notification_body(report)

        assert "【重要】" in body
        assert "「節約」" in body
        assert "！" in body

    def test_emoji_safety(self):
        """簡易的な絵文字・記号を含む場合も安全に処理されること"""
        report = _make_sample_report(
            advice="🎉 今週は素晴らしい節約でした！"
        )
        body = format_notification_body(report)

        assert "🎉" in body


# ── エッジケーステスト ────────────────────────────────────


class TestEdgeCases:
    """エッジケースの検証"""

    def test_empty_advice(self):
        """助言が空文字列の場合も動作すること"""
        report = _make_sample_report(advice="")
        body = format_notification_body(report)
        payload_apns = format_apns_payload(report)
        payload_fcm = format_fcm_payload(report)

        assert isinstance(body, str)
        assert isinstance(payload_apns, dict)
        assert isinstance(payload_fcm, dict)

    def test_very_long_advice(self):
        """長い助言文も切り詰めずに含まれること（プッシュ通知の制限は呼び出し側の責任）"""
        long_advice = "これはとても長い助言です。" * 20
        report = _make_sample_report(advice=long_advice)
        body = format_notification_body(report)

        assert long_advice in body

    def test_special_week_format(self):
        """ISO週形式が正しくハンドルされること（W53など）"""
        report = _make_sample_report(week="2026-W53")
        payload_apns = format_apns_payload(report)
        payload_fcm = format_fcm_payload(report)

        assert "2026-W53" in payload_apns["deepLink"]
        assert "2026-W53" in payload_fcm["data"]["deepLink"]

    def test_amount_zero(self):
        """金額がゼロのカテゴリも表示されること"""
        report = _make_sample_report(
            categories=[CategorySummary(name="趣味費", amount=0)]
        )
        body = format_notification_body(report)

        assert "趣味費" in body
        assert "0" in body

    def test_roundtrip_payloads_are_json_serializable(self):
        """生成されたペイロードがJSONシリアライズ可能であること"""
        import json

        report = _make_sample_report()
        apns = format_apns_payload(report)
        fcm = format_fcm_payload(report)

        # JSONシリアライズできること
        json.dumps(apns, ensure_ascii=False)
        json.dumps(fcm, ensure_ascii=False)

    def test_all_categories_displayed_correctly(self):
        """カテゴリが金額降順に並んでいること（上位3件）"""
        report = _make_sample_report(
            categories=[
                CategorySummary(name="食費", amount=12500),
                CategorySummary(name="外食費", amount=9800),
                CategorySummary(name="娯楽費", amount=7500),
            ]
        )
        body = format_notification_body(report)

        # 金額の大きい順に出現することを検証
        pos_food = body.index("食費")
        pos_dining = body.index("外食費")
        pos_leisure = body.index("娯楽費")

        assert pos_food < pos_dining < pos_leisure, (
            f"Expected 食費 < 外食費 < 娯楽費 in body, "
            f"got positions {pos_food}, {pos_dining}, {pos_leisure}"
        )
