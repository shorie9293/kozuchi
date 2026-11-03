import 'package:flutter/foundation.dart';

/// ログ出力先。差し替え可能にして試練（テスト）で捕捉できるようにする。
typedef LogSink = void Function(String message);

/// 現世（アプリ）共通のロガー。
///
/// 本番ビルドでログが垂れ流しにならないよう、レベルごとに出力可否を制御する。
/// - [debug] / [info] — 開発時（[isDebug]）のみ出力。リリースビルドでは無出力。
/// - [warn] / [error] — 障害調査のため常時出力。
///
/// 出力先（[LogSink]）が例外を投げても呼び出し元へは伝播させない。
/// ログはあくまで観測手段であり、本処理を壊してはならない。
class AppLogger {
  AppLogger({bool? isDebug, LogSink? sink})
      : isDebug = isDebug ?? kDebugMode,
        _sink = sink ?? debugPrint;

  /// debug/info を出力するか。既定は [kDebugMode]（リリースでは false）。
  final bool isDebug;

  final LogSink _sink;

  /// 開発時のみ出力する詳細ログ。
  void debug(String message) {
    if (!isDebug) return;
    _emit('DEBUG', message);
  }

  /// 開発時のみ出力する情報ログ。
  void info(String message) {
    if (!isDebug) return;
    _emit('INFO', message);
  }

  /// 想定内の失敗・復旧可能な異常。常時出力。
  void warn(String message, [Object? error, StackTrace? stackTrace]) {
    _emit('WARN', _compose(message, error, stackTrace));
  }

  /// 想定外の失敗。常時出力。
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _emit('ERROR', _compose(message, error, stackTrace));
  }

  static String _compose(
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final buffer = StringBuffer(message);
    if (error != null) buffer.write(' | error=$error');
    if (stackTrace != null) buffer.write(' | stack=$stackTrace');
    return buffer.toString();
  }

  void _emit(String level, String message) {
    final line = '[$level] $message';
    try {
      _sink(line);
    } catch (_) {
      // ログ出力の失敗で本処理を止めない。
    }
  }
}

/// 現世共通のロガー実体。
final appLog = AppLogger();
