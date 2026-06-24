#!/usr/bin/env python3
"""
kozuchi 週次通知ディスパッチャー (Weekly Notification Dispatcher)

毎週日曜 20:00 JST に実行される。
全アクティブユーザーの週次レポートを生成し、プッシュ通知を送信する。

機能:
  - アクティブユーザー一覧の取得（transactions テーブルから）
  - 週次レポート生成（weekly_report モジュール）
  - 通知フォーマット（notification_formatter モジュール）
  - 重複送信防止（notification_log テーブル）
  - エラーハンドリング（1ユーザー失敗で全体停止しない）
  - 結果ログ出力

Usage:
    python3 weekly_notification.py [--week YYYY-WWW] [--dry-run] [--user USER_ID]

Options:
    --week     対象のISO週（デフォルト: 現在の週）
    --dry-run  送信せずにプレビューのみ表示
    --user     特定ユーザーのみ処理（デフォルト: 全ユーザー）

Exit codes:
    0 - 全ユーザー成功
    1 - 一部ユーザー失敗
    2 - 全ユーザー失敗
"""

from __future__ import annotations

import argparse
import sqlite3
import sys
import traceback
from datetime import datetime
from pathlib import Path
from typing import Optional

# 親ディレクトリをパスに追加（server/ 内の他モジュールを import 可能に）
_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

from weekly_report import generate_weekly_report, get_current_week_str
from notification_formatter import (
    WeeklyReport,
    CategorySummary,
    SatoriChange,
    format_notification_body,
    format_apns_payload,
    format_fcm_payload,
)
from notification_log import (
    ensure_notification_log_table,
    is_notification_sent,
    record_notification_sent,
    record_notification_failed,
)

DB_PATH = Path.home() / "Takamagahara" / "utsushiyo" / "kozuchi" / "server" / "kozuchi.db"


# ── dict → dataclass アダプター ────────────────────────────

def report_dict_to_weekly_report(report: dict) -> WeeklyReport:
    """
    generate_weekly_report() の戻り値（dict）を
    notification_formatter の WeeklyReport dataclass に変換する。
    """
    categories = [
        CategorySummary(
            name=cat["category"],
            amount=cat["amount"],
        )
        for cat in report.get("top_categories", [])[:3]
    ]

    satori = report.get("satori", {})
    summary = report.get("summary", {})

    # SATORI変化額: 貯蓄額の絶対変化を概算
    # delta は貯蓄率の変化（例: +0.05 = 5%改善）
    # 収入ベースで金額換算（収入ゼロの場合は delta=0 に収束するためゼロで良い）
    income = summary.get("total_income", 0)
    if income > 0:
        satori_amount = int(abs(satori.get("delta", 0)) * income)
    else:
        satori_amount = 0

    # direction: "increase"/"decrease" → "up"/"down"
    direction = satori.get("direction", "stable")
    if direction == "increase":
        dir_str = "up"
    elif direction == "decrease":
        dir_str = "down"
    else:
        dir_str = "up"  # stable は見た目上 up 扱い（矢印は出ない）

    satori_change = SatoriChange(
        direction=dir_str,
        amount=satori_amount,
    )

    return WeeklyReport(
        week=report["week"],
        categories=categories,
        satori_change=satori_change,
        advice=report.get("advice", ""),
    )


# ── ユーザー取得 ──────────────────────────────────────────

