import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kozuchi/core/infrastructure/env.dart';
import 'package:kozuchi/domain/models/achievement_api_model.dart';
import 'package:kozuchi/domain/models/achievement_check_models.dart';

/// 実績APIとの通信を担当するサービス
///
/// GET /api/achievements から実績一覧を取得する。
/// user_id を指定するとユーザー別の解除状態・進捗を含めて返却される。
class AchievementService {
  final http.Client _client;
  final String? _baseUrlOverride;
  final Future<List<AchievementApiModel>> Function({String? userId})? _fetchOverride;

  AchievementService({http.Client? client, String? baseUrl,
      Future<List<AchievementApiModel>> Function({String? userId})? fetchOverride})
      : _client = client ?? http.Client(),
        _baseUrlOverride = baseUrl,
        _fetchOverride = fetchOverride;

  String get _baseUrl => _baseUrlOverride ?? Env.achievementApiUrl;

  /// 全実績を取得する
  ///
  /// [userId] を指定すると、そのユーザーの解除状態と進捗を含めて返す。
  /// 指定しない場合は全実績が unlocked=false で返される。
  Future<List<AchievementApiModel>> fetchAchievements({
    String? userId,
  }) async {
    if (_fetchOverride != null) {
      return _fetchOverride!(userId: userId);
    }

    final uri = Uri.parse('$_baseUrl/api/achievements').replace(
      queryParameters: userId != null ? {'user_id': userId} : null,
    );

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw AchievementServiceException(
        '実績の取得に失敗しました (status: ${response.statusCode})',
      );
    }

    final List<dynamic> jsonList = json.decode(response.body) as List<dynamic>;
    return jsonList
        .map((e) => AchievementApiModel.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }
  /// 実績チェックを実行し、新たに解除された実績を返す
  ///
  /// [request] にはユーザーIDと全基準値の現在値を含める。
  /// 戻り値の [AchievementCheckResponse.newlyUnlocked] が空でなければ
  /// ポップアップで実績解除を通知すること。
  Future<AchievementCheckResponse> checkAchievements(
    AchievementCheckRequest request,
  ) async {
    final uri = Uri.parse('$_baseUrl/api/achievements/check');

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(request.toJson()),
    );

    if (response.statusCode != 200) {
      throw AchievementServiceException(
        '実績チェックに失敗しました (status: ${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AchievementCheckResponse.fromJson(
      Map<String, dynamic>.from(data),
    );
  }
}

/// 実績サービスの例外
class AchievementServiceException implements Exception {
  final String message;
  const AchievementServiceException(this.message);

  @override
  String toString() => 'AchievementServiceException: $message';
}
