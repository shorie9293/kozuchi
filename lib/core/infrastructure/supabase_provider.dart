import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabaseクライアントの遅延初期化プロバイダ
///
/// main.dart の `Supabase.initialize()` 後にアクセス可能。
/// 使用例:
/// ```dart
/// final client = SupabaseProvider.client;
/// final data = await client.from('table').select();
///
/// // 匿名ユーザーIDの取得（データ同期用）
/// final userId = SupabaseProvider.currentUserId;
/// ```
class SupabaseProvider {
  SupabaseProvider._();

  static SupabaseClient get client {
    try {
      return Supabase.instance.client;
    } on AssertionError {
      throw StateError(
        'Supabase has not been initialized. '
        'Call Supabase.initialize() before accessing SupabaseProvider.client.',
      );
    }
  }

  /// 現在の匿名ユーザーID（未認証時はnull）
  ///
  /// データ同期時の user_id カラムに使用する。
  /// 匿名認証完了後に利用可能。
  static String? get currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } on AssertionError {
      throw StateError(
        'Supabase has not been initialized. '
        'Call Supabase.initialize() before accessing SupabaseProvider.currentUserId.',
      );
    }
  }
}
