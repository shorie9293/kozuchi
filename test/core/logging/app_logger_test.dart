import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/logging/app_logger.dart';

void main() {
  group('AppLogger', () {
    late List<String> lines;
    late AppLogger Function({bool? isDebug, LogSink? sink}) build;

    setUp(() {
      lines = <String>[];
      build = ({bool? isDebug, LogSink? sink}) =>
          AppLogger(isDebug: isDebug, sink: sink ?? lines.add);
    });

    test('debug は isDebug=true ならレベルタグ付きで出力する', () {
      build(isDebug: true).debug('payload 解析');
      expect(lines, hasLength(1));
      expect(lines.single, contains('[DEBUG]'));
      expect(lines.single, contains('payload 解析'));
    });

    test('debug は isDebug=false なら無出力', () {
      build(isDebug: false).debug('本番では出ない');
      expect(lines, isEmpty);
    });

    test('info は isDebug=false なら無出力 / true なら出力', () {
      build(isDebug: false).info('本番では出ない');
      expect(lines, isEmpty);

      build(isDebug: true).info('開発時のみ');
      expect(lines.single, contains('[INFO]'));
      expect(lines.single, contains('開発時のみ'));
    });

    test('warn は isDebug=false でも常時出力し、例外を添えられる', () {
      final error = StateError('失敗');
      final stack = StackTrace.current;
      build(isDebug: false).warn('バックアップ失敗', error, stack);

      expect(lines, hasLength(1));
      expect(lines.single, contains('[WARN]'));
      expect(lines.single, contains('バックアップ失敗'));
      expect(lines.single, contains('Bad state: 失敗'));
      expect(lines.single, contains('stack='));
    });

    test('error は isDebug=false でも常時出力する', () {
      build(isDebug: false).error('致命的失敗', Exception('boom'));

      expect(lines, hasLength(1));
      expect(lines.single, contains('[ERROR]'));
      expect(lines.single, contains('致命的失敗'));
      expect(lines.single, contains('boom'));
    });

    test('error は例外情報なしでも出力できる', () {
      build(isDebug: false).error('単独メッセージ');
      expect(lines.single, contains('[ERROR] 単独メッセージ'));
    });

    test('出力先が例外を投げても呼び出し元へ伝播しない', () {
      final throwing = AppLogger(
        isDebug: true,
        sink: (_) => throw Exception('sink broken'),
      );

      expect(() => throwing.debug('debug'), returnsNormally);
      expect(() => throwing.info('info'), returnsNormally);
      expect(() => throwing.warn('warn'), returnsNormally);
      expect(() => throwing.error('error'), returnsNormally);
    });

    test('isDebug 省略時は kDebugMode に従う', () {
      expect(AppLogger().isDebug, kDebugMode);
    });

    test('appLog は既定設定の AppLogger 実体', () {
      expect(appLog, isA<AppLogger>());
      expect(appLog.isDebug, kDebugMode);
    });
  });
}
