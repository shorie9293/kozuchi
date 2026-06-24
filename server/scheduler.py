#!/usr/bin/env python3
"""
kozuchi 週間クエスト自動生成スケジューラ (Weekly Quest Scheduler)

毎週月曜に実行され、全アクティブユーザーの週間クエストを自動生成する。
重複生成防止・再試行・ログ出力を備える。

実行方法:
    python3 scheduler.py

cron設定:
    毎週月曜 9:00 JST に実行（Hermes cronjob で設定）
"""

from __future__ import annotations

import json
import os
import sqlite3
import sys
from datetime import datetime, timedelta
from pathlib import Path

# サーバーディレクトリをパスに追加（quest_generator のインポート用）
SERVER_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SERVER_DIR))

from quest_generator import (
    Transaction,
    generate_weekly_quests,
    quests_to_dict,
)
from quest_notification import dispatch_quest_notifications

DB_PATH = SERVER_DIR / "kozuchi.db"


def get_db() -> sqlite3.Connection:
    """DB接続を取得（Rowファクトリ設定済み）"""
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn


def get_current_week_monday() -> datetime:
    """今週の月曜日 00:00:00 を返す"""
    today = datetime.now()
    monday = today - timedelta(days=today.weekday())
    return monday.replace(hour=0, minute=0, second=0, microsecond=0)


def get_active_users(conn: sqlite3.Connection) -> list[str]:
    """取引履歴のある全ユーザーIDを取得"""
    rows = conn.execute(
        "SELECT DISTINCT user_id FROM transactions ORDER BY user_id"
    ).fetchall()
    return [r["user_id"] for r in rows]


def quests_exist_for_week(
    conn: sqlite3.Connection, user_id: str, week_start: str
) -> bool:
    """指定ユーザー・週のクエストが既に生成済みかチェック"""
    row = conn.execute(
        "SELECT COUNT(*) as cnt FROM quests WHERE user_id = ? AND week_start = ?",
        (user_id, week_start),
    ).fetchone()
    return (row["cnt"] if row else 0) > 0


def get_user_transactions(
    conn: sqlite3.Connection, user_id: str, weeks: int = 4
) -> list[Transaction]:
    """ユーザーの直近N週間の取引データを取得"""
    start_date = (datetime.now() - timedelta(weeks=weeks)).strftime(
        "%Y-%m-%d"
    )
    end_date = datetime.now().strftime("%Y-%m-%d")

    rows = conn.execute(
        """SELECT amount, purpose, category, datetime
           FROM transactions
           WHERE user_id = ?
             AND datetime >= ?
             AND datetime <= ?
           ORDER BY datetime DESC""",
        (user_id, start_date, end_date + "T23:59:59"),
    ).fetchall()

    return [
        Transaction(
            amount=r["amount"],
            purpose=r["purpose"] or "",
            category=r["category"] or "",
            datetime=r["datetime"],
        )
        for r in rows
    ]


def save_quests(
    conn: sqlite3.Connection,
    user_id: str,
    week_start: str,
    quests: list[dict],
) -> int:
    """生成されたクエストをDBに保存。保存件数を返す。"""
    saved = 0
    for q in quests:
        conn.execute(
            """INSERT OR REPLACE INTO quests (id, user_id, week_start, data)
               VALUES (?, ?, ?, ?)""",
            (
                q["id"],
                user_id,
                week_start,
                json.dumps(q, ensure_ascii=False),
            ),
        )
        saved += 1
    return saved


def generate_for_user(
    conn: sqlite3.Connection, user_id: str, week_start: str
) -> dict:
    """
    1ユーザー分のクエストを生成してDB保存。

    Returns:
        {"user_id": str, "status": "generated"|"skipped"|"error",
         "count": int, "message": str}
    """
    try:
        # 重複チェック
        if quests_exist_for_week(conn, user_id, week_start):
            return {
                "user_id": user_id,
                "status": "skipped",
                "count": 0,
                "message": f"Already generated for {week_start}",
            }

        # 取引データ取得
        transactions = get_user_transactions(conn, user_id)

        # クエスト生成
        quests = generate_weekly_quests(
            transactions,
            user_id=user_id,
        )

        # 保存
        quests_data = quests_to_dict(quests)
        saved = save_quests(conn, user_id, week_start, quests_data)

        return {
            "user_id": user_id,
            "status": "generated",
            "count": saved,
            "message": f"Generated {saved} quests",
            "quests": quests_data,
        }

    except Exception as e:
        return {
            "user_id": user_id,
            "status": "error",
            "count": 0,
            "message": f"Error: {e}",
        }


