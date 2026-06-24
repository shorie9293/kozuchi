import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/auth_service.dart';

void main() {
  group('AuthService', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    group('constructor', () {
      test('AuthService が例外なくインスタンス化できること', () {
        expect(authService, isA<AuthService>());
      });
    });

    group('currentUserId (static)', () {
      test('Supabase未初期化時の currentUserId の型は String?', () {
        // 静的解析確認：currentUserId は String? 型
        // 未初期化時は StateError がスローされる
        expect(
          () => AuthService.currentUserId,
          throwsA(isA<StateError>()),
        );
      });
    });

    group('API contracts', () {
      test('signInAnonymously は Supabase 未初期化時に StateError', () {
        // 実行時はSupabase未初期化のため StateError がスローされる
        expect(
          () => authService.signInAnonymously(),
          throwsA(isA<StateError>()),
        );
      });

      test('isAuthenticated は Supabase 未初期化時に StateError', () {
        expect(
          () => authService.isAuthenticated,
          throwsA(isA<StateError>()),
        );
      });

      test('currentSession は Supabase 未初期化時に StateError', () {
        expect(
          () => authService.currentSession,
          throwsA(isA<StateError>()),
        );
      });

      test('onAuthStateChange は Supabase 未初期化時に StateError', () {
        expect(
          () => authService.onAuthStateChange,
          throwsA(isA<StateError>()),
        );
      });

      test('signOut は Supabase 未初期化時に StateError', () {
        expect(
          () => authService.signOut(),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