def get_active_users(conn: sqlite3.Connection, specific_user: Optional[str] = None) -> list[str]:
    """アクティブユーザーIDの一覧を取得する。"""
    if specific_user:
        return [specific_user]

    rows = conn.execute(
        "SELECT DISTINCT user_id FROM transactions ORDER BY user_id"
    ).fetchall()
    return [r[0] for r in rows]


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
    現時点ではログ出力のみ。
    """
    if dry_run:
        return True, None

    # TODO: 実際のプッシュ送信実装
    # - APNs: apns_client.send(device_token, apns_payload)
    # - FCM:  fcm_client.send(topic, fcm_payload)
    # 現状は成功として扱う
    return True, None


# ── メイン処理 ────────────────────────────────────────────

def dispatch_weekly_notifications(
    week_str: Optional[str] = None,
    specific_user: Optional[str] = None,
    dry_run: bool = False,
) -> dict:
    """
    全アクティブユーザーに週次通知を送信する。

    Returns:
        {
            "week": str,
            "total_users": int,
            "sent": int,
            "skipped": int,    # 既に送信済み
            "failed": int,
            "details": [{user_id, status, error?}, ...],
            "dry_run": bool,
        }
    """
    if week_str is None:
        week_str = get_current_week_str()

    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row  # weekly_report の内部関数が Row 前提
    ensure_notification_log_table(conn)

    users = get_active_users(conn, specific_user)
    result = {
        "week": week_str,
        "total_users": len(users),
        "sent": 0,
        "skipped": 0,
        "failed": 0,
        "details": [],
        "dry_run": dry_run,
        "dispatched_at": datetime.now().isoformat(),
    }

    print(f"=== 週次通知ディスパッチ開始 ===")
    print(f"週: {week_str}")
    print(f"対象ユーザー数: {len(users)}")
    print(f"ドライラン: {dry_run}")
    print()

    for user_id in users:
        detail = {"user_id": user_id, "status": "unknown"}
        try:
            # 重複チェック
            if not dry_run and is_notification_sent(conn, user_id, week_str):
                detail["status"] = "skipped"
                result["skipped"] += 1
                result["details"].append(detail)
                print(f"  [{user_id}] SKIP: 既に送信済み")
                continue

            # レポート生成（キャッシュ使用）
            report = generate_weekly_report(
                user_id=user_id,
                week_str=week_str,
                conn=conn,
                use_cache=True,
            )

            # データ変換
            wr = report_dict_to_weekly_report(report)

            # フォーマット
            apns_payload = format_apns_payload(wr)
            fcm_payload = format_fcm_payload(wr)

            # プレビュー出力（常に表示）
            body_preview = format_notification_body(wr)
            print(f"  [{user_id}]")
            print(f"    タイトル: 今週の支出まとめ＋アドバイザー諫評")
            print(f"    本文:")
            for line in body_preview.split("\n"):
                print(f"      {line}")

            # 送信
            success, error_msg = send_push_notification(
                user_id, apns_payload, fcm_payload, dry_run=dry_run,
            )

            if success:
                if not dry_run:
                    record_notification_sent(conn, user_id, week_str)
                detail["status"] = "sent"
                result["sent"] += 1
                print(f"    結果: {'DRY-RUN' if dry_run else 'SENT'}")
            else:
                if not dry_run:
                    record_notification_failed(conn, user_id, week_str, error_msg or "unknown error")
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
            if not dry_run:
                try:
                    record_notification_failed(conn, user_id, week_str, str(e))
                except Exception:
                    pass
            print(f"  [{user_id}] ERROR: {type(e).__name__}: {e}")
            traceback.print_exc()
            # 1ユーザーの失敗で全体を止めない
            continue

    conn.close()

    # サマリー出力
    print()
    print(f"=== ディスパッチ完了 ===")
    print(f"  総ユーザー数: {result['total_users']}")
    print(f"  送信成功: {result['sent']}")
    print(f"  スキップ(送信済): {result['skipped']}")
    print(f"  失敗: {result['failed']}")

    return result


# ── CLI エントリポイント ───────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="kozuchi 週次通知ディスパッチャー",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 weekly_notification.py --dry-run          # プレビュー表示
  python3 weekly_notification.py --week 2026-W25    # 特定週を指定
  python3 weekly_notification.py --user user_001    # 特定ユーザーのみ
  python3 weekly_notification.py --dry-run --user user_001
        """,
    )
    parser.add_argument("--week", help="ISO週文字列 (例: 2026-W25)")
    parser.add_argument("--dry-run", action="store_true", help="送信せずにプレビュー表示")
    parser.add_argument("--user", help="特定ユーザーID（デフォルト: 全ユーザー）")
    args = parser.parse_args()

    result = dispatch_weekly_notifications(
        week_str=args.week,
        specific_user=args.user,
        dry_run=args.dry_run,
    )

    # 終了コード判定
    if result["failed"] == result["total_users"] and result["total_users"] > 0:
        return 2  # 全ユーザー失敗
    elif result["failed"] > 0:
        return 1  # 一部ユーザー失敗
    return 0


if __name__ == "__main__":
    sys.exit(main())
