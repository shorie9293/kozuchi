import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/receipt_viewer/presentation/receipt_viewer_app_keys.dart';
import 'package:kozuchi/features/transaction_history/presentation/widgets/transaction_list_item.dart';
import 'package:kozuchi/features/transaction_history/presentation/widgets/transaction_list_widget.dart';

void main() {
  const baseTransaction = TransactionModel(
    amount: -500,
    purpose: 'コーヒー',
    category: '食費',
    datetime: '2026-09-18T10:00:00.000',
  );

  group('TransactionListItem レシートボタン', () {
    testWidgets('receiptImagePath ありでボタンが表示され、タップで呼ばれる', (tester) async {
      var tapped = 0;
      final transaction = TransactionModel(
        amount: -500,
        purpose: 'コーヒー',
        category: '食費',
        datetime: '2026-09-18T10:00:00.000',
        receiptImagePath: '/tmp/receipt.jpg',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                TransactionListItem(
                  transaction: transaction,
                  onReceiptTap: () => tapped++,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final expectedKey = ReceiptViewerAppKeys.receiptButtonFor(
        transaction.datetime,
        transaction.amount,
      );
      expect(find.byKey(expectedKey), findsOneWidget);

      await tester.tap(find.byKey(expectedKey));
      expect(tapped, 1);
    });

    testWidgets('receiptImagePath なしでは表示されない', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                TransactionListItem(transaction: baseTransaction),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.receipt_long_outlined),
        findsNothing,
      );
    });

    testWidgets('空白のみのパスでは表示されない', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                TransactionListItem(
                  transaction: TransactionModel(
                    amount: -500,
                    purpose: 'コーヒー',
                    category: '食費',
                    datetime: '2026-09-18T10:00:00.000',
                    receiptImagePath: '   ',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.receipt_long_outlined),
        findsNothing,
      );
    });
  });

  group('TransactionListWidget 伝播', () {
    testWidgets('onReceiptTap が TransactionListItem へ伝播する', (tester) async {
      TransactionModel? received;
      final transaction = TransactionModel(
        amount: -500,
        purpose: 'コーヒー',
        category: '食費',
        datetime: '2026-09-18T10:00:00.000',
        receiptImagePath: '/tmp/receipt.jpg',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionListWidget(
              transactions: [transaction],
              onReceiptTap: (t) => received = t,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final expectedKey = ReceiptViewerAppKeys.receiptButtonFor(
        transaction.datetime,
        transaction.amount,
      );
      await tester.tap(find.byKey(expectedKey));
      expect(received, same(transaction));
    });
  });
}
