import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/trial_quest/presentation/screens/offering_input_screen.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/advisor.dart';

void main() {
  group('OfferingInputScreen', () {
    final quest = TrialQuest(
      title: '誰かと食事を共にせよ',
      description: '友人や家族と食事をし、会計を済ませよ',
      suggestedOffering: 3000,
      advisor: Advisor.lifePlanner,
    );
    final player = PlayerModel(hp: 100000, exp: 30);

    testWidgets('支出入力画面が表示される（AppBarあり）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OfferingInputScreen(quest: quest, player: player),
        ),
      );

      expect(find.text('支出の記録'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('金額フィールドに初期値（suggestedOffering）が設定されている',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OfferingInputScreen(quest: quest, player: player),
        ),
      );

      final amountField = find.widgetWithText(TextFormField, '3000');
      expect(amountField, findsOneWidget);
    });

    testWidgets('用途とメモの入力フィールドが存在する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OfferingInputScreen(quest: quest, player: player),
        ),
      );

      expect(find.text('用途'), findsOneWidget);
      expect(find.text('一言メモ（任意）'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
    });

    testWidgets('金額がレベルMAXで送信するとバリデーションエラーが表示される',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OfferingInputScreen(quest: quest, player: player),
        ),
      );

      // 金額フィールドをクリア
      final amountField = find.widgetWithText(TextFormField, '3000');
      await tester.tap(amountField);
      await tester.pumpAndSettle();
      await tester.enterText(amountField, '');
      await tester.pumpAndSettle();

      // 送信ボタンまでスクロール
      final submitButton = find.text('支出を実行する');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();

      // 送信ボタンをタップ
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('金額を入力せよ'), findsOneWidget);
    });

    testWidgets('全フィールド入力後に送信すると画面がポップされる', (tester) async {
      OfferingResult? capturedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<OfferingResult>(
                  MaterialPageRoute(
                    builder: (_) =>
                        OfferingInputScreen(quest: quest, player: player),
                  ),
                );
                capturedResult = result;
              },
              child: const Text('開く'),
            ),
          ),
        ),
      );

      // 画面を開く
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();

      // OfferingInputScreen が表示されていることを確認
      expect(find.text('支出の記録'), findsOneWidget);

      // 金額フィールドに値を入力
      final amountField = find.widgetWithText(TextFormField, '3000');
      await tester.tap(amountField);
      await tester.pumpAndSettle();
      await tester.enterText(amountField, '5000');
      await tester.pumpAndSettle();

      // 用途フィールドに入力
      await tester.tap(find.byType(TextFormField).at(1));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(1),
        '友人との食事',
      );
      await tester.pumpAndSettle();

      // メモフィールドに入力
      await tester.tap(find.byType(TextFormField).at(2));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(2),
        '楽しいひとときだった',
      );
      await tester.pumpAndSettle();

      // 送信ボタンまでスクロールしてタップ
      final submitButton = find.text('支出を実行する');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // OfferingInputScreen がポップされた（画面が閉じた）ことを確認
      expect(find.text('支出の記録'), findsNothing);

      // OfferingResult が正しく返されたことを確認
      expect(capturedResult, isNotNull);
      expect(capturedResult!.amount, 5000);
      expect(capturedResult!.purpose, '友人との食事');
      expect(capturedResult!.note, '楽しいひとときだった');
      // HPが5000減っている
      expect(capturedResult!.updatedPlayer.hp, 95000);
    });
  });
}
