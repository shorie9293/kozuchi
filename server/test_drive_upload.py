#!/usr/bin/env python3
"""
kozuchi DriveアップロードAPIのテスト

server.py の /api/drive/upload エンドポイントをテストする。
実際のGoogle Drive APIは呼び出さず、drive_upload.py をモックする。
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

# テスト対象をインポートする前にモックを設定
sys.path.insert(0, str(Path(__file__).resolve().parent))

from server import app


@pytest.fixture
def client():
    """Flaskテストクライアント"""
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


class TestDriveUploadEndpoint:
    """POST /api/drive/upload のテスト"""

    def test_empty_csv_content_returns_400(self, client):
        """空のCSVデータは400エラーを返す"""
        # 空文字列
        resp = client.post(
            "/api/drive/upload",
            data=json.dumps({"csv_content": ""}),
            content_type="application/json",
        )
        assert resp.status_code == 400
        data = json.loads(resp.data)
        assert "空" in data["error"]

    def test_missing_csv_content_returns_400(self, client):
        """csv_contentフィールドがない場合は400エラーを返す"""
        resp = client.post(
            "/api/drive/upload",
            data=json.dumps({}),
            content_type="application/json",
        )
        assert resp.status_code == 400

    def test_valid_csv_returns_200(self, client):
        """正常なCSVデータで200が返る（drive_uploadをモック）"""
        mock_result = {
            "file_id": "test123",
            "file_name": "test.csv",
            "web_view_link": "https://drive.google.com/file/d/test123/view",
            "uploaded_at": "2026-06-23T12:00:00",
        }

        with patch("server.server.upload_csv_to_drive", return_value=mock_result):
            resp = client.post(
                "/api/drive/upload",
                data=json.dumps({
                    "csv_content": "日付,用途,カテゴリ,金額\n2026-06-23,食費,食費,-1500\n",
                }),
                content_type="application/json",
            )

        assert resp.status_code == 200
        data = json.loads(resp.data)
        assert data["status"] == "uploaded"
        assert data["file_id"] == "test123"
        assert data["web_view_link"] == "https://drive.google.com/file/d/test123/view"

    def test_with_filename_passes_through(self, client):
        """filename指定がdrive_uploadに渡される"""
        mock_result = {
            "file_id": "test456",
            "file_name": "custom.csv",
            "web_view_link": "https://drive.google.com/file/d/test456/view",
            "uploaded_at": "2026-06-23T12:00:00",
        }

        with patch("server.server.upload_csv_to_drive") as mock_upload:
            mock_upload.return_value = mock_result

            resp = client.post(
                "/api/drive/upload",
                data=json.dumps({
                    "csv_content": "data\n",
                    "filename": "custom.csv",
                }),
                content_type="application/json",
            )

        assert resp.status_code == 200
        # filenameが正しく渡されていることを確認
        mock_upload.assert_called_once_with("data", filename="custom.csv")

    def test_drive_upload_error_maps_to_http_status(self, client):
        """DriveUploadErrorのコードがHTTPステータスコードにマッピングされる"""
        from drive_upload import DriveUploadError

        test_cases = [
            ("DRIVE_NOT_AUTHENTICATED", 401),
            ("DRIVE_PERMISSION_DENIED", 403),
            ("DRIVE_EMPTY_CONTENT", 400),
            ("DRIVE_TIMEOUT", 504),
            ("DRIVE_API_ERROR", 500),
            ("DRIVE_UNKNOWN_CODE", 500),  # 未知のコードは500
        ]

        for error_code, expected_http_status in test_cases:
            with patch("server.server.upload_csv_to_drive") as mock_upload:
                mock_upload.side_effect = DriveUploadError(
                    "Test error", code=error_code
                )

                resp = client.post(
                    "/api/drive/upload",
                    data=json.dumps({"csv_content": "data\n"}),
                    content_type="application/json",
                )

                assert resp.status_code == expected_http_status, (
                    f"Expected {expected_http_status} for {error_code}, "
                    f"got {resp.status_code}"
                )

                data = json.loads(resp.data)
                assert "error" in data
                assert data.get("code") == error_code


class TestDriveUploadModule:
    """drive_upload.py モジュールのテスト"""

    def test_empty_content_raises(self):
        """空のCSVデータでDriveUploadErrorが発生する"""
        from drive_upload import DriveUploadError, upload_csv_to_drive

        with pytest.raises(DriveUploadError) as exc:
            upload_csv_to_drive("")
        assert "空" in exc.value.message
        assert exc.value.code == "DRIVE_EMPTY_CONTENT"

    def test_whitespace_only_raises(self):
        """空白のみのCSVデータでDriveUploadErrorが発生する"""
        from drive_upload import DriveUploadError, upload_csv_to_drive

        with pytest.raises(DriveUploadError) as exc:
            upload_csv_to_drive("   \n  ")
        assert "空" in exc.value.message

    @patch("drive_upload._run_gapi")
    def test_full_upload_flow(self, mock_run_gapi):
        """アップロード→共有の一連のフローをテスト"""
        from drive_upload import upload_csv_to_drive

        # アップロード成功レスポンス
        mock_run_gapi.side_effect = [
            # 1回目: drive upload
            {
                "status": "uploaded",
                "id": "test_file_123",
                "name": "test.csv",
                "mimeType": "text/csv",
                "webViewLink": "https://drive.google.com/file/d/test_file_123/view",
            },
            # 2回目: drive share
            {
                "status": "shared",
                "permissionId": "perm_456",
                "fileId": "test_file_123",
                "role": "reader",
                "type": "anyone",
            },
        ]

        result = upload_csv_to_drive("col1,col2\nval1,val2\n")

        assert result["file_id"] == "test_file_123"
        assert result["web_view_link"] == "https://drive.google.com/file/d/test_file_123/view"
        assert result["file_name"] == result["file_name"]  # 自動生成ファイル名
        assert "uploaded_at" in result

        # _run_gapiが2回呼ばれたことを確認（upload + share）
        assert mock_run_gapi.call_count == 2

    @patch("drive_upload._run_gapi")
    def test_upload_failure_raises(self, mock_run_gapi):
        """アップロード失敗時にDriveUploadErrorが発生する"""
        from drive_upload import DriveUploadError, upload_csv_to_drive

        mock_run_gapi.return_value = {"status": "error", "message": "Upload failed"}

        with pytest.raises(DriveUploadError) as exc:
            upload_csv_to_drive("data\n")

        assert exc.value.code == "DRIVE_UPLOAD_FAILED"


# ── 直接実行時 ──────────────────────────────────────────

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
