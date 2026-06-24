#!/usr/bin/env python3
"""
kozuchi クエスト通知ディスパッチャー (Quest Notification Dispatcher)

毎週月曜のクエスト生成後に実行され、ユーザーに新着クエストを通知する。
火曜・水曜のリマインド機能も提供する。

機能:
  - クエスト生成通知（月曜）
  - 未選択クエストのリマインド（火曜・水曜）
  - 通知ログによる重複防止
  - クエスト概要を含む通知文生成
  - APNs/FCM ペイロード生成（スタブ）

Usage:
    from quest_notification import (
        dispatch_quest_notifications,
        dispatch_quest_reminders,
        format_quest_notification_body,
        get_pending_quest_notifications,
    )

    # 月曜: クエスト生成通知
    result = dispatch_quest_notifications(week_start="2026-06-29")

    # 火曜/水曜: リマインド
    result = dispatch_quest_reminders(week_start="2026-06-29")
"""

from __future__ import annotations

import json
import sqlite3
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

# 親ディレクトリをパスに追加
_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

DB_PATH = Path.home() / "Takamagahara" / "utsushiyo" / "kozuchi" / "server" / "kozuchi.db"

# 通知タイプ定数
NOTIFY_TYPE_QUEST_READY = "quest_ready"      # 月曜: クエスト用意完了
NOTIFY_TYPE_QUEST_REMINDER = "quest_reminder" # 火曜/水曜: 未選択リマインド

# ディープリンクテンプレート
QUEST_DEEP_LINK = "app://weekly-quest?week={week}"


# ── DB 操作 ──────────────────────────────────────────────

def ensure_quest_notification_table(conn: sqlite3.Connection) -> None:
    """クエスト通知ログテーブルを作成（なければ）"""
    conn.execute("""
        CREATE TABLE IF NOT EXISTS quest_notification_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            week_start TEXT NOT NULL,
            notify_type TEXT NOT NULL DEFAULT 'quest_ready',
            status TEXT NOT NULL DEFAULT 'pending',
            error TEXT,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            UNIQUE(user_id, week_start, notify_type)
        )
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_quest_notif_user_week
        ON quest_notification_log(user_id, week_start)
    """)
    conn.commit()


def is_quest_notification_sent(
    conn: sqlite3.Connection,
    user_id: str,
    week_start: str,
    notify_type: str = NOTIFY_TYPE_QUEST_READY,
) -> bool:
    """指定ユーザー・週のクエスト通知が既に送信済みか"""
    ensure_quest_notification_table(conn)
    row = conn.execute(
        "SELECT 1 FROM quest_notification_log "
        "WHERE user_id = ? AND week_start = ? AND notify_type = ? AND status = 'sent'",
        (user_id, week_start, notify_type),
    ).fetchone()
    return row is not None


def record_quest_notification(
    conn: sqlite3.Connection,
    user_id: str,
    week_start: str,
    notify_type: str = NOTIFY_TYPE_QUEST_READY,
    status: str = "sent",
    error: Optional[str] = None,
) -> None:
    """クエスト通知の送信結果を記録"""
    ensure_quest_notification_table(conn)
    conn.execute(
        """INSERT OR REPLACE INTO quest_notification_log
           (user_id, week_start, notify_type, status, error, created_at)
           VALUES (?, ?, ?, ?, ?, datetime('now'))""",
        (user_id, week_start, notify_type, status, error),
    )
    conn.commit()


# ── クエスト取得 ──────────────────────────────────────────

def get_quests_for_user(
    conn: sqlite3.Connection, user_id: str, week_start: str
) -> list[dict]:
    """指定ユーザー・週のクエスト一覧を取得"""
    rows = conn.execute(
        "SELECT data FROM quests WHERE user_id = ? AND week_start = ?",
        (user_id, week_start),
    ).fetchall()
    quests = []
    for row in rows:
        try:
            q = json.loads(row[0])
            quests.append(q)
        except (json.JSONDecodeError, TypeError):
            continue
    return quests


def get_users_with_quests(
    conn: sqlite3.Connection, week_start: str
) -> list[str]:
    """指定週にクエストが生成されているユーザー一覧"""
    rows = conn.execute(
        "SELECT DISTINCT user_id FROM quests WHERE week_start = ? ORDER BY user_id",
        (week_start,),
    ).fetchall()
    return [r[0] for r in rows]


