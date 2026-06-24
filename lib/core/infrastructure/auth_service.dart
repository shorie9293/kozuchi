import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 匿名認証サービス
///
/// アプリ起動時に匿名サインインを実行し、
/// 安定した匿名ユーザーIDをデータ同期用に提供する。
///
/// 使用方法:
/// ```dart
/// // main.dart で Supabase.initialize() 後に:
/// final authService = AuthService();
/// await authService.signInAnonymously();
///
/// // 任意の場所でユーザーID取得:
/// final userId = AuthService.currentUserId;
/// ```
class AuthService {
  AuthService();

  /// Supabaseクライアント
  SupabaseClient get _client {
    try {
      return Supabase.instance.client;
    } on AssertionError {
      throw StateError(
        'Supabase has not been initialized. '
        'Call Supabase.initialize() before using AuthService.',
      );
    }
  }

  /// 現在のユーザーが認証済みかどうか
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// 現在のユーザーID（未認証時はnull）
  /// データ同期時の user_id として使用する
  static String? get currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } on AssertionError {
      throw StateError(
        'Supabase has not been initialized. '
        'Call Supabase.initialize() before accessing AuthService.currentUserId.',
      );
    }
  }

  /// 現在のセッション（未認証時はnull）
  Session? get currentSession => _client.auth.currentSession;

  /// 匿名サインインを実行する
  ///
  /// - 既存セッションがある場合は何もしない（SDKが自動復元済み）
  /// - セッションがない場合のみ新規匿名サインイン
  /// - エラー時は例外を投げる
  ///
  /// 戻り値: 認証後のユーザーID
  Future<String> signInAnonymously() async {
    // 既存セッションがあれば再利用（SDKがSupabase.initialize()時点で復元済み）
    if (isAuthenticated) {
      final userId = _client.auth.currentUser!.id;
      return userId;
    }

    // 匿名サインイン実行
    try {
      final response = await _client.auth.signInAnonymously();
      final userId = response.user?.id;
      if (userId == null) {
        throw AuthException(
          'Anonymous sign-in succeeded but no user ID returned',
        );
      }
      return userId;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        'Failed to sign in anonymously: $e',
      );
    }
  }

  /// 認証状態の変化をリッスンする
  ///
  /// トークンリフレッシュ・サインアウト等のイベントを検知する。
  /// SDKが自動でトークンリフレッシュを行うため、通常は監視不要だが、
  /// デバッグやUI更新のために使用可能。
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// サインアウト（デバッグ・テスト用）
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
