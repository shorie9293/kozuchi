import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kozuchi/core/infrastructure/env.dart';
import 'weekly_report.dart';

/// 週間レポートAPIサービス
///
/// kozuchiサーバーの GET /api/weekly-report エンドポイントから
/// 週間レポートデータを取得する。
class WeeklyReportApiService {
  final String _baseUrl;
  final http.Client _client;

  WeeklyReportApiService({
    String? baseUrl,
    http.Client? client,
  })  : _baseUrl = baseUrl ?? Env.weeklyReportApiUrl,
        _client = client ?? _DefaultHttpClient();

  /// 指定週のレポートを取得する
  ///
  /// [week] が null の場合は現在の週を使用。
  /// [userId] はデフォルトで "user_001"。
  Future<WeeklyReport> fetchReport({
    String? week,
    String userId = 'user_001',
  }) async {
    final uri = Uri.parse('$_baseUrl/api/weekly-report').replace(
      queryParameters: {
        if (week != null) 'week': week,
        'user_id': userId,
        'cache': 'true',
      },
    );

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw WeeklyReportApiException(
        'レポートの取得に失敗しました (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    // エラーレスポンスの確認
    if (body.containsKey('error')) {
      throw WeeklyReportApiException(body['error'] as String);
    }

    return WeeklyReport.fromApiJson(body);
  }
}

/// API呼び出し例外
class WeeklyReportApiException implements Exception {
  final String message;
  final int? statusCode;

  const WeeklyReportApiException(this.message, {this.statusCode});

  @override
  String toString() => 'WeeklyReportApiException: $message';
}

/// デフォルトHTTPクライアント
class _DefaultHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
