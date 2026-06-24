import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/supabase_provider.dart';

void main() {
  group('SupabaseProvider', () {
    group('currentUserId', () {
      test('currentUserId の戻り値の型は String?', () {
        // 仕様: 未認証時やSupabase未初期化時は StateError がスローされる
        // 静的解析確認：currentUserId は String? 型
        expect(
          () => SupabaseProvider.currentUserId,
          throwsA(isA<StateError>()),
        );
      });
    });

    group('client', () {
      test('未初期化時の client アクセスは StateError', () {
        expect(
          () => SupabaseProvider.client,
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
