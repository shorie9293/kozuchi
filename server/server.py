#!/usr/bin/env python3
"""
kozuchi バックエンドサーバー (Flask)

提供エンドポイント:
  GET  /api/transactions        - 取引データ取得（フィルタ対応）
  GET  /api/transactions/export - 取引データCSVエクスポート
  POST /api/transactions/email  - 取引データCSVをメール送信
  POST /api/quests/generate     - 週間クエスト候補生成
  GET  /api/health          - ヘルスチェック
  GET  /api/health          - ヘルスチェック

起動: python3 server.py
"""

from __future__ import annotations

import io
import json
import os
import random
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

from flask import Flask, Response, jsonify, request

from quest_generator import (
    Transaction,
    generate_weekly_quests,
    quests_to_dict,
)

from csv_export import (
    format_transactions_csv,
    validate_date,
)

from email_service import (
    send_csv_email,
    validate_email,
    check_rate_limit,
    EmailSendError,
)

from drive_upload import (
    DriveUploadError,
    upload_csv_to_drive,
)
from weekly_report import (
    generate_weekly_report,
    get_current_week_str,
)

app = Flask(__name__)

# ── 設定 ──────────────────────────────────────────────────
DB_PATH = Path.home() / "Takamagahara" / "utsushiyo" / "kozuchi" / "server" / "kozuchi.db"
DATA_DIR = Path.home() / "Takamagahara" / "utsushiyo" / "kozuchi" / "server" / "data"
DEFAULT_USER_ID = "user_001"


# ── DB ヘルパー ───────────────────────────────────────────

