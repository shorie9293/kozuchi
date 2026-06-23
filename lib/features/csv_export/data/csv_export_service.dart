import 'dart:convert';

import 'package:http/http.dart' as http;

/// CSVエクスポートサービスの例外
class CsvExportException implements Exception {
  final String message;
  const CsvExportException(this.message);

  @override
  String toString() => 'CsvExportException: $message';
}

/// CSVエクスポートサービス
///
/// `GET /api/transactions/export` エンドポイントを叩き、
/// CSVデータを文字列として取得する。
class CsvExportService {
  final http.Client _client;
  final String _baseUrl;

  CsvExportService({
    http.Client? client,
    String baseUrl = 'http://localhost:8080',
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl;

  /// 日付を YYYY-MM-DD 形式に整形する
  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// CSVデータをエクスポートする
  ///
  /// [startDate] と [endDate] で日付範囲を指定。
  /// 両方nullの場合は全期間のデータを取得。
  ///
  /// 成功時: CSV文字列を返す
  /// 失敗時: [CsvExportException] を投げる
  Future<String> exportCsv({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) {
      queryParams['start_date'] = _formatDate(startDate);
    }
    if (endDate != null) {
      queryParams['end_date'] = _formatDate(endDate);
    }

    final uri = Uri.parse('$_baseUrl/api/transactions/export')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    try {
      final response = await _client.get(uri).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';
        if (!contentType.contains('text/csv') &&
            !contentType.contains('application/csv') &&
            !contentType.contains('application/octet-stream')) {
          // content-type が期待と異なる場合も、中身がCSVっぽければ許容
        }
        return utf8.decode(response.bodyBytes);
      } else if (response.statusCode == 400) {
        throw CsvExportException('日付の形式が正しくありません');
      } else {
        throw CsvExportException(
          'API returned status ${response.statusCode}: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw CsvExportException('Network error: ${e.message}');
    } on FormatException catch (e) {
      throw CsvExportException('Invalid response format: ${e.message}');
    }
  }

  /// リソースを解放する
  void dispose() {
    _client.close();
  }

  /// CSVデータをメールで送信する
  ///
  /// [email] 送信先メールアドレス
  /// [startDate] / [endDate] でCSVの日付範囲を指定（省略可）
  ///
  /// 成功時: {"success": true, "message": "..."} を返す
  /// 失敗時: [CsvExportException] を投げる
  Future<Map<String, dynamic>> sendCsvByEmail({
    required String email,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final body = <String, dynamic>{
      'email': email,
    };
    if (startDate != null) {
      body['start_date'] = _formatDate(startDate);
    }
    if (endDate != null) {
      body['end_date'] = _formatDate(endDate);
    }

    final uri = Uri.parse('$_baseUrl/api/transactions/email');

    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: utf8.encode(jsonEncode(body)),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return data;
      } else if (response.statusCode == 429) {
        throw CsvExportException(
          data['error']?.toString() ?? '送信回数の上限に達しました',
        );
      } else if (response.statusCode == 400) {
        throw CsvExportException(
          data['error']?.toString() ?? '入力内容が正しくありません',
        );
      } else {
        throw CsvExportException(
          data['error']?.toString() ?? 'メール送信に失敗しました (${response.statusCode})',
        );
      }
    } on http.ClientException catch (e) {
      throw CsvExportException('Network error: ${e.message}');
    } on FormatException catch (e) {
      throw CsvExportException('Invalid response format: ${e.message}');
    }
  }
}
