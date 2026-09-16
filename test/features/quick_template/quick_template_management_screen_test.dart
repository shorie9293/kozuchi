import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/quick_template/data/quick_template_repository.dart';
import 'package:kozuchi/features/quick_template/domain/models/expense_template.dart';
import 'package:kozuchi/features/quick_template/presentation/quick_template_app_keys.dart';
import 'package:kozuchi/features/quick_template/presentation/screens/quick_template_management_screen.dart';

ExpenseTemplate _tpl(
  String id, {
  int amount = 100,
  required String purpose,
  String category = '食費',
  int useCount = 0,
}) {
  return ExpenseTemplate(
    id: id,
    amount: amount,
    purpose: purpose,
    category: category,
    useCount: useCount,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  List<ExpenseTemplate> initial = const [],
}) async {
  final repo = InMemoryQuickTemplateRepository();
  // 初期データを直接投入（saveTemplates は private 経由を避けるため save を使う）
  await repo.saveTemplates(initial);
  await tester.pumpWidget(
    MaterialApp(
      home: QuickTemplateManagementScreen(repository: repo),
    ),
  );
  await tester.pump();
}

void main() {
  group('QuickTemplateManagementScreen', () {
    testWidgets('一覧に使用回数・金額・カテゴリが表示される', (tester) async {
      await _pumpScreen(
        tester,
        initial: [
          _tpl('a', amount: 500, purpose: '昼食', category: '食費', useCount: 3),
        ],
      );
      expect(find.byKey(QuickTemplateAppKeys.managementScreen), findsOneWidget);
      expect(find.text('昼食'), findsOneWidget);
      expect(find.text('¥500・食費・使用 3回'), findsOneWidget);
    });

    testWidgets('使用回数順に並ぶ', (tester) async {
      await _pumpScreen(
        tester,
        initial: [
          _tpl('a', purpose: '昼食', useCount: 1),
          _tpl('b', purpose: 'コーヒー', useCount: 5),
        ],
      );
      final tileB = tester.getTopLeft(
        find.byKey(QuickTemplateAppKeys.listTile('b')),
      );
      final tileA = tester.getTopLeft(
        find.byKey(QuickTemplateAppKeys.listTile('a')),
      );
      expect(tileB.dy, lessThan(tileA.dy));
    });

    testWidgets('削除ボタンでテンプレートが消える', (tester) async {
      await _pumpScreen(
        tester,
        initial: [_tpl('a', purpose: '昼食')],
      );
      await tester.tap(find.byKey(QuickTemplateAppKeys.deleteButton('a')));
      await tester.pump();
      expect(find.text('テンプレートはまだありません'), findsOneWidget);
    });

    testWidgets('追加ダイアログで新規テンプレートを保存できる', (tester) async {
      await _pumpScreen(tester);
      await tester.tap(find.byKey(QuickTemplateAppKeys.addButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(QuickTemplateAppKeys.amountField),
        '500',
      );
      await tester.enterText(
        find.byKey(QuickTemplateAppKeys.purposeField),
        '昼食',
      );
      await tester.tap(find.text('食費'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(QuickTemplateAppKeys.saveButton));
      await tester.pumpAndSettle();

      expect(find.text('昼食'), findsOneWidget);
      expect(find.text('¥500・食費・使用 0回'), findsOneWidget);
    });
  });
}
