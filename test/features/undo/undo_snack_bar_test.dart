import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/undo/presentation/undo_snack_bar.dart';

/// Undo スナックバーの試練（表示・アクション・1回限りの発火）。
void main() {
  group('showUndoSnackBar', () {
    Future<void> pumpHost(
      WidgetTester tester, {
      required VoidCallback onUndo,
      String message = '取引を削除しました',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showUndoSnackBar(
                    context,
                    message: message,
                    onUndo: onUndo,
                  ),
                  child: const Text('発火'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('メッセージと「元に戻す」アクションが表示される', (tester) async {
      await pumpHost(tester, onUndo: () {});

      await tester.tap(find.text('発火'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('取引を削除しました'), findsOneWidget);
      expect(find.text('元に戻す'), findsOneWidget);
      expect(find.byKey(undoActionKey), findsOneWidget);
    });

    testWidgets('「元に戻す」タップで onUndo が1回だけ呼ばれる', (tester) async {
      var calls = 0;
      await pumpHost(tester, onUndo: () => calls++);

      await tester.tap(find.text('発火'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(undoActionKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(calls, 1);
    });

    testWidgets('duration は指定値（既定5秒）が SnackBar に渡る', (tester) async {
      await pumpHost(tester, onUndo: () {});

      await tester.tap(find.text('発火'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 5),
      );
    });

    testWidgets('duration を明示指定できる', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showUndoSnackBar(
                    context,
                    message: '取引を削除しました',
                    onUndo: () {},
                    duration: const Duration(seconds: 2),
                  ),
                  child: const Text('発火'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('発火'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 2),
      );
    });

    testWidgets('メッセージは呼び出し側の文言をそのまま表示する', (tester) async {
      await pumpHost(tester, onUndo: () {}, message: '削除しました（取消可能）');

      await tester.tap(find.text('発火'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('削除しました（取消可能）'), findsOneWidget);
    });
  });
}
