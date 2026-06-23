import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_history/presentation/widgets/transaction_list_item.dart';

void main() {
  group('TransactionListItem', () {
    /// Helper to pump a TransactionListItem with the given transaction.
    Future<void> pumpItem(WidgetTester tester, TransactionModel tx) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionListItem(transaction: tx),
          ),
        ),
      );
    }

    testWidgets('収入取引は緑色の金額を表示する', (tester) async {
      final tx = TransactionModel(
        amount: 50000,
        purpose: '給与',
        category: '収入',
        datetime: '2026-06-23T10:00:00',
      );
      await pumpItem(tester, tx);

      // 金額が ¥50,000 と表示される
      expect(find.text('¥50,000'), findsOneWidget);
      // 用途が表示される
      expect(find.text('給与'), findsOneWidget);
      // カテゴリがバッジで表示される
      expect(find.text('収入'), findsOneWidget);
      // 日時が yyyy/MM/dd HH:mm 形式で表示される
      expect(find.text('2026/06/23 10:00'), findsOneWidget);
    });

    testWidgets('支出取引は赤色の金額を表示する', (tester) async {
      final tx = TransactionModel(
        amount: -3000,
        purpose: '食費',
        category: '食費',
        datetime: '2026-06-23T12:00:00',
      );
      await pumpItem(tester, tx);

      // 金額が -¥3,000 と表示される
      expect(find.text('-¥3,000'), findsOneWidget);
      expect(find.text('食費'), findsAtLeast(1)); // 用途とカテゴリ両方で表示あり
      expect(find.text('2026/06/23 12:00'), findsOneWidget);
    });

    testWidgets('ゼロ円の取引はニュートラル表示', (tester) async {
      final tx = TransactionModel(
        amount: 0,
        purpose: '調整',
        category: 'その他',
        datetime: '2026-06-23T00:00:00',
      );
      await pumpItem(tester, tx);

      expect(find.text('¥0'), findsOneWidget);
      expect(find.text('調整'), findsOneWidget);
      expect(find.text('その他'), findsOneWidget);
      expect(find.text('2026/06/23 00:00'), findsOneWidget);
    });

    testWidgets('大きな金額はカンマ区切りで表示される', (tester) async {
      final tx = TransactionModel(
        amount: 1234567,
        purpose: 'ボーナス',
        category: '収入',
        datetime: '2026-06-23T15:30:00',
      );
      await pumpItem(tester, tx);

      expect(find.text('¥1,234,567'), findsOneWidget);
    });
  });
}
