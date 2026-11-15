import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/core/widgets/empty_state.dart';

void main() {
  group('EmptyStateSpec', () {
    test('title が空文字なら ArgumentError', () {
      expect(
        () => EmptyStateSpec(title: ''),
        throwsArgumentError,
      );
    });

    test('title が空白のみなら ArgumentError', () {
      expect(
        () => EmptyStateSpec(title: '   '),
        throwsArgumentError,
      );
    });

    test('actionLabel だけ指定すると ArgumentError', () {
      expect(
        () => EmptyStateSpec(title: 'まだありません', actionLabel: '追加する'),
        throwsArgumentError,
      );
    });

    test('onAction だけ指定すると ArgumentError', () {
      expect(
        () => EmptyStateSpec(title: 'まだありません', onAction: () {}),
        throwsArgumentError,
      );
    });

    test('actionLabel と onAction を両方指定すれば生成できる', () {
      final spec = EmptyStateSpec(
        title: 'まだありません',
        actionLabel: '追加する',
        onAction: () {},
      );

      expect(spec.hasAction, isTrue);
      expect(spec.description, isNull);
      expect(spec.hasDescription, isFalse);
    });

    test('説明も行動も省いた最小構成を許す', () {
      final spec = EmptyStateSpec(title: 'まだありません');

      expect(spec.hasAction, isFalse);
      expect(spec.hasDescription, isFalse);
    });
  });

  group('EmptyStateView', () {
    Future<void> pumpView(
      WidgetTester tester, {
      required EmptyStateSpec spec,
      IconData? icon,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateView(
              key: const ValueKey('empty_state_view_under_test'),
              spec: spec,
              icon: icon,
            ),
          ),
        ),
      );
    }

    testWidgets('見出しだけのとき見出しのみ描画する', (tester) async {
      await pumpView(tester, spec: EmptyStateSpec(title: '取引がありません'));

      expect(find.text('取引がありません'), findsOneWidget);
      expect(find.byKey(EmptyStateView.actionButtonKey), findsNothing);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('説明を渡すと説明文を描画する', (tester) async {
      await pumpView(
        tester,
        spec: EmptyStateSpec(
          title: '取引がありません',
          description: '記録すると、ここに一覧が表示されます。',
        ),
      );

      expect(find.text('取引がありません'), findsOneWidget);
      expect(find.text('記録すると、ここに一覧が表示されます。'), findsOneWidget);
    });

    testWidgets('説明が null なら説明文を描画しない', (tester) async {
      await pumpView(tester, spec: EmptyStateSpec(title: '取引がありません'));

      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('アイコンを渡すと描画し、null なら描画しない', (tester) async {
      await pumpView(
        tester,
        spec: EmptyStateSpec(title: 'まだありません'),
        icon: Icons.receipt_long_outlined,
      );
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);

      await pumpView(tester, spec: EmptyStateSpec(title: 'まだありません'));
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('行動ボタンを押すと onAction が一度呼ばれる', (tester) async {
      var calls = 0;
      await pumpView(
        tester,
        spec: EmptyStateSpec(
          title: '定期取引はまだありません',
          actionLabel: '定期取引を追加する',
          onAction: () => calls++,
        ),
      );

      final button = find.byKey(EmptyStateView.actionButtonKey);
      expect(button, findsOneWidget);
      expect(find.text('定期取引を追加する'), findsOneWidget);

      await tester.tap(button);
      await tester.pump();

      expect(calls, 1);
    });

    testWidgets('行動を省くとボタンを描画しない（描画だけの空状態）', (tester) async {
      await pumpView(
        tester,
        spec: EmptyStateSpec(title: '該当する取引がありません'),
      );

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byKey(EmptyStateView.actionButtonKey), findsNothing);
    });

    testWidgets('Key で一意に掴める', (tester) async {
      await pumpView(tester, spec: EmptyStateSpec(title: 'まだありません'));

      expect(
        find.byKey(const ValueKey('empty_state_view_under_test')),
        findsOneWidget,
      );
      expect(find.byType(EmptyStateView), findsOneWidget);
    });
  });
}