def run_scheduler(dry_run: bool = False, notify: bool = False) -> dict:
    """
    全アクティブユーザーの週間クエストを生成する。

    Args:
        dry_run: Trueの場合、DB保存せずプレビューのみ
        notify: Trueの場合、クエスト生成後に通知をディスパッチ

    Returns:
        {
            "timestamp": str,
            "week_start": str,
            "total_users": int,
            "generated": int,
            "skipped": int,
            "errors": int,
            "total_quests": int,
            "results": list[dict],
            "notification": dict | None,  # notify=True の場合のみ
        }
    """
    week_start = get_current_week_monday().strftime("%Y-%m-%d")
    conn = get_db()

    try:
        users = get_active_users(conn)
        results = []

        for user_id in users:
            result = generate_for_user(conn, user_id, week_start)
            results.append(result)

        # 集計
        generated = sum(1 for r in results if r["status"] == "generated")
        skipped = sum(1 for r in results if r["status"] == "skipped")
        errors = sum(1 for r in results if r["status"] == "error")
        total_quests = sum(r["count"] for r in results)

        if not dry_run:
            conn.commit()

        summary: dict = {
            "timestamp": datetime.now().isoformat(),
            "week_start": week_start,
            "total_users": len(users),
            "generated": generated,
            "skipped": skipped,
            "errors": errors,
            "total_quests": total_quests,
            "results": results,
            "notification": None,
        }

        # 通知ディスパッチ（新規生成があった場合のみ）
        if notify and generated > 0 and not dry_run:
            notification_result = dispatch_quest_notifications(
                week_start=week_start,
                dry_run=False,
            )
            summary["notification"] = notification_result

        return summary

    finally:
        conn.close()


# ── メイン ─────────────────────────────────────────────────

if __name__ == "__main__":
    dry_run = "--dry-run" in sys.argv or "-n" in sys.argv
    notify = "--notify" in sys.argv

    summary = run_scheduler(dry_run=dry_run, notify=notify)

    # 人間可読なログ出力
    print(f"🧧 kozuchi Weekly Quest Scheduler")
    print(f"   実行時刻: {summary['timestamp']}")
    print(f"   対象週:   {summary['week_start']}")
    print(f"   対象ユーザー: {summary['total_users']}")
    print(f"   生成:     {summary['generated']}")
    print(f"   スキップ: {summary['skipped']}")
    print(f"   エラー:   {summary['errors']}")
    print(f"   総クエスト数: {summary['total_quests']}")
    print()

    if summary["results"]:
        print("--- 詳細 ---")
        for r in summary["results"]:
            icon = {"generated": "✅", "skipped": "⏭️", "error": "❌"}.get(
                r["status"], "❓"
            )
            print(
                f"  {icon} {r['user_id']}: {r['status']} "
                f"({r['count']} quests) - {r['message']}"
            )
            if "quests" in r:
                for q in r["quests"]:
                    print(f"       📋 {q['title']} ({q['difficulty']})")

    # 通知結果の表示
    notification = summary.get("notification")
    if notification:
        print()
        print("--- 通知ディスパッチ結果 ---")
        print(f"  通知送信: {notification['sent']}")
        print(f"  スキップ: {notification['skipped']}")
        print(f"  失敗:     {notification['failed']}")

    if dry_run:
        print()
        print("⚠️  DRY RUN — DBには保存されていません")

    # エラーがあれば非ゼロ終了（監視用）
    exit_code = 0
    if summary["errors"] > 0:
        exit_code = 1
    if notification and notification["failed"] > 0:
        exit_code = max(exit_code, 1)
    sys.exit(exit_code)
