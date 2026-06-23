#!/usr/bin/env python3
"""
kozuchi email service

CSV添付メール送信モジュール。
SMTP（smtplib）を使用し、設定は環境変数またはコード内デフォルトで制御。

環境変数:
  SMTP_HOST      - SMTPサーバー (default: smtp.gmail.com)
  SMTP_PORT      - SMTPポート (default: 587)
  SMTP_USER      - SMTPユーザー名 (default: Horie.shunta@gmail.com)
  SMTP_PASSWORD  - SMTPパスワード（Gmailアプリパスワード推奨）
  FROM_EMAIL     - 送信元アドレス (default: SMTP_USER)
"""

from __future__ import annotations

import os
import re
import smtplib
import time
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
from typing import Optional

# ── 設定 ──────────────────────────────────────────────────

SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER", "Horie.shunta@gmail.com")
SMTP_PASSWORD = os.environ.get("SMTP_PASSWORD", "")
FROM_EMAIL = os.environ.get("FROM_EMAIL", SMTP_USER)


# ── メールアドレスバリデーション ──────────────────────────

# RFC 5322 simplified regex
_EMAIL_RE = re.compile(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
    r"(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
)


def validate_email(email: str) -> bool:
    """メールアドレスの形式をバリデーションする。

    Args:
        email: 検証するメールアドレス文字列

    Returns:
        有効な形式ならTrue
    """
    if not email or not isinstance(email, str):
        return False
    if len(email) > 254:
        return False
    return bool(_EMAIL_RE.match(email))


# ── レート制限（簡易インメモリ） ──────────────────────────

# 構造: { key: [timestamps...] }
# key = IPアドレス or メールアドレス
_rate_limit_store: dict[str, list[float]] = {}

# 設定
RATE_LIMIT_MAX = int(os.environ.get("EMAIL_RATE_LIMIT_MAX", "5"))       # 最大回数
RATE_LIMIT_WINDOW = int(os.environ.get("EMAIL_RATE_LIMIT_WINDOW", "300"))  # 秒


def check_rate_limit(key: str) -> bool:
    """レート制限をチェックする。

    Args:
        key: 制限対象のキー（IPアドレス または メールアドレス）

    Returns:
        制限内ならTrue、超過ならFalse
    """
    now = time.time()
    window_start = now - RATE_LIMIT_WINDOW

    if key not in _rate_limit_store:
        _rate_limit_store[key] = []

    # 古いタイムスタンプを除去
    _rate_limit_store[key] = [
        ts for ts in _rate_limit_store[key] if ts > window_start
    ]

    if len(_rate_limit_store[key]) >= RATE_LIMIT_MAX:
        return False

    _rate_limit_store[key].append(now)
    return True


def _cleanup_rate_limits():
    """全キーの古いエントリを掃除する（定期的に呼ぶと良い）"""
    now = time.time()
    window_start = now - RATE_LIMIT_WINDOW
    for key in list(_rate_limit_store.keys()):
        _rate_limit_store[key] = [
            ts for ts in _rate_limit_store[key] if ts > window_start
        ]
        if not _rate_limit_store[key]:
            del _rate_limit_store[key]


# ── メール送信 ────────────────────────────────────────────


class EmailSendError(Exception):
    """メール送信エラー"""
    pass


def send_csv_email(
    to_email: str,
    csv_content: str,
    *,
    subject: str = "kozuchi 取引データ エクスポート",
    filename: str = "transactions.csv",
    from_email: str = FROM_EMAIL,
) -> dict:
    """CSVを添付したメールを送信する。

    Args:
        to_email: 送信先メールアドレス
        csv_content: CSVデータ（文字列）
        subject: メール件名
        filename: 添付ファイル名
        from_email: 送信元アドレス

    Returns:
        {"success": True, "message": "..."}

    Raises:
        EmailSendError: 送信失敗時
        ValueError: 引数が無効な場合
    """
    # バリデーション
    if not validate_email(to_email):
        raise ValueError(f"無効なメールアドレスです: {to_email}")

    if not csv_content:
        raise ValueError("CSVデータが空です")

    # SMTPパスワードが設定されていない場合
    if not SMTP_PASSWORD:
        raise EmailSendError(
            "SMTP_PASSWORD が設定されていません。"
            "環境変数 SMTP_PASSWORD を設定してください。"
        )

    # MIMEメッセージ構築
    msg = MIMEMultipart()
    msg["From"] = from_email
    msg["To"] = to_email
    msg["Subject"] = subject

    # 本文
    body = (
        f"kozuchi（小槌）から取引データをエクスポートしました。\n\n"
        f"添付ファイル: {filename}\n"
        f"データ件数: {_count_csv_rows(csv_content)} 件\n\n"
        f"---\n"
        f"このメールは kozuchi アプリから送信されました。\n"
    )
    msg.attach(MIMEText(body, "plain", "utf-8"))

    # CSV添付
    csv_part = MIMEBase("text", "csv")
    csv_part.set_payload(csv_content.encode("utf-8"))
    encoders.encode_base64(csv_part)
    csv_part.add_header(
        "Content-Disposition",
        f"attachment; filename={filename}",
    )
    msg.attach(csv_part)

    # SMTP送信
    try:
        server = smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=15)
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(SMTP_USER, SMTP_PASSWORD)
        server.sendmail(from_email, to_email, msg.as_string())
        server.quit()
    except smtplib.SMTPAuthenticationError as e:
        raise EmailSendError(
            f"SMTP認証に失敗しました。SMTP_USER/SMTP_PASSWORDを確認してください。"
        ) from e
    except smtplib.SMTPException as e:
        raise EmailSendError(f"SMTP送信エラー: {e}") from e
    except OSError as e:
        raise EmailSendError(f"ネットワークエラー: {e}") from e

    return {
        "success": True,
        "message": f"メールを {to_email} に送信しました",
    }


def _count_csv_rows(csv_content: str) -> int:
    """CSVのデータ行数を数える（ヘッダ行を除く）"""
    lines = csv_content.strip().split("\n")
    # BOMがある場合を考慮
    if lines and lines[0].startswith("\ufeff"):
        lines[0] = lines[0][1:]
    return max(0, len(lines) - 1)  # ヘッダ行を除く
