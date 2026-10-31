import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/core/crash/crash_guard.dart';
import 'package:kozuchi/core/crash/crash_log_entry.dart';
import 'package:kozuchi/core/crash/crash_log_repository.dart';

void main() {
  group('installCrashGuard', () {
    late FlutterExceptionHandler? originalFlutterOnError;
    late bool Function(Object, StackTrace)? originalPlatformOnError;

    setUp(() {
      originalFlutterOnError = FlutterError.onError;
      originalPlatformOnError = PlatformDispatcher.instance.onError;
      debugResetCrashGuard();
    });

    tearDown(() {
      FlutterError.onError = originalFlutterOnError;
      PlatformDispatcher.instance.onError = originalPlatformOnError;
      debugResetCrashGuard();
    });

    test('既存の FlutterError.onError を壊さず、端末内ログにも記録する', () async {
      var existingCalls = 0;
      FlutterError.onError = (_) => existingCalls++;

      final repo = InMemoryCrashLogRepository();
      expect(installCrashGuard(repository: repo), isTrue);

      FlutterError.onError!(
        FlutterErrorDetails(
          exception: StateError('描画失敗'),
          stack: StackTrace.current,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(existingCalls, 1, reason: '既存ハンドラは必ず呼ばれる');
      final entries = await repo.loadAll();
      expect(entries.length, 1);
      expect(entries.single.kind, CrashKind.flutterError);
      expect(entries.single.message, contains('描画失敗'));
    });

    test('PlatformDispatcher.onError も合流し、未処理(false)を返す', () async {
      var existingCalls = 0;
      PlatformDispatcher.instance.onError = (_, __) {
        existingCalls++;
        return true;
      };

      final repo = InMemoryCrashLogRepository();
      installCrashGuard(repository: repo);

      final handled = PlatformDispatcher.instance.onError!(
        StateError('基盤失敗'),
        StackTrace.current,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(handled, isFalse);
      expect(existingCalls, 1);
      final entries = await repo.loadAll();
      expect(entries.single.kind, CrashKind.platformError);
    });

    test('二重導入しても記録は1件のまま（冪等）', () async {
      final repo = InMemoryCrashLogRepository();
      installCrashGuard(repository: repo);
      final firstHandler = FlutterError.onError;
      installCrashGuard(repository: InMemoryCrashLogRepository());

      expect(identical(FlutterError.onError, firstHandler), isTrue);
    });
  });
}