def get_users_without_selection(
    conn: sqlite3.Connection, week_start: str
) -> list[str]:
    """
    指定週にクエストが生成されているが、まだ選択していないユーザー一覧。
    
    選択状態は quests テーブルの data JSON 内に selected フラグで管理される想定。
    実際のアプリ実装では別テーブルまたはSupabaseで管理されるため、
    ここではクエストが存在する全ユーザーを対象とする。
    """
    return get_users_with_quests(conn, week_start)


# ── 通知文生成 ────────────────────────────────────────────

def format_quest_notification_body(quests: list[dict]) -> str:
    """クエスト通知本文を生成（日本語）"""
    if not quests:
        return "今週のクエストが用意されました。アプリを開いて確認してください。"

    lines = ["【今週のクエストが用意されました】", ""]
    
    for i, q in enumerate(quests[:5], 1):  # 最大5件
        title = q.get("title", "クエスト")
        diff = q.get("difficulty_label", q.get("difficulty", ""))
        cat = q.get("category", "")
        target = q.get("target_amount", 0)
        flavor = q.get("flavor_text", "")
        
        line = f"{i}. {title}"
        if diff:
            line += f" [{diff}]"
        if target > 0:
            line += f" - ¥{target:,}"
        lines.append(line)
        
        if flavor and i <= 3:  # 上位3件のみ味付け表示
            lines.append(f"   {flavor}")
    
    lines.append("")
    lines.append("タップしてクエストを選択してください。")
    
    return "\n".join(lines)


def format_quest_reminder_body(quest_count: int) -> str:
    """リマインド通知本文を生成"""
    templates = [
        f"まだ今週のクエストが選ばれていません！{quest_count}件のクエストが待っています。",
        f"守護神からの挑戦状が届いています。{quest_count}件のクエストを確認しましょう。",
        f"週も半ばです。今週のクエスト（{quest_count}件）を選んで挑戦を始めませんか？",
    ]
    import random
    return random.choice(templates)


def format_quest_apns_payload(quests: list[dict], week_start: str, is_reminder: bool = False) -> dict:
    """APNsペイロード生成"""
    title = "今週のクエストが用意されました" if not is_reminder else "クエスト選択のお知らせ"
    body = format_quest_notification_body(quests) if not is_reminder else format_quest_reminder_body(len(quests))
    
    return {
        "aps": {
            "alert": {
                "title": title,
                "body": body,
            },
            "sound": "default",
            "badge": 1,
        },
        "deepLink": QUEST_DEEP_LINK.format(week=week_start),
        "notificationType": "quest_reminder" if is_reminder else "quest_ready",
    }


def format_quest_fcm_payload(quests: list[dict], week_start: str, is_reminder: bool = False) -> dict:
    """FCMペイロード生成"""
    title = "今週のクエストが用意されました" if not is_reminder else "クエスト選択のお知らせ"
    body = format_quest_notification_body(quests) if not is_reminder else format_quest_reminder_body(len(quests))
    
    return {
        "notification": {
            "title": title,
            "body": body,
        },
        "data": {
            "deepLink": QUEST_DEEP_LINK.format(week=week_start),
            "notificationType": "quest_reminder" if is_reminder else "quest_ready",
        },
        "android": {
            "priority": "high",
        },
    }


# ── 通知送信（スタブ）─────────────────────────────────────

def send_push_notification(
    user_id: str,
    apns_payload: dict,
    fcm_payload: dict,
    dry_run: bool = False,
) -> tuple[bool, Optional[str]]:
    """
    プッシュ通知を送信するスタブ。
    
    実際のプロダクション実装では、APNs / FCM の API を呼び出す。
    現時点では成功として扱う（通知ログへの記録が主目的）。
    """
    if dry_run:
        return True, None
    
    # TODO: 実際のプッシュ送信実装
    # - device_token の取得は Flutter アプリ側で管理
    # - 本番では Supabase 等から device_token を取得して送信
    return True, None


# ── メイン処理 ────────────────────────────────────────────