def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    """初回起動時にDBとテーブルを作成"""
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    conn = get_db()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            amount INTEGER NOT NULL,
            purpose TEXT NOT NULL DEFAULT '',
            category TEXT NOT NULL DEFAULT '',
            datetime TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_tx_user_date
        ON transactions(user_id, datetime)
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS quests (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            week_start TEXT NOT NULL,
            data TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
    """)
    conn.commit()
    conn.close()


# ── シードデータ（開発用）────────────────────────────────

def seed_demo_data(user_id: str = DEFAULT_USER_ID):
    """デモ用取引データを投入"""
    conn = get_db()
    count = conn.execute(
        "SELECT COUNT(*) FROM transactions WHERE user_id = ?", (user_id,)
    ).fetchone()[0]
    if count > 0:
        conn.close()
        return  # 既にデータあり

    today = datetime.now()
    transactions = []

    categories = {
        "食費":     [800, 1200, 600, 2000, 1500, 900, 3000],
        "外食費":   [3500, 0, 5000, 2000, 0, 4500, 2500],
        "娯楽費":   [0, 6000, 3000, 0, 8000, 2000, 0],
        "書籍費":   [1200, 0, 0, 4000, 0, 0, 2500],
        "交際費":   [0, 0, 8000, 0, 5000, 0, 3000],
        "交通費":   [1000, 1500, 800, 2000, 1200, 900, 1800],
        "日用品費": [500, 300, 1200, 0, 800, 600, 400],
        "趣味費":   [0, 4000, 0, 0, 3000, 0, 5000],
        "被服費":   [0, 0, 15000, 0, 0, 8000, 0],
    }

    # 過去4週間分のデータを生成
    for week_offset in range(4):
        for day_offset in range(7):
            d = today - timedelta(weeks=week_offset, days=(6 - day_offset))
            date_str = d.strftime("%Y-%m-%dT12:00:00")

            for cat, amounts in categories.items():
                base_amount = amounts[day_offset]
                if base_amount == 0:
                    continue
                # 週ごとに少し変動させる
                variation = 1.0 - (week_offset * 0.1)
                amount = -int(base_amount * variation * random.uniform(0.8, 1.2))

                transactions.append(
                    (user_id, amount, f"{cat}の支出", cat, date_str)
                )

    conn.executemany(
        "INSERT INTO transactions (user_id, amount, purpose, category, datetime) "
        "VALUES (?, ?, ?, ?, ?)",
        transactions,
    )
    conn.commit()
    conn.close()


# ── エンドポイント ────────────────────────────────────────


@app.route("/api/health")
def health():
    return jsonify({
        "status": "ok",
        "server": "kozuchi-backend",
        "version": "1.0.0",
    })


@app.route("/api/transactions")
def get_transactions():
    """
    取引データ取得。

    Query params:
      user_id    - ユーザーID (default: "user_001")
      type       - "income" | "expense" | "all" (default: "all")
      start_date - YYYY-MM-DD (default: 30日前)
      end_date   - YYYY-MM-DD (default: 今日)
      category   - カテゴリフィルタ (任意)
      limit      - 最大返却数 (default: 200)
    """
    user_id = request.args.get("user_id", DEFAULT_USER_ID)
    tx_type = request.args.get("type", "all")
    start_date = request.args.get("start_date")
    end_date = request.args.get("end_date")
    category = request.args.get("category")
    limit = min(int(request.args.get("limit", 200)), 1000)

    if not start_date:
        start_date = (datetime.now() - timedelta(days=30)).strftime("%Y-%m-%d")
    if not end_date:
        end_date = datetime.now().strftime("%Y-%m-%d")

    conn = get_db()
    query = """
        SELECT id, user_id, amount, purpose, category, datetime
        FROM transactions
        WHERE user_id = ?
          AND datetime >= ?
          AND datetime <= ?
    """
    params = [user_id, start_date, end_date + "T23:59:59"]

    if tx_type == "income":
        query += " AND amount >= 0"
    elif tx_type == "expense":
        query += " AND amount < 0"

    if category:
        query += " AND category = ?"
        params.append(category)

    query += " ORDER BY datetime DESC LIMIT ?"
    params.append(limit)

    rows = conn.execute(query, params).fetchall()
    conn.close()

    data = [dict(r) for r in rows]
    return jsonify({"data": data, "count": len(data)})


@app.route("/api/transactions/export")
def export_transactions_csv():
    """
    取引データをCSVでエクスポートする。

    Query params:
      user_id    - ユーザーID (default: "user_001")
      start_date - YYYY-MM-DD (任意。指定なし＝全期間)
      end_date   - YYYY-MM-DD (任意。指定なし＝全期間)

    Returns:
      Content-Type: text/csv; charset=utf-8
      カラム: 日付, 用途, カテゴリ, 金額（符号付き）

    Errors:
      400 - 日付形式が無効な場合
    """
    user_id = request.args.get("user_id", DEFAULT_USER_ID)

    # 日付バリデーション
    try:
        start_date = validate_date(request.args.get("start_date"))
        end_date = validate_date(request.args.get("end_date"))
    except ValueError as e:
        return jsonify({"error": str(e)}), 400

    # クエリ構築
    conn = get_db()
    query = """
        SELECT id, user_id, amount, purpose, category, datetime
        FROM transactions
        WHERE user_id = ?
    """
    params = [user_id]

    if start_date:
        query += " AND datetime >= ?"
        params.append(start_date)
    if end_date:
        query += " AND datetime <= ?"
        params.append(end_date + "T23:59:59")

    query += " ORDER BY datetime DESC"

    rows = conn.execute(query, params).fetchall()
    conn.close()

    # CSV生成
    transactions = [dict(r) for r in rows]
    csv_content = format_transactions_csv(transactions)

    return Response(
        csv_content,
        mimetype="text/csv",
        headers={
            "Content-Disposition": "attachment; filename=transactions.csv",
            "Content-Type": "text/csv; charset=utf-8",
        },
    )


@app.route("/api/transactions/email", methods=["POST"])
def email_transactions_csv():
    """
    取引データのCSVを指定されたメールアドレスに送信する。

    Request body (JSON):
      {
        "email": "recipient@example.com",     // 必須: 送信先メールアドレス
        "user_id": "user_001",                // 任意: ユーザーID
        "start_date": "2026-01-01",           // 任意: CSV範囲（start_date/end_dateのいずれか）
        "end_date": "2026-06-23"              // 任意: CSV範囲
      }

    Response (成功):
      {"success": true, "message": "メールを xxx@example.com に送信しました"}
      status: 200

    Response (エラー):
      {"error": "エラーメッセージ"}
      status: 400 (バリデーション), 429 (レート制限), 500 (送信失敗)
    """
    body = request.get_json(silent=True) or {}
    to_email = (body.get("email") or "").strip()
    user_id = body.get("user_id", DEFAULT_USER_ID)

    # ── メールアドレスバリデーション ──
    if not to_email:
        return jsonify({"error": "メールアドレスを指定してください"}), 400
    if not validate_email(to_email):
        return jsonify({"error": f"無効なメールアドレス形式です: {to_email}"}), 400

    # ── レート制限（IPベース） ──
    client_ip = request.remote_addr or "unknown"
    if not check_rate_limit(client_ip):
        return jsonify({
            "error": "送信回数の上限に達しました。しばらく待ってから再試行してください。"
        }), 429

    # ── レート制限（メールアドレスベースも） ──
    if not check_rate_limit(f"email:{to_email}"):
        return jsonify({
            "error": "このメールアドレスへの送信回数が上限に達しました。"
        }), 429

    # ── CSV取得（パラメータから生成、またはリクエストから直接） ──
    try:
        start_date = validate_date(body.get("start_date"))
        end_date = validate_date(body.get("end_date"))
    except ValueError as e:
        return jsonify({"error": str(e)}), 400

    conn = get_db()
    query = """
        SELECT id, user_id, amount, purpose, category, datetime
        FROM transactions
        WHERE user_id = ?
    """
    params = [user_id]

    if start_date:
        query += " AND datetime >= ?"
        params.append(start_date)
    if end_date:
        query += " AND datetime <= ?"
        params.append(end_date + "T23:59:59")

    query += " ORDER BY datetime DESC"

    rows = conn.execute(query, params).fetchall()
    conn.close()

    if not rows:
        return jsonify({"error": "指定された期間に取引データがありません"}), 404

    transactions = [dict(r) for r in rows]
    csv_content = format_transactions_csv(transactions)

    # ── メール送信 ──
    try:
        result = send_csv_email(to_email, csv_content)
        return jsonify(result), 200
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except EmailSendError as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/drive/upload", methods=["POST"])
def upload_to_drive():
    """
    CSVデータをGoogle Driveにアップロードし、共有リンクを返す。

    Request body (JSON):
      {
        "csv_content": "日付,用途,カテゴリ,金額\\n2026-06-23,食費,食費,-1500\\n",
        "filename": "kozuchi_export_2026-06-23.csv"   // 任意
      }

    Response (200):
      {
        "status": "uploaded",
        "file_id": "xxx",
        "file_name": "kozuchi_export_2026-06-23.csv",
        "web_view_link": "https://drive.google.com/file/d/xxx/view",
        "uploaded_at": "2026-06-23T12:00:00"
      }

    Errors:
      400 - CSVデータが空の場合
      401 - Google認証が未完了
      403 - Drive権限不足
      500 - アップロード失敗
    """
    body = request.get_json(silent=True) or {}
    csv_content = body.get("csv_content", "").strip()
    filename = body.get("filename")

    if not csv_content:
        return jsonify({"error": "CSVデータが空です。エクスポートを先に実行してください。"}), 400

    try:
        result = upload_csv_to_drive(
            csv_content,
            filename=filename,
        )
        return jsonify({
            "status": "uploaded",
            **result,
        })
    except DriveUploadError as e:
        status_code = {
            "DRIVE_EMPTY_CONTENT": 400,
            "DRIVE_NOT_AUTHENTICATED": 401,
            "DRIVE_PERMISSION_DENIED": 403,
            "DRIVE_TIMEOUT": 504,
            "DRIVE_API_ERROR": 500,
            "DRIVE_PARSE_ERROR": 500,
            "DRIVE_NOT_CONFIGURED": 500,
            "DRIVE_UPLOAD_FAILED": 500,
        }.get(e.code, 500)

        return jsonify({
            "error": e.message,
            "code": e.code,
        }), status_code


@app.route("/api/quests/generate", methods=["POST"])
def generate_quests():
    """
    週間クエスト候補を生成する。

    Request body (JSON):
      {
        "user_id": "user_001",           // 必須
        "weeks": 4,                      // 分析対象週数 (default: 4)
        "num_quests": 0,                 // 生成数 (0=自動, default: 0)
        "seed": null                     // 乱数シード (任意)
      }

    Response:
      {
        "user_id": "user_001",
        "generated_at": "2026-06-23T...",
        "quests": [ {...}, ... ],
        "count": 3
      }
    """
    body = request.get_json(silent=True) or {}
    user_id = body.get("user_id", DEFAULT_USER_ID)
    weeks = min(int(body.get("weeks", 4)), 12)
    num_quests = int(body.get("num_quests", 0))
    seed = body.get("seed")

    # 取引データ取得
    start_date = (datetime.now() - timedelta(weeks=weeks)).strftime("%Y-%m-%d")
    end_date = datetime.now().strftime("%Y-%m-%d")

    conn = get_db()
    rows = conn.execute(
        """SELECT amount, purpose, category, datetime
           FROM transactions
           WHERE user_id = ?
             AND datetime >= ?
             AND datetime <= ?
           ORDER BY datetime DESC""",
        (user_id, start_date, end_date + "T23:59:59"),
    ).fetchall()
    conn.close()

    transactions = [
        Transaction(
            amount=r["amount"],
            purpose=r["purpose"] or "",
            category=r["category"] or "",
            datetime=r["datetime"],
        )
        for r in rows
    ]

    # クエスト生成
    quests = generate_weekly_quests(
        transactions,
        user_id=user_id,
        num_quests=num_quests,
        seed=seed,
    )

    # 生成結果をDBに保存
    week_start = _get_current_week_monday().strftime("%Y-%m-%d")
    conn = get_db()
    for q in quests:
        conn.execute(
            """INSERT OR REPLACE INTO quests (id, user_id, week_start, data)
               VALUES (?, ?, ?, ?)""",
            (q.id, user_id, week_start, json.dumps(quests_to_dict([q])[0], ensure_ascii=False)),
        )
    conn.commit()
    conn.close()

    return jsonify({
        "user_id": user_id,
        "generated_at": datetime.now().isoformat(),
        "week_start": week_start,
        "quests": quests_to_dict(quests),
        "count": len(quests),
    })


@app.route("/api/quests/<user_id>")
def get_user_quests(user_id: str):
    """ユーザーの現在の週間クエストを取得"""
    week_start = _get_current_week_monday().strftime("%Y-%m-%d")

    conn = get_db()
    rows = conn.execute(
        "SELECT data FROM quests WHERE user_id = ? AND week_start = ?",
        (user_id, week_start),
    ).fetchall()
    conn.close()

    quests = [json.loads(r["data"]) for r in rows]
    return jsonify({
        "user_id": user_id,
        "week_start": week_start,
        "quests": quests,
        "count": len(quests),
    })


@app.route("/api/weekly-report")
def get_weekly_report():
    """
    Weekly spending report endpoint.

    Query params:
      user_id - User ID (default: "user_001")
      week    - ISO week string 'YYYY-WWW' (default: current week)
      cache   - Use cached report 'true'|'false' (default: 'true')
    """
    user_id = request.args.get("user_id", DEFAULT_USER_ID)
    week_str = request.args.get("week")
    use_cache = request.args.get("cache", "true").lower() == "true"

    try:
        report = generate_weekly_report(
            user_id=user_id,
            week_str=week_str,
            use_cache=use_cache,
        )
        return jsonify(report)
    except ValueError as e:
        return jsonify({"error": str(e)}), 400

# ── ユーティリティ ────────────────────────────────────────

def _get_current_week_monday() -> datetime:
    today = datetime.now()
    monday = today - timedelta(days=today.weekday())
    return monday.replace(hour=0, minute=0, second=0, microsecond=0)


# ── メイン ─────────────────────────────────────────────────

if __name__ == "__main__":
    import random
    random.seed(42)  # シードデータの再現性

    init_db()
    seed_demo_data()

    port = int(os.environ.get("PORT", 8080))
    print(f"🧧 kozuchi backend starting on port {port}...")
    app.run(host="0.0.0.0", port=port, debug=True)
