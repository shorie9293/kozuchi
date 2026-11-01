import 'dart:async';
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

  /// 通信の打ち切り時間。圏外・無応答で画面が永久に待つのを防ぐ。
  final Duration _timeout;

  /// 既定の打ち切り時間。
  static const Duration defaultTimeout = Duration(seconds: 10);

  WeeklyReportApiService({
    String? baseUrl,
    http.Client? client,
    Duration timeout = defaultTimeout,
  })  : _baseUrl = baseUrl ?? Env.weeklyReportApiUrl,
        _client = client ?? _DefaultHttpClient(),
        _timeout = timeout {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', '打ち切り時間は正の値であること');
    }
  }

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

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on TimeoutException catch (e) {
      throw WeeklyReportApiException(
        'レポートの取得が時間内に応答しませんでした（時間切れ）',
        isTimeout: true,
        cause: e,
      );
    }

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

  /// 打ち切り時間の超過（圏外・無応答）で発生したことを示す。
  final bool isTimeout;

  /// 元の例外（[TimeoutException] 等）。
  final Object? cause;

  const WeeklyReportApiException(
    this.message, {
    this.statusCode,
    this.isTimeout = false,
    this.cause,
  });

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
