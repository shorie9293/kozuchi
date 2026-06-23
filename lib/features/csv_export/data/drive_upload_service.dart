import 'dart:convert';

import 'package:http/http.dart' as http;

/// Driveアップロードサービスの例外
class DriveUploadException implements Exception {
  final String message;
  final String code;

  const DriveUploadException(this.message, {this.code = 'DRIVE_ERROR'});

  @override
  String toString() => 'DriveUploadException: $message (code: $code)';
}

/// Google Driveアップロードサービス
///
/// `POST /api/drive/upload` エンドポイントを叩き、
/// CSVデータをGoogle Driveにアップロードして共有リンクを取得する。
class DriveUploadService {
  final http.Client _client;
  final String _baseUrl;

  DriveUploadService({
    http.Client? client,
    String baseUrl = 'http://localhost:8080',
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl;

  /// CSVデータをGoogle Driveにアップロードし、共有リンクを返す
  ///
  /// [csvContent] アップロードするCSV文字列
  /// [filename] ファイル名（任意、指定しない場合はサーバー側で自動生成）
  ///
  /// 成功時: `DriveUploadResult` を返す
  /// 失敗時: [DriveUploadException] を投げる
  Future<DriveUploadResult> uploadCsv(
    String csvContent, {
    String? filename,
  }) async {
    if (csvContent.trim().isEmpty) {
      throw const DriveUploadException(
        'CSVデータが空です。エクスポートを先に実行してください。',
        code: 'DRIVE_EMPTY_CONTENT',
      );
    }

    final uri = Uri.parse('$_baseUrl/api/drive/upload');
    final body = <String, dynamic>{
      'csv_content': csvContent,
    };
    if (filename != null) {
      body['filename'] = filename;
    }

    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        return DriveUploadResult.fromJson(data);
      }

      // エラーレスポンスのパース
      String errorMessage = 'Driveアップロードに失敗しました';
      String errorCode = 'DRIVE_ERROR';
      try {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        errorMessage = errorData['error'] as String? ?? errorMessage;
        errorCode = errorData['code'] as String? ?? errorCode;
      } catch (_) {
        errorMessage = response.body;
      }

      throw DriveUploadException(errorMessage, code: errorCode);
    } on http.ClientException catch (e) {
      throw DriveUploadException(
        'ネットワークエラー: ${e.message}',
        code: 'DRIVE_NETWORK_ERROR',
      );
    } on FormatException catch (e) {
      throw DriveUploadException(
        '応答の解析に失敗しました: ${e.message}',
        code: 'DRIVE_PARSE_ERROR',
      );
    } on DriveUploadException {
      rethrow;
    }
  }

  /// リソースを解放する
  void dispose() {
    _client.close();
  }
}

/// Driveアップロード結果
class DriveUploadResult {
  final String fileId;
  final String fileName;
  final String webViewLink;
  final String uploadedAt;

  const DriveUploadResult({
    required this.fileId,
    required this.fileName,
    required this.webViewLink,
    required this.uploadedAt,
  });

  factory DriveUploadResult.fromJson(Map<String, dynamic> json) {
    return DriveUploadResult(
      fileId: json['file_id'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      webViewLink: json['web_view_link'] as String? ?? '',
      uploadedAt: json['uploaded_at'] as String? ?? '',
    );
  }
}
