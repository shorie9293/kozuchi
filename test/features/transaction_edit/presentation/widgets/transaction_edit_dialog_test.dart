import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_edit/presentation/transaction_edit_app_keys.dart';
import 'package:kozuchi/features/transaction_edit/presentation/widgets/transaction_edit_dialog.dart';

Future<void> _pumpDialog(
  WidgetTester tester, {
  required TransactionModel transaction,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => TransactionEditDialog.show(context, transaction: transaction),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

TransactionModel _tx({int amount = -500}) => TransactionModel(
      amount: amount,
      purpose: '昼食',
      category: '食費',
      datetime: '2026-10-05T12:00:00.000',
      receiptImagePath: '/r.jpg',
      id: 'entry-1',
    );

void main() {
  testWidgets('編集ダイアログは初期値を欄に反映する', (tester) async {
    await _pumpDialog(tester, transaction: _tx());
    expect(
      tester.widget<TextField>(find.byKey(TransactionEditAppKeys.amountField))
          .controller!
          .text,
      '500',
    );
    expect(
      tester.widget<TextField>(find.byKey(TransactionEditAppKeys.categoryField))
          .controller!
          .text,
      '食費',
    );
    expect(
      tester.widget<TextField>(find.byKey(TransactionEditAppKeys.noteField))
          .controller!
          .text,
      '昼食',
    );
    // 日付ラベル（用途欄と区別するため日付書式で照合）
    expect(find.text('2026/10/05'), findsOneWidget);
  });

  testWidgets('保存で編集後の取引を返す', (tester) async {
    TransactionModel? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await TransactionEditDialog.show(
                    context,
                    transaction: _tx(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(TransactionEditAppKeys.amountField), '1,200');
    await tester.enterText(find.byKey(TransactionEditAppKeys.categoryField), '交通費');
    await tester.enterText(find.byKey(TransactionEditAppKeys.noteField), '電車代');
    await tester.tap(find.byKey(TransactionEditAppKeys.saveButton));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.amount, -1200);
    expect(result!.category, '交通費');
    expect(result!.purpose, '電車代');
    expect(result!.id, 'entry-1');
    expect(result!.receiptImagePath, '/r.jpg');
  });

  testWidgets('不正金額ではエラー表示し、ダイアログは閉じない', (tester) async {
    TransactionModel? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await TransactionEditDialog.show(
                    context,
                    transaction: _tx(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(TransactionEditAppKeys.amountField), '0');
    await tester.enterText(find.byKey(TransactionEditAppKeys.categoryField), '');
    await tester.tap(find.byKey(TransactionEditAppKeys.saveButton));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('金額は1以上の数値・カテゴリは必須です'), findsOneWidget);
    expect(find.byKey(TransactionEditAppKeys.saveButton), findsOneWidget);
  });

  testWidgets('キャンセルは null を返す', (tester) async {
    TransactionModel? result = _tx();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await TransactionEditDialog.show(
                    context,
                    transaction: _tx(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(TransactionEditAppKeys.cancelButton));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('削除確認ダイアログは確定で true・取消で false を返す', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {},
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    // 取消
    var result = showTransactionDeleteConfirmDialog(context(tester), transaction: _tx());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TransactionEditAppKeys.deleteCancelButton));
    await tester.pumpAndSettle();
    expect(await result, isFalse);

    // 確定
    result = showTransactionDeleteConfirmDialog(context(tester), transaction: _tx());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TransactionEditAppKeys.deleteConfirmButton));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });
}

BuildContext context(WidgetTester tester) {
  final element = tester.element(find.byType(FilledButton).first);
  return element;
}
