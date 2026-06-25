import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/trial_quest/presentation/screens/reflection_screen.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/advisor.dart';

/// テスト用の TrialQuest ヘルパー
TrialQuest _createQuest({
  String title = '試練のタイトル',
  String description = '試練の説明',
  int suggestedOffering = 500,
  Advisor advisor = Advisor.daikokuten,
}) {
  return TrialQuest(
    title: title,
    description: description,
    suggestedOffering: suggestedOffering,
    advisor: advisor,
  );
}

void main() {
  group('ReflectionScreen', () {
    testWidgets('1. AppBarに「振り返り」が表示される', (tester) async {
      final quest = _createQuest();

      await tester.pumpWidget(
        MaterialApp(home: ReflectionScreen(quest: quest)),
      );

      // AppBarのタイトルを確認
      expect(find.text('振り返り'), findsOneWidget);
    });

    testWidgets('2. テキスト入力フィールドが存在する', (tester) async {
      final quest = _createQuest();

      await tester.pumpWidget(
        MaterialApp(home: ReflectionScreen(quest: quest)),
      );

      // TextFormField が存在することを確認
      expect(find.byType(TextFormField), findsOneWidget);

      // labelText '振り返りを綴れ' が存在することを確認
      expect(find.text('振り返りを綴れ'), findsOneWidget);
    });

    testWidgets('3. 送信ボタンが存在する', (tester) async {
      final quest = _createQuest();

      await tester.pumpWidget(
        MaterialApp(home: ReflectionScreen(quest: quest)),
      );

      // ElevatedButton を確認
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('振り返りを提出する'), findsOneWidget);
    });

    testWidgets('4. レベルMAX文字で送信するとバリデーションエラーが表示される', (tester) async {
      final quest = _createQuest();

      await tester.pumpWidget(
        MaterialApp(home: ReflectionScreen(quest: quest)),
      );

      // 何も入力せずに送信ボタンをタップ
      await tester.tap(find.text('振り返りを提出する'));
      await tester.pumpAndSettle();

      // バリデーションエラーメッセージを確認
      expect(find.text('振り返りを入力せよ'), findsOneWidget);
    });

    testWidgets('5. テキスト入力後に送信すると画面がポップされる', (tester) async {
      String? result;
      final quest = _createQuest();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReflectionScreen(quest: quest),
                    ),
                  );
                },
                child: const Text('OpenReflection'),
              );
            },
          ),
        ),
      );

      // ナビゲーションボタンをタップして ReflectionScreen を開く
      await tester.tap(find.text('OpenReflection'));
      await tester.pumpAndSettle();

      // ReflectionScreen が表示されていることを確認
      expect(find.byType(ReflectionScreen), findsOneWidget);

      // テキストを入力
      const reflectionText = '友人との食事で奢った。最初は痛かったが、相手が喜ぶ姿を見て自分の心も軽くなった。';
      await tester.enterText(find.byType(TextFormField), reflectionText);

      // 送信ボタンをタップ
      await tester.tap(find.text('振り返りを提出する'));
      await tester.pumpAndSettle();

      // Navigator.pop でテキストが返されたことを確認
      expect(result, reflectionText);

      // ReflectionScreen がポップされて非表示になったことを確認
      expect(find.byType(ReflectionScreen), findsNothing);
    });
  });
}
