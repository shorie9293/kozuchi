import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';

import 'package:kozuchi/core/crash/crash_log_entry.dart';
import 'package:kozuchi/core/crash/crash_log_repository.dart';
import 'package:kozuchi/core/crash/crash_log_service.dart';

/// 端末内クラッシュログの記録器（main からも差し替え可能）。
CrashLogger? _logger;
bool _installed = false;

/// Flutter の例外経路を「既存の処理 + 端末内ログ」へ合流させる。
///
/// - [FlutterError.onError] は既存ハンドラを必ず先に呼ぶ（Crashlytics 等を壊さない）。
/// - [PlatformDispatcher.onError] も既存ハンドラを先に呼び、未処理（false）を返す。
/// - 二重呼び出しは無害（2回目以降は何もしない）。
bool installCrashGuard({CrashLogRepository? repository}) {
  if (_installed) return true;

  final logger = CrashLogger(repository ?? FileCrashLogRepository());
  _logger = logger;

  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    previousOnError?.call(details);
    logger.record(
      details.exception,
      details.stack,
      kind: CrashKind.flutterError,
    );
  };

  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    previousPlatformOnError?.call(error, stack);
    logger.record(error, stack, kind: CrashKind.platformError);
    // 端末内ログは補助記録であり、未処理として上位へ委ねる。
    return false;
  };

  _installed = true;
  return true;
}

/// 試練用: 差し込んだ記録器を取り出す。
@visibleForTesting
CrashLogger? debugCrashLogger() => _logger;

/// 試練用: 導入状態を戻す（本番経路では呼ばない）。
@visibleForTesting
void debugResetCrashGuard() {
  _installed = false;
  _logger = null;
}
