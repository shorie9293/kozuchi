import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/help/domain/help_catalog.dart';
import 'package:kozuchi/features/help/presentation/help_app_keys.dart';
import 'package:kozuchi/features/help/presentation/help_screen.dart';
import 'package:kozuchi/features/tutorial/domain/kozuchi_tutorial_step.dart';

/// ヘルプ画面の試練（依存注入なし・カタログのみ）。
Future<void> _pump(WidgetTester tester, {HelpCatalog? catalog}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: HelpScreen(catalog: catalog)));
  await tester.pump();
}

void main() {
  group('HelpScreen - 表示', () {
    testWidgets('AppBar に「遊び方・ヘルプ」、全章の見出しを並べる', (tester) async {
      await _pump(tester);

      expect(find.text('遊び方・ヘルプ'), findsOneWidget);
      for (final step in KozuchiTutorialStep.values) {
        expect(find.text(step.label), findsOneWidget);
      }
    });

    testWidgets('章を開くとチュートリアル本文が読める', (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(HelpAppKeys.topicTile('welcome')));
      await tester.pumpAndSettle();

      expect(
        find.text(KozuchiTutorialStep.welcome.description),
        findsOneWidget,
      );
    });
  });

  group('HelpScreen - 検索', () {
    testWidgets('キーワードで章を絞り込む', (tester) async {
      await _pump(tester);

      await tester.enterText(find.byKey(HelpAppKeys.searchField), '支出');
      await tester.pump();

      expect(find.text('支出の理'), findsOneWidget);
      expect(find.text('打ち出の小槌へようこそ'), findsNothing);
      expect(find.text('悟りへの道'), findsNothing);
    });

    testWidgets('該当なしなら空メッセージを出す', (tester) async {
      await _pump(tester);

      await tester.enterText(
        find.byKey(HelpAppKeys.searchField),
        '存在しない語句xyz',
      );
      await tester.pump();

      expect(find.byKey(HelpAppKeys.emptyMessage), findsOneWidget);
      expect(find.text('該当する項目がありません'), findsOneWidget);
      expect(find.byKey(HelpAppKeys.list), findsNothing);
    });

    testWidgets('検索語を消すと全章に戻る', (tester) async {
      await _pump(tester);

      await tester.enterText(find.byKey(HelpAppKeys.searchField), '支出');
      await tester.pump();
      await tester.enterText(find.byKey(HelpAppKeys.searchField), '');
      await tester.pump();

      for (final step in KozuchiTutorialStep.values) {
        expect(find.text(step.label), findsOneWidget);
      }
    });
  });
}