def dispatch_quest_notifications(
    week_start: str,
    specific_user: Optional[str] = None,
    dry_run: bool = False,
) -> dict:
    """
    全ユーザーにクエスト生成通知を送信する（月曜用）。
    
    Args:
        week_start: 対象週の月曜日 (YYYY-MM-DD)
        specific_user: 特定ユーザーのみ（None=全ユーザー）
        dry_run: Trueの場合、送信せずプレビューのみ
    
    Returns:
        {week_start, total_users, sent, skipped, failed, details, dry_run}
    """
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    ensure_quest_notification_table(conn)
    
    users = get_users_with_quests(conn, week_start)
    if specific_user:
        users = [specific_user] if specific_user in users else []
    
    result = {
        "week_start": week_start,
        "total_users": len(users),
        "sent": 0,
        "skipped": 0,
        "failed": 0,
        "details": [],
        "dry_run": dry_run,
        "dispatched_at": datetime.now().isoformat(),
    }
    
    print(f"=== クエスト通知ディスパッチ開始 ===")
    print(f"週: {week_start}")
    print(f"対象ユーザー数: {len(users)}")
    print(f"ドライラン: {dry_run}")
    print()
    
    for user_id in users:
        detail = {"user_id": user_id, "status": "unknown"}
        try:
            # 重複チェック
            if not dry_run and is_quest_notification_sent(
                conn, user_id, week_start, NOTIFY_TYPE_QUEST_READY
            ):
                detail["status"] = "skipped"
                result["skipped"] += 1
                result["details"].append(detail)
                print(f"  [{user_id}] SKIP: 既に通知済み")
                continue
            
            # クエスト取得
            quests = get_quests_for_user(conn, user_id, week_start)
            
            if not quests:
                detail["status"] = "skipped"
                detail["reason"] = "no_quests"
                result["skipped"] += 1
                result["details"].append(detail)
                print(f"  [{user_id}] SKIP: クエストなし")
                continue
            
            # 通知文生成
            body = format_quest_notification_body(quests)
            apns = format_quest_apns_payload(quests, week_start, is_reminder=False)
            fcm = format_quest_fcm_payload(quests, week_start, is_reminder=False)
            
            # プレビュー出力
            print(f"  [{user_id}] {len(quests)}件のクエスト")
            for line in body.split("\n")[:5]:
                print(f"    {line}")
            
            # 送信
            success, error_msg = send_push_notification(
                user_id, apns, fcm, dry_run=dry_run,
            )
            
            if success:
                if not dry_run:
                    record_quest_notification(
                        conn, user_id, week_start, NOTIFY_TYPE_QUEST_READY, "sent"
                    )
                detail["status"] = "sent"
                detail["quest_count"] = len(quests)
                result["sent"] += 1
                print(f"    結果: {'DRY-RUN' if dry_run else 'SENT'}")
            else:
                if not dry_run:
                    record_quest_notification(
                        conn, user_id, week_start, NOTIFY_TYPE_QUEST_READY,
                        "failed", error_msg,
                    )
                detail["status"] = "failed"
                detail["error"] = error_msg
                result["failed"] += 1
                print(f"    結果: FAILED - {error_msg}")
            
            result["details"].append(detail)
            
        except Exception as e:
            detail["status"] = "failed"
            detail["error"] = f"{type(e).__name__}: {e}"
            result["failed"] += 1
            result["details"].append(detail)
            print(f"  [{user_id}] ERROR: {type(e).__name__}: {e}")
            continue
    
    conn.close()
    
    # サマリー
    print()
    print(f"=== クエスト通知完了 ===")
    print(f"  総ユーザー数: {result['total_users']}")
    print(f"  送信成功: {result['sent']}")
    print(f"  スキップ: {result['skipped']}")
    print(f"  失敗: {result['failed']}")
    
    return result


