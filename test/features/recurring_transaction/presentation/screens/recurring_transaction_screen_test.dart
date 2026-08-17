import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/recurring_transaction/data/recurring_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';
import 'package:kozuchi/features/recurring_transaction/presentation/screens/recurring_transaction_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecurringTransactionRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = const RecurringTransactionRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: RecurringTransactionScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  group('RecurringTransactionScreen', () {
    testWidgets('AppBarに「定期取引」が表示される', (tester) async {
      await pumpScreen(tester);
      expect(find.text('定期取引'), findsOneWidget);
    });

    testWidgets('保存済みの定期取引が一覧表示される', (tester) async {
      await repository.addDefinition(
        RecurringTransaction(
          id: 'rent',
          purpose: '家賃',
          category: '住居費',
          amount: -85000,
          frequency: RecurringFrequency.monthly,
          dayOfMonth: 5,
          startDate: DateTime(2026, 1, 5),
        ),
      );
      await pumpScreen(tester);

      expect(find.text('家賃'), findsOneWidget);
      expect(find.textContaining('85,000'), findsOneWidget);
      expect(find.textContaining('毎月'), findsWidgets);
    });

    testWidgets('定期取引を追加すると一覧に反映され永続化される', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('定期取引を追加'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('recurringTx_purposeField')), '家賃');
      await tester.enterText(
          find.byKey(const Key('recurringTx_amountField')), '-85000');
      await tester.tap(find.byKey(const Key('recurringTx_saveButton')));
      await tester.pumpAndSettle();

      expect(find.text('家賃'), findsOneWidget);

      final defs = await repository.loadDefinitions();
      expect(defs, hasLength(1));
      expect(defs[0].purpose, '家賃');
      expect(defs[0].amount, -85000);
    });

    testWidgets('定期取引を削除できる', (tester) async {
      await repository.addDefinition(
        RecurringTransaction(
          id: 'rent',
          purpose: '家賃',
          category: '住居費',
          amount: -85000,
          frequency: RecurringFrequency.monthly,
          dayOfMonth: 5,
          startDate: DateTime(2026, 1, 5),
        ),
      );
      await pumpScreen(tester);
      expect(find.text('家賃'), findsOneWidget);

      await tester.tap(find.byKey(const Key('recurringTx_deleteButton_rent')));
      await tester.pumpAndSettle();

      expect(find.text('家賃'), findsNothing);
      expect(await repository.loadDefinitions(), isEmpty);
    });

    testWidgets('未登録時は空メッセージが表示される', (tester) async {
      await pumpScreen(tester);
      expect(find.text('定期取引はまだありません'), findsOneWidget);
    });
  });
}
