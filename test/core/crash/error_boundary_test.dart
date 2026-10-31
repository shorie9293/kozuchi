import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/core/crash/crash_log_entry.dart';
import 'package:kozuchi/core/crash/crash_log_screen.dart';
import 'package:kozuchi/core/crash/error_boundary.dart';
import 'package:kozuchi/core/crash/crash_log_repository.dart';

void main() {
  group('ErrorBoundary', () {
    testWidgets('build 中の例外を捕まえて復帰UIを出す', (tester) async {
      final previousBuilder = ErrorWidget.builder;

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            child: Builder(
              builder: (_) => throw StateError('描画失敗'),
            ),
          ),
        ),
      );
      // 例外発生フレーム → 復帰UIへ切り替わるフレーム
      await tester.pump();
      await tester.pump();

      expect(find.byKey(ErrorBoundary.messageKey), findsOneWidget);
      expect(find.text('表示中に問題が発生しました'), findsOneWidget);
      expect(find.byKey(ErrorBoundary.retryButtonKey), findsOneWidget);

      // Flutter のテストハーネスが捕捉した例外はここで受け取る。
      expect(tester.takeException(), isA<StateError>());

      await tester.pumpWidget(const SizedBox.shrink());
      // dispose で元のビルダーへ戻っていること。
      expect(ErrorWidget.builder, previousBuilder);
    });

    testWidgets('再読み込みで child を作り直す', (tester) async {
      var builds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            child: Builder(
              builder: (_) {
                builds++;
                if (builds == 1) throw StateError('一度だけ失敗');
                return const Text('復帰しました');
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isA<StateError>());
      expect(find.byKey(ErrorBoundary.retryButtonKey), findsOneWidget);

      await tester.tap(find.byKey(ErrorBoundary.retryButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('復帰しました'), findsOneWidget);
      expect(find.byKey(ErrorBoundary.retryButtonKey), findsNothing);
      expect(builds, greaterThan(1));
    });

    testWidgets('例外が無ければ child をそのまま表示する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(child: const Text('平常運転')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('平常運転'), findsOneWidget);
      expect(find.byKey(ErrorBoundary.messageKey), findsNothing);
    });

    testWidgets('onError で例外を通知する', (tester) async {
      Object? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            onError: (error, _) => captured = error,
            child: Builder(builder: (_) => throw ArgumentError('通知対象')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      tester.takeException();
      expect(captured, isA<ArgumentError>());
    });
  });

  group('CrashLogScreen', () {
    testWidgets('記録が無ければ空状態を出す', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CrashLogScreen(repository: InMemoryCrashLogRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(CrashLogScreen.emptyKey), findsOneWidget);
      expect(find.text('記録された不具合はありません'), findsOneWidget);
    });

    testWidgets('サマリーと一覧を表示し、コピーできる', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final repo = InMemoryCrashLogRepository([
        CrashLogEntry(
          timestamp: DateTime.utc(2026, 11, 1, 9, 5),
          kind: CrashKind.flutterError,
          message: '一件目',
          stackTop: '',
        ),
        CrashLogEntry(
          timestamp: DateTime.utc(2026, 11, 1, 9, 31),
          kind: CrashKind.zoneError,
          message: '二件目',
          stackTop: '',
        ),
      ]);

      await tester
          .pumpWidget(MaterialApp(home: CrashLogScreen(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.byKey(CrashLogScreen.summaryKey), findsOneWidget);
      expect(find.text('前回の異常終了 2件（最終 09:31）'), findsOneWidget);
      expect(find.byKey(CrashLogScreen.listKey), findsOneWidget);
      expect(find.text('二件目'), findsOneWidget);

      await tester.tap(find.byKey(CrashLogScreen.copyButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('クリップボードへコピーしました'), findsOneWidget);
      expect(copied, isNotNull);
      expect(copied, contains('前回の異常終了 2件（最終 09:31）'));
      expect(copied, contains('二件目'));
    });
  });
}
