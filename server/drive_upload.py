#!/usr/bin/env python3
"""
kozuchi Google Drive upload module

CSVデータをGoogle Driveにアップロードし、共有可能なリンクを返す。
google_api.py をサブプロセスで呼び出し、認証・トークン更新・アップロード・共有を実行。
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Optional

# google_api.py へのパス
_HERMES_SKILLS = Path.home() / ".hermes" / "skills" / "productivity" / "google-workspace" / "scripts"
_GAPI = str(_HERMES_SKILLS / "google_api.py")


class DriveUploadError(Exception):
    """Google Driveアップロード時のエラー"""

    def __init__(self, message: str, code: str = "DRIVE_ERROR"):
        self.message = message
        self.code = code
        super().__init__(message)


def _run_gapi(*args: str) -> dict:
    """google_api.py を呼び出し、JSONレスポンスを返す"""
    cmd = ["python3", _GAPI, *args]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=60,
        )
    except subprocess.TimeoutExpired:
        raise DriveUploadError(
            "Google Drive APIがタイムアウトしました。ネットワーク接続を確認してください。",
            code="DRIVE_TIMEOUT",
        )
    except FileNotFoundError:
        raise DriveUploadError(
            f"google_api.py が見つかりません: {_GAPI}",
            code="DRIVE_NOT_CONFIGURED",
        )

    if result.returncode != 0:
        stderr = result.stderr.strip()
        # 認証エラーの判定
        if "Not authenticated" in stderr or "NOT_AUTHENTICATED" in stderr:
            raise DriveUploadError(
                "Google Drive認証が完了していません。setup.pyを実行してください。",
                code="DRIVE_NOT_AUTHENTICATED",
            )
        if "insufficient" in stderr.lower() or "permission" in stderr.lower():
            raise DriveUploadError(
                "Google Driveへの権限が不足しています。スコープを確認してください。",
                code="DRIVE_PERMISSION_DENIED",
            )
        raise DriveUploadError(
            f"Google Drive API呼び出しに失敗しました: {stderr or result.stdout.strip()}",
            code="DRIVE_API_ERROR",
        )

    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        raise DriveUploadError(
            f"Google Drive APIからの応答を解析できませんでした: {result.stdout[:200]}",
            code="DRIVE_PARSE_ERROR",
        )


def upload_csv_to_drive(
    csv_content: str,
    *,
    filename: Optional[str] = None,
    folder_name: str = "kozuchi-exports",
) -> dict:
    """
    CSVデータをGoogle Driveにアップロードし、共有リンクを返す。

    Args:
        csv_content: アップロードするCSVデータ（UTF-8文字列）
        filename: ファイル名（指定しない場合は自動生成）
        folder_name: 格納先フォルダ名（デフォルト: "kozuchi-exports"）

    Returns:
        {
            "file_id": "xxx",
            "file_name": "kozuchi_export_2026-06-23.csv",
            "web_view_link": "https://drive.google.com/file/d/xxx/view",
            "uploaded_at": "2026-06-23T12:00:00",
        }

    Raises:
        DriveUploadError: アップロードまたは共有に失敗した場合
    """
    if not csv_content or not csv_content.strip():
        raise DriveUploadError(
            "CSVデータが空です。エクスポートを先に実行してください。",
            code="DRIVE_EMPTY_CONTENT",
        )

    # ファイル名の生成
    if filename is None:
        timestamp = datetime.now().strftime("%Y-%m-%d_%H%M%S")
        filename = f"kozuchi_export_{timestamp}.csv"

    # 一時ファイルにCSVを書き出し
    # google_api.py はファイルパスを受け取るため、一時ファイル経由でアップロード
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            suffix=".csv",
            prefix="kozuchi_",
            encoding="utf-8",
            delete=False,
        ) as f:
            f.write(csv_content)
            tmp_path = f.name

        # 1. ファイルをDriveにアップロード
        upload_result = _run_gapi("drive", "upload", tmp_path, "--name", filename)

        if upload_result.get("status") != "uploaded":
            raise DriveUploadError(
                f"アップロードに失敗しました: {upload_result}",
                code="DRIVE_UPLOAD_FAILED",
            )

        file_id = upload_result["id"]
        web_view_link = upload_result.get("webViewLink", "")

        # 2. 共有設定: リンクを知っている全員が閲覧可能
        _run_gapi(
            "drive", "share", file_id,
            "--type", "anyone",
            "--role", "reader",
        )

        return {
            "file_id": file_id,
            "file_name": filename,
            "web_view_link": web_view_link,
            "uploaded_at": datetime.now().isoformat(),
        }

    finally:
        # 一時ファイルの削除
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except OSError:
                pass


# ── スタンドアロンテスト ──────────────────────────────────

if __name__ == "__main__":
    import sys

    # 簡易テスト: ダミーCSVをアップロード
    test_csv = "日付,用途,カテゴリ,金額\n2026-06-23,テスト支出,食費,-1500\n"

    try:
        result = upload_csv_to_drive(test_csv)
        print("アップロード成功:")
        print(json.dumps(result, indent=2, ensure_ascii=False))
    except DriveUploadError as e:
        print(f"エラー [{e.code}]: {e.message}", file=sys.stderr)
        sys.exit(1)
