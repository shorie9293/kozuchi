import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'goal.dart';

/// 目標管理 API サービス
///
/// kozuchiサーバーの /api/goals エンドポイントと通信する。
class GoalApiService {
  final String _baseUrl;
  final http.Client _client;
  final String _userId;

  /// 通信の打ち切り時間。圏外・無応答で画面が永久に待つのを防ぐ。
  final Duration _timeout;

  /// 既定の打ち切り時間。
  static const Duration defaultTimeout = Duration(seconds: 10);

  GoalApiService({
    required String baseUrl,
    http.Client? client,
    String userId = 'user_001',
    Duration timeout = defaultTimeout,
  })  : _baseUrl = baseUrl,
        _client = client ?? _DefaultHttpClient(),
        _userId = userId,
        _timeout = timeout {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', '打ち切り時間は正の値であること');
    }
  }

  /// 打ち切り時間を課して送る。時間切れは「失敗」として投げる。
  Future<http.Response> _send(
    Future<http.Response> Function() request,
    String what,
  ) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException catch (e) {
      throw GoalApiException(
        '$whatが時間内に応答しませんでした（時間切れ）',
        isTimeout: true,
        cause: e,
      );
    }
  }

  /// 目標一覧を取得する
  ///
  /// [status] でフィルタ可能: "active" | "completed" | "cancelled"
  Future<GoalListResponse> listGoals({
    String? status,
  }) async {
    final params = <String, String>{
      'user_id': _userId,
      if (status != null) 'status': status,
    };
    final uri = Uri.parse('$_baseUrl/api/goals').replace(
      queryParameters: params,
    );

    final response = await _send(() => _client.get(uri), '目標一覧の取得');
    _checkResponse(response);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return GoalListResponse.fromJson(body);
  }

  /// 単一の目標を取得する
  Future<Goal> getGoal(String goalId) async {
    final uri = Uri.parse('$_baseUrl/api/goals/$goalId').replace(
      queryParameters: {'user_id': _userId},
    );

    final response = await _send(() => _client.get(uri), '目標の取得');
    _checkResponse(response);

    return Goal.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// 新しい目標を作成する
  Future<Goal> createGoal({
    required String title,
    required int targetAmount,
    String? deadline,
    int currentAmount = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/goals');

    final response = await _send(
      () => _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _userId,
          'title': title,
          'target_amount': targetAmount,
          if (deadline != null) 'deadline': deadline,
          'current_amount': currentAmount,
        }),
      ),
      '目標の作成',
    );
    _checkResponse(response);

    return Goal.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// 目標を更新する（進捗・詳細・ステータス変更）
  ///
  /// 指定したフィールドのみ更新される。
  /// current_amount >= target_amount の場合、自動で完了になる。
  Future<Goal> updateGoal(
    String goalId, {
    String? title,
    int? targetAmount,
    String? deadline,
    int? currentAmount,
    String? status,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/goals/$goalId');

    final body = <String, dynamic>{'user_id': _userId};
    if (title != null) body['title'] = title;
    if (targetAmount != null) body['target_amount'] = targetAmount;
    if (deadline != null) body['deadline'] = deadline;
    if (currentAmount != null) body['current_amount'] = currentAmount;
    if (status != null) body['status'] = status;

    final response = await _send(
      () => _client.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
      '目標の更新',
    );
    _checkResponse(response);

    return Goal.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// 目標を削除する
  Future<void> deleteGoal(String goalId) async {
    final uri = Uri.parse('$_baseUrl/api/goals/$goalId').replace(
      queryParameters: {'user_id': _userId},
    );

    final response = await _send(() => _client.delete(uri), '目標の削除');
    if (response.statusCode != 204) {
      throw GoalApiException(
        '目標の削除に失敗しました (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
  }

  /// レスポンスのステータスコードとエラーボディをチェック
  void _checkResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String message;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = body['error'] as String? ??
          body['detail'] as String? ??
          'Unknown error';
    } catch (_) {
      message = 'HTTP ${response.statusCode}';
    }

    throw GoalApiException(message, statusCode: response.statusCode);
  }
}

/// 目標一覧レスポンス
class GoalListResponse {
  final List<Goal> goals;
  final int total;

  const GoalListResponse({required this.goals, required this.total});

  factory GoalListResponse.fromJson(Map<String, dynamic> json) {
    return GoalListResponse(
      goals: (json['goals'] as List<dynamic>)
          .map((g) => Goal.fromJson(g as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
    );
  }
}

/// API 呼び出し例外
class GoalApiException implements Exception {
  final String message;
  final int? statusCode;

  /// 打ち切り時間の超過（圏外・無応答）で発生したことを示す。
  final bool isTimeout;

  /// 元の例外（[TimeoutException] 等）。
  final Object? cause;

  const GoalApiException(
    this.message, {
    this.statusCode,
    this.isTimeout = false,
    this.cause,
  });

  @override
  String toString() =>
      'GoalApiException: $message${isTimeout ? ' (timeout)' : ''}';
}

/// デフォルト HTTP クライアント
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
