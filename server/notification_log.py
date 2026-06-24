#!/usr/bin/env python3
"""
kozuchi 通知ログテーブル管理 (Notification Log)

このモジュールは通知送信履歴を追跡する notification_log テーブルを管理する。
重複送信防止とエラー追跡に使用される。

Usage:
    from notification_log import (
        ensure_notification_log_table,
        record_notification_sent,
        record_notification_failed,
        is_notification_sent,
        get_pending_notifications,
    )
"""
from __future__ import annotations

import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Optional

DB_PATH = Path.home() / "Takamagahara" / "utsushiyo" / "kozuchi" / "server" / "kozuchi.db"


def ensure_notification_log_table(conn: sqlite3.Connection) -> None:
    """notification_log テーブルが存在しなければ作成する。"""
    conn.execute("""
        CREATE TABLE IF NOT EXISTS notification_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            week TEXT NOT NULL,
            platform TEXT NOT NULL DEFAULT 'both',
            status TEXT NOT NULL DEFAULT 'sent',
            error TEXT,
            sent_at TEXT NOT NULL DEFAULT (datetime('now')),
            UNIQUE(user_id, week, platform)
        )
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_notification_log_user_week
        ON notification_log(user_id, week)
    """)
    conn.commit()


def is_notification_sent(
    conn: sqlite3.Connection,
    user_id: str,
    week_str: str,
    platform: str = "both",
) -> bool:
    """指定ユーザー・週の通知が既に送信済みか確認する。"""
    ensure_notification_log_table(conn)
    row = conn.execute(
        "SELECT 1 FROM notification_log WHERE user_id = ? AND week = ? AND platform = ? AND status = 'sent'",
        (user_id, week_str, platform),
    ).fetchone()
    return row is not None


def record_notification_sent(
    conn: sqlite3.Connection,
    user_id: str,
    week_str: str,
    platform: str = "both",
) -> None:
    """通知送信成功を記録する。"""
    ensure_notification_log_table(conn)
    conn.execute(
        """
        INSERT OR REPLACE INTO notification_log (user_id, week, platform, status, sent_at)
        VALUES (?, ?, ?, 'sent', datetime('now'))
        """,
        (user_id, week_str, platform),
    )
    conn.commit()


def record_notification_failed(
    conn: sqlite3.Connection,
    user_id: str,
    week_str: str,
    error_msg: str,
    platform: str = "both",
) -> None:
    """通知送信失敗を記録する。"""
    ensure_notification_log_table(conn)
    conn.execute(
        """
        INSERT OR REPLACE INTO notification_log (user_id, week, platform, status, error, sent_at)
        VALUES (?, ?, ?, 'failed', ?, datetime('now'))
        """,
        (user_id, week_str, platform, error_msg),
    )
    conn.commit()


def get_pending_notifications(
    conn: sqlite3.Connection,
    week_str: Optional[str] = None,
) -> list[dict]:
    """指定された週に通知がまだ送られていないユーザー一覧を取得する。"""
    ensure_notification_log_table(conn)
    conn.row_factory = sqlite3.Row
    sent_users = conn.execute(
        "SELECT DISTINCT user_id FROM notification_log WHERE status = 'sent' AND (? IS NULL OR week = ?)",
        (week_str, week_str),
    ).fetchall()
    sent_ids = {r["user_id"] for r in sent_users}
    conn.row_factory = None
    return list(sent_ids)
