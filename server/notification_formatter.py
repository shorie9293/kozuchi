#!/usr/bin/env python3
"""
kozuchi プッシュ通知フォーマッター (Push Notification Formatter)

週次レポートを受け取り、APNs (iOS) / FCM (Android) 向けの
プッシュ通知ペイロードを生成する。

Usage:
    from notification_formatter import (
        WeeklyReport,
        CategorySummary,
        SatoriChange,
        format_apns_payload,
        format_fcm_payload,
    )

    report = WeeklyReport(
        week="2026-W25",
        categories=[CategorySummary(name="食費", amount=12500), ...],
        satori_change=SatoriChange(direction="up", amount=3200),
        advice="今週は食費が多めです。来週は自炊を増やしてみましょう。",
    )

    apns_payload = format_apns_payload(report)
    fcm_payload = format_fcm_payload(report)
"""

from __future__ import annotations

from dataclasses import dataclass


# ── 定数 ──────────────────────────────────────────────────

NOTIFICATION_TITLE = "今週の支出まとめ＋アドバイザー諫評"
DEEP_LINK_TEMPLATE = "app://weekly-report?week={week}"


# ── データ型 ──────────────────────────────────────────────


@dataclass
class CategorySummary:
    """1カテゴリの集計サマリ"""
    name: str     # カテゴリ名（日本語）
    amount: int   # 支出金額（正の整数）


@dataclass
class SatoriChange:
    """SATORIの変化量"""
    direction: str  # "up" or "down"
    amount: int     # 変化額（正の整数）


@dataclass
class WeeklyReport:
    """1週間の集計レポート"""
    week: str                         # ISO週形式 "YYYY-Www"
    categories: list[CategorySummary] # 支出上位カテゴリ（金額降順）
    satori_change: SatoriChange       # SATORI変化
    advice: str                       # アドバイザーからの助言文


# ── フォーマット関数 ──────────────────────────────────────


def _format_amount(amount: int) -> str:
    """金額を日本式（カンマ区切り）でフォーマット"""
    return f"{amount:,}"


def _satori_arrow(direction: str) -> str:
    """SATORI変化の方向を矢印記号に変換"""
    if direction == "up":
        return "↑"
    elif direction == "down":
        return "↓"
    return direction


def format_notification_body(report: WeeklyReport) -> str:
    """
    通知本文を生成する。

    日本語のセクション分けで、支出TOP3・SATORI変化・助言を含む。
    """
    lines: list[str] = []

    # ── 支出TOP3 ──
    lines.append("【支出TOP3】")
    for i, cat in enumerate(report.categories[:3], 1):
        lines.append(f"{i}. {cat.name} ¥{_format_amount(cat.amount)}")

    # ── SATORI変化 ──
    lines.append("")
    arrow = _satori_arrow(report.satori_change.direction)
    lines.append(f"【SATORI】{arrow} ¥{_format_amount(report.satori_change.amount)}")

    # ── 今週の助言 ──
    lines.append("")
    lines.append("【今週の助言】")
    lines.append(report.advice)

    return "\n".join(lines)


def _build_deep_link(week: str) -> str:
    """週パラメータからディープリンクURLを生成"""
    return DEEP_LINK_TEMPLATE.format(week=week)


def format_apns_payload(report: WeeklyReport) -> dict:
    """
    APNs (Apple Push Notification service) 向けペイロードを生成。

    iOS端末へのプッシュ通知用。
    """
    return {
        "aps": {
            "alert": {
                "title": NOTIFICATION_TITLE,
                "body": format_notification_body(report),
            },
            "sound": "default",
            "badge": 1,
        },
        "deepLink": _build_deep_link(report.week),
    }


def format_fcm_payload(report: WeeklyReport) -> dict:
    """
    FCM (Firebase Cloud Messaging) 向けペイロードを生成。

    Android端末へのプッシュ通知用。
    """
    return {
        "notification": {
            "title": NOTIFICATION_TITLE,
            "body": format_notification_body(report),
        },
        "data": {
            "deepLink": _build_deep_link(report.week),
        },
        "android": {
            "priority": "high",
        },
    }
