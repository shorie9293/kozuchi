import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/csv_import/presentation/screens/csv_import_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const validCsv = 'date,desc,amount\n'
      '2026-06-01,給与,+300000\n'
      '2026-06-02,食費,-1200\n';

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Future<String?> Function() pickCsvContent,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CsvImportScreen(
          pickCsvContent: pickCsvContent,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CsvImportScreen', () {
    testWidgets('AppBarに「銀行明細の取り込み」が表示される', (tester) async {
      await pumpScreen(tester, pickCsvContent: () async => null);
      expect(find.text('銀行明細の取り込み'), findsOneWidget);
    });

    testWidgets('CSV選択ボタンが表示される', (tester) async {
      await pumpScreen(tester, pickCsvContent: () async => null);
      expect(find.text('CSVファイルを選択'), findsOneWidget);
    });

    testWidgets('CSV選択→パース→永続化→成功表示まで動作する', (tester) async {
      await pumpScreen(
        tester,
        pickCsvContent: () async => validCsv,
      );

      await tester.tap(find.text('CSVファイルを選択'));
      await tester.pumpAndSettle();

      // 成功表示
      expect(find.textContaining('2件'), findsWidgets);
      expect(find.textContaining('給与'), findsOneWidget);

      // 永続化確認
      final saved = await const LocalTransactionRepository().loadAll();
      expect(saved, hasLength(2));
      expect(saved[0].amount, 300000);
    });

    testWidgets('不正行がある場合はスキップ数が表示される', (tester) async {
      await pumpScreen(
        tester,
        pickCsvContent: () async =>
            'date,desc,amount\n2026-06-01,有効,100\n不正な行\n',
      );

      await tester.tap(find.text('CSVファイルを選択'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1件'), findsWidgets);
      expect(find.textContaining('スキップ'), findsOneWidget);
    });

    testWidgets('選択をキャンセルした場合は何も起きない', (tester) async {
      await pumpScreen(tester, pickCsvContent: () async => null);
      await tester.tap(find.text('CSVファイルを選択'));
      await tester.pumpAndSettle();

      final saved = await const LocalTransactionRepository().loadAll();
      expect(saved, isEmpty);
      expect(find.textContaining('取り込みました'), findsNothing);
    });
  });
}
