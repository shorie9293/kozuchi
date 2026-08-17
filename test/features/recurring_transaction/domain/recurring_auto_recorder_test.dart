import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/data/recurring_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_auto_recorder.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecurringAutoRecorder recorder;
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 6, 15, 9, 0, 0);
    recorder = RecurringAutoRecorder(clock: () => now);
  });

  RecurringTransaction monthly({
    String id = 'rent',
    int amount = -85000,
    int dayOfMonth = 5,
    DateTime? start,
  }) {
    return RecurringTransaction(
      id: id,
      purpose: '家賃',
      category: '住居費',
      amount: amount,
      frequency: RecurringFrequency.monthly,
      dayOfMonth: dayOfMonth,
      startDate: start ?? DateTime(2026, 1, 5),
    );
  }

  group('RecurringAutoRecorder', () {
    test('startDateからnowまでの発生分を自動記録する', () async {
      final defRepo = const RecurringTransactionRepository();
      await defRepo.addDefinition(monthly()); // 毎月5日, start 1/5

      final result = await recorder.run();

      // 1/5,2/5,3/5,4/5,5/5,6/5 の6件
      expect(result.generatedCount, 6);
      expect(result.transactions, hasLength(6));

      final local = await const LocalTransactionRepository().loadAll();
      expect(local, hasLength(6));
      expect(local[0].datetime, startsWith('2026-01-05'));
    });

    test('lastGenerated以降の発生分のみ記録し重複しない', () async {
      final defRepo = const RecurringTransactionRepository();
      await defRepo.addDefinition(monthly()); // start 1/5

      // 1回目: 1/5〜6/15 → 6件
      await recorder.run();
      // nowを翌月に進める
      now = DateTime(2026, 7, 15, 9, 0, 0);
      // 2回目: 6/15以降 → 7/5 のみ1件
      final result = await recorder.run();

      expect(result.generatedCount, 1);
      expect(result.transactions.single.datetime, startsWith('2026-07-05'));

      final local = await const LocalTransactionRepository().loadAll();
      // 6+1 = 7件で重複なし
      expect(local, hasLength(7));
      expect(local.where((t) => t.datetime.startsWith('2026-07-05')), hasLength(1));
    });

    test('非アクティブな定義は記録されない', () async {
      final defRepo = const RecurringTransactionRepository();
      await defRepo.addDefinition(monthly().copyWith(isActive: false));

      final result = await recorder.run();
      expect(result.generatedCount, 0);
      expect(await const LocalTransactionRepository().loadAll(), isEmpty);
    });

    test('定義が空なら何も生成しない', () async {
      final result = await recorder.run();
      expect(result.generatedCount, 0);
    });

    test('lastGenerated保存済みでも新規に追加された定義は自身のstartDateから始める', () async {
      final defRepo = const RecurringTransactionRepository();
      await defRepo.addDefinition(monthly()); // start 1/5, dayOfMonth 5
      await recorder.run(); // 6件, lastGenerated=6/15

      // 新規定義を追加（7月開始, 10日）
      await defRepo.addDefinition(
        monthly(id: 'new', amount: -20000, dayOfMonth: 10, start: DateTime(2026, 7, 10)),
      );

      now = DateTime(2026, 8, 1, 9, 0, 0);
      final result = await recorder.run();

      // 既存rent定義は 6/15 以降 → 7/5 の1件
      final rentDates = result.transactions
          .where((t) => t.amount == -85000)
          .map((t) => t.datetime)
          .toList();
      expect(rentDates, ['2026-07-05T12:00:00']);

      // 新規定義は自身のstartDate 7/10 から発生し、過去のlastGenerated(6/15)より前へ遡らない
      final newDates = result.transactions
          .where((t) => t.amount == -20000)
          .map((t) => t.datetime)
          .toList();
      expect(newDates, ['2026-07-10T12:00:00']);

      // 合計 2件（7/5 と 7/10）
      expect(result.generatedCount, 2);
      expect(result.transactions, hasLength(2));
    });

    test('週次定義の自動記録', () async {
      final defRepo = const RecurringTransactionRepository();
      await defRepo.addDefinition(
        RecurringTransaction(
          id: 'lesson',
          purpose: '英会話',
          category: '習い事',
          amount: -5000,
          frequency: RecurringFrequency.weekly,
          dayOfWeek: DateTime.monday,
          startDate: DateTime(2026, 6, 1), // 月曜
        ),
      );
      // now = 6/15(月曜)
      final result = await recorder.run();
      // 6/1, 6/8, 6/15 → 3件
      expect(result.generatedCount, 3);
      final dates = result.transactions.map((t) => t.datetime).toList();
      expect(dates, contains('2026-06-15T12:00:00'));
    });
  });
}