def dispatch_quest_reminders(
    week_start: str,
    specific_user: Optional[str] = None,
    dry_run: bool = False,
) -> dict:
    """
    未選択クエストのリマインド通知を送信する（火曜・水曜用）。
    
    クエストが生成されているが未選択のユーザーにリマインドを送る。
    
    Args:
        week_start: 対象週の月曜日 (YYYY-MM-DD)
        specific_user: 特定ユーザーのみ（None=全ユーザー）
        dry_run: Trueの場合、送信せずプレビューのみ
    
    Returns:
        {week_start, total_users, sent, skipped, failed, details, dry_run}
    """
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    ensure_quest_notification_table(conn)
    
    # クエストがあるがリマインド未送信のユーザーを対象
    users_with_quests = get_users_with_quests(conn, week_start)
    if specific_user:
        users_with_quests = [specific_user] if specific_user in users_with_quests else []
    
    # 既にリマインド送信済みのユーザーを除外
    users = []
    for uid in users_with_quests:
        if not is_quest_notification_sent(conn, uid, week_start, NOTIFY_TYPE_QUEST_REMINDER):
            users.append(uid)
    
    result = {
        "week_start": week_start,
        "total_users": len(users),
        "sent": 0,
        "skipped": 0,
        "failed": 0,
        "details": [],
        "dry_run": dry_run,
        "dispatched_at": datetime.now().isoformat(),
    }
    
    print(f"=== クエストリマインドディスパッチ開始 ===")
    print(f"週: {week_start}")
    print(f"対象ユーザー数: {len(users)}")
    print(f"ドライラン: {dry_run}")
    print()
    
    for user_id in users:
        detail = {"user_id": user_id, "status": "unknown"}
        try:
            quests = get_quests_for_user(conn, user_id, week_start)
            
            if not quests:
                detail["status"] = "skipped"
                detail["reason"] = "no_quests"
                result["skipped"] += 1
                result["details"].append(detail)
                continue
            
            body = format_quest_reminder_body(len(quests))
            apns = format_quest_apns_payload(quests, week_start, is_reminder=True)
            fcm = format_quest_fcm_payload(quests, week_start, is_reminder=True)
            
            print(f"  [{user_id}] {len(quests)}件の未選択クエスト")
            print(f"    本文: {body}")
            
            success, error_msg = send_push_notification(
                user_id, apns, fcm, dry_run=dry_run,
            )
            
            if success:
                if not dry_run:
                    record_quest_notification(
                        conn, user_id, week_start, NOTIFY_TYPE_QUEST_REMINDER, "sent"
                    )
                detail["status"] = "sent"
                detail["quest_count"] = len(quests)
                result["sent"] += 1
                print(f"    結果: {'DRY-RUN' if dry_run else 'SENT'}")
            else:
                if not dry_run:
                    record_quest_notification(
                        conn, user_id, week_start, NOTIFY_TYPE_QUEST_REMINDER,
                        "failed", error_msg,
                    )
                detail["status"] = "failed"
                detail["error"] = error_msg
                result["failed"] += 1
                print(f"    結果: FAILED - {error_msg}")
            
            result["details"].append(detail)
            
        except Exception as e:
            detail["status"] = "failed"
            detail["error"] = f"{type(e).__name__}: {e}"
            result["failed"] += 1
            result["details"].append(detail)
            print(f"  [{user_id}] ERROR: {type(e).__name__}: {e}")
            continue
    
    conn.close()
    
    print()
    print(f"=== クエストリマインド完了 ===")
    print(f"  総ユーザー数: {result['total_users']}")
    print(f"  送信成功: {result['sent']}")
    print(f"  スキップ: {result['skipped']}")
    print(f"  失敗: {result['failed']}")
    
    return result


def get_pending_quest_notifications(
    user_id: str,
    week_start: Optional[str] = None,
) -> list[dict]:
    """
    ユーザーの未読クエスト通知一覧を取得する（Flutter API用）。
    
    Returns:
        [{quest_id, title, description, category, target_amount, difficulty, ...}, ...]
    """
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    
    if week_start is None:
        # 最新の週を取得
        row = conn.execute(
            "SELECT week_start FROM quests WHERE user_id = ? ORDER BY week_start DESC LIMIT 1",
            (user_id,),
        ).fetchone()
        if not row:
            conn.close()
            return []
        week_start = row[0]
    
    quests = get_quests_for_user(conn, user_id, week_start)
    conn.close()
    return quests


# ── CLI エントリポイント ───────────────────────────────────

def main() -> int:
    import argparse
    
    parser = argparse.ArgumentParser(
        description="kozuchi クエスト通知ディスパッチャー",
    )
    parser.add_argument("mode", choices=["notify", "remind"],
                        help="notify=月曜クエスト通知, remind=火水リマインド")
    parser.add_argument("--week", help="対象週の月曜日 (YYYY-MM-DD)")
    parser.add_argument("--dry-run", action="store_true", help="送信せずプレビュー表示")
    parser.add_argument("--user", help="特定ユーザーID")
    args = parser.parse_args()
    
    if args.week is None:
        from datetime import datetime, timedelta
        today = datetime.now()
        monday = today - timedelta(days=today.weekday())
        week_start = monday.strftime("%Y-%m-%d")
    else:
        week_start = args.week
    
    if args.mode == "notify":
        result = dispatch_quest_notifications(
            week_start=week_start,
            specific_user=args.user,
            dry_run=args.dry_run,
        )
    else:  # remind
        result = dispatch_quest_reminders(
            week_start=week_start,
            specific_user=args.user,
            dry_run=args.dry_run,
        )
    
    if result["failed"] == result["total_users"] and result["total_users"] > 0:
        return 2
    elif result["failed"] > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
