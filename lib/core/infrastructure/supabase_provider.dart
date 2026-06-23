import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabaseクライアントの遅延初期化プロバイダ
///
/// main.dart の `Supabase.initialize()` 後にアクセス可能。
/// 使用例:
/// ```dart
/// final client = SupabaseProvider.client;
/// final data = await client.from('table').select();
/// ```
class SupabaseProvider {
  SupabaseProvider._();

  static SupabaseClient get client {
    final instance = Supabase.instance;
    if (instance.client == null) {
      throw StateError(
        'Supabase has not been initialized. '
        'Call Supabase.initialize() before accessing SupabaseProvider.client.',
      );
    }
    return instance.client;
  }
}
