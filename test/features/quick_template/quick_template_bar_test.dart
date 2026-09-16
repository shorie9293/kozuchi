import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/quick_template/domain/models/expense_template.dart';
import 'package:kozuchi/features/quick_template/domain/quick_template_service.dart';
import 'package:kozuchi/features/quick_template/presentation/quick_template_app_keys.dart';
import 'package:kozuchi/features/quick_template/presentation/widgets/quick_template_bar.dart';

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

Future<void> _pumpBar(
  WidgetTester tester, {
  required List<ExpenseTemplate> templates,
  ValueChanged<ExpenseTemplateDraft>? onSelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuickTemplateBar(
          templates: templates,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('QuickTemplateBar', () {
    testWidgets('テンプレートごとにチップが表示される（用途・金額併記）', (tester) async {
      await _pumpBar(
        tester,
        templates: [
          _tpl('a', amount: 500, purpose: '昼食'),
          _tpl('b', amount: 120, purpose: 'コーヒー'),
        ],
      );
      expect(find.text('昼食 ¥500'), findsOneWidget);
      expect(find.text('コーヒー ¥120'), findsOneWidget);
      expect(find.byKey(QuickTemplateAppKeys.manageButton), findsOneWidget);
    });

    testWidgets('使用回数順に並ぶ', (tester) async {
      await _pumpBar(
        tester,
        templates: [
          _tpl('a', amount: 500, purpose: '昼食', useCount: 1),
          _tpl('b', amount: 120, purpose: 'コーヒー', useCount: 5),
        ],
      );
      final chipB = tester.getTopLeft(
        find.byKey(QuickTemplateAppKeys.chip('b')),
      );
      final chipA = tester.getTopLeft(
        find.byKey(QuickTemplateAppKeys.chip('a')),
      );
      expect(chipB.dx, lessThan(chipA.dx));
    });

    testWidgets('タップで onSelected に draft が渡る', (tester) async {
      ExpenseTemplateDraft? received;
      await _pumpBar(
        tester,
        templates: [_tpl('a', amount: 500, purpose: '昼食')],
        onSelected: (draft) => received = draft,
      );
      await tester.tap(find.byKey(QuickTemplateAppKeys.chip('a')));
      await tester.pump();
      expect(received, isNotNull);
      expect(received!.amount, 500);
      expect(received!.purpose, '昼食');
      expect(received!.category, '食費');
    });

    testWidgets('空のときは空状態と＋ボタンを表示する', (tester) async {
      await _pumpBar(tester, templates: []);
      expect(find.text('よく使う支出のテンプレートはまだありません'), findsOneWidget);
      expect(find.byKey(QuickTemplateAppKeys.manageButton), findsOneWidget);
    });
  });
}
