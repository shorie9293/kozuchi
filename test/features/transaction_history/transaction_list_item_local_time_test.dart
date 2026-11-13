import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_history/presentation/widgets/transaction_list_item.dart';

/// 取引行の日時表示がローカル時刻で行われることの試練。
///
/// クラウド同期は Z 付き（UTC）の ISO 8601 を返すため、
/// `DateTime.parse` の戻り値をそのまま組むと JST 早朝の取引が
/// 「前日 23:xx」と表示される（ローカル暦の1日ズレ）。
void main() {
  Future<void> pumpItem(WidgetTester tester, String datetime) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionListItem(
            transaction: TransactionModel(
              amount: -500,
              purpose: '昼食',
              category: '食費',
              datetime: datetime,
              id: 't1',
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Z 付き日時はローカル時刻で表示される', (tester) async {
    // JST 2026-11-13 08:30 = UTC 2026-11-12T23:30Z
    final utcIso = DateTime.parse('2026-11-12T23:30:00.000Z').toIso8601String();
    await pumpItem(tester, utcIso);

    final local = DateTime.parse(utcIso).toLocal();
    final expected = '${local.year}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('Z 無し（既存ローカル保存）の表示は不変', (tester) async {
    await pumpItem(tester, '2026-06-22T14:30:00.000');
    expect(find.text('2026/06/22 14:30'), findsOneWidget);
  });

  testWidgets('壊れた日時文字列でも例外を出さず原文を表示する', (tester) async {
    await pumpItem(tester, 'broken-datetime');
    expect(tester.takeException(), isNull);
    expect(find.text('broken-datetime'), findsOneWidget);
  });
}
