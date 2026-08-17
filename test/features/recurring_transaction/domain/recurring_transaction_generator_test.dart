import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction_generator.dart';

void main() {
  const generator = RecurringTransactionGenerator();

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

  group('RecurringTransactionGenerator', () {
    test('月次: startDate以降の発生分を生成する', () {
      final tx = monthly(start: DateTime(2026, 1, 5));
      final generated = generator.generateFor(tx, DateTime(2026, 4, 10));

      expect(generated, hasLength(4)); // 1月,2月,3月,4月
      expect(generated[0].datetime, startsWith('2026-01-05'));
      expect(generated[3].datetime, startsWith('2026-04-05'));
      expect(generated[0].amount, -85000);
      expect(generated[0].purpose, '家賃');
      expect(generated[0].category, '住居費');
    });

    test('月次: 月末をまたぐ指定日にend-of-month調整がされる', () {
      // 31日指定 → 4月(30日)は30日に調整される
      final tx = RecurringTransaction(
        id: 'lastday',
        purpose: 'p',
        category: 'c',
        amount: -1000,
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 31,
        startDate: DateTime(2026, 1, 31),
      );
      final generated = generator.generateFor(tx, DateTime(2026, 5, 1));

      expect(generated, hasLength(4));
      // 2月 → 28日, 4月 → 30日
      expect(generated[1].datetime, startsWith('2026-02-28'));
      expect(generated[3].datetime, startsWith('2026-04-30'));
    });

    test('週次: 指定曜日の発生分を生成する', () {
      final tx = RecurringTransaction(
        id: 'lesson',
        purpose: '英会話',
        category: '習い事',
        amount: -5000,
        frequency: RecurringFrequency.weekly,
        dayOfWeek: DateTime.monday,
        startDate: DateTime(2026, 6, 1), // 月曜
      );
      final generated = generator.generateFor(tx, DateTime(2026, 6, 21));

      // 6/1, 6/8, 6/15, 6/21(日) → 6/15まで。6/21は日曜で対象外
      final dates = generated.map((g) => g.datetime).toList();
      expect(dates, contains('2026-06-01T12:00:00'));
      expect(dates, contains('2026-06-08T12:00:00'));
      expect(dates, contains('2026-06-15T12:00:00'));
      expect(generated, hasLength(3));
    });

    test('日次: 毎日発生する', () {
      final tx = RecurringTransaction(
        id: 'daily',
        purpose: 'お小遣い',
        category: '収入',
        amount: 500,
        frequency: RecurringFrequency.daily,
        startDate: DateTime(2026, 6, 1),
      );
      final generated = generator.generateFor(tx, DateTime(2026, 6, 3));
      expect(generated, hasLength(3));
    });

    test('nowがstartDateより前なら何も生成しない', () {
      final tx = monthly(start: DateTime(2026, 6, 5));
      final generated = generator.generateFor(tx, DateTime(2026, 5, 1));
      expect(generated, isEmpty);
    });

    test('startDate当日がnow以降でもstartDate当日分は含む', () {
      final tx = monthly(start: DateTime(2026, 6, 5));
      final generated = generator.generateFor(tx, DateTime(2026, 6, 5));
      expect(generated, hasLength(1));
    });
  });
}
