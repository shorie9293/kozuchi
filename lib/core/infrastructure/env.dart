import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 環境変数への型安全アクセス
///
/// .env ファイル（Git管理外）から読み出し。
/// main.dart で `await dotenv.load()` が完了した後に使用すること。
class Env {
  Env._();

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? (throw Exception('SUPABASE_URL not set in .env'));

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? (throw Exception('SUPABASE_ANON_KEY not set in .env'));

  static String get achievementApiUrl =>
      dotenv.env['ACHIEVEMENT_API_URL'] ?? 'http://localhost:8100';
}
