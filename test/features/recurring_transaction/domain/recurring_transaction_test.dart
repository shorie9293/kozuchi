import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

void main() {
  group('RecurringTransaction', () {
    test('toJson → fromJson 往復で同一の値が復元される', () {
      final recurring = RecurringTransaction(
        id: 'rent',
        purpose: '家賃',
        category: '住居費',
        amount: -85000,
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 5,
        startDate: DateTime(2026, 1, 5),
        isActive: true,
      );

      final restored = RecurringTransaction.fromJson(recurring.toJson());

      expect(restored.id, 'rent');
      expect(restored.purpose, '家賃');
      expect(restored.category, '住居費');
      expect(restored.amount, -85000);
      expect(restored.frequency, RecurringFrequency.monthly);
      expect(restored.dayOfMonth, 5);
      expect(restored.startDate, DateTime(2026, 1, 5));
      expect(restored.isActive, isTrue);
    });

    test('weeklyタイプとdailyタイプも往復可能', () {
      final weekly = RecurringTransaction(
        id: 'w',
        purpose: '英会話',
        category: '習い事',
        amount: -5000,
        frequency: RecurringFrequency.weekly,
        dayOfWeek: DateTime.monday,
        startDate: DateTime(2026, 1, 1),
      );
      final restored = RecurringTransaction.fromJson(weekly.toJson());
      expect(restored.frequency, RecurringFrequency.weekly);
      expect(restored.dayOfWeek, DateTime.monday);

      final daily = RecurringTransaction(
        id: 'd',
        purpose: 'お小遣い',
        category: '収入',
        amount: 500,
        frequency: RecurringFrequency.daily,
        startDate: DateTime(2026, 1, 1),
      );
      final restoredDaily = RecurringTransaction.fromJson(daily.toJson());
      expect(restoredDaily.frequency, RecurringFrequency.daily);
    });

    test('isActive のデフォルトは true である', () {
      final recurring = RecurringTransaction(
        id: 'x',
        purpose: 'p',
        category: 'c',
        amount: -1,
        frequency: RecurringFrequency.monthly,
        startDate: DateTime(2026, 1, 1),
      );
      expect(recurring.isActive, isTrue);
    });

    test('idが同一なら等価と判定される', () {
      final a = RecurringTransaction(
        id: 'a',
        purpose: 'p',
        category: 'c',
        amount: -1,
        frequency: RecurringFrequency.monthly,
        startDate: DateTime(2026, 1, 1),
      );
      final b = RecurringTransaction(
        id: 'a',
        purpose: '別の用途',
        category: '別カテゴリ',
        amount: -999,
        frequency: RecurringFrequency.daily,
        startDate: DateTime(2026, 2, 1),
      );
      expect(a == b, isTrue);
    });

    test('copyWith で項目を更新できる', () {
      final base = RecurringTransaction(
        id: 'r',
        purpose: 'p',
        category: 'c',
        amount: -100,
        frequency: RecurringFrequency.monthly,
        startDate: DateTime(2026, 1, 1),
      );
      final updated = base.copyWith(isActive: false, amount: -200);
      expect(updated.isActive, isFalse);
      expect(updated.amount, -200);
      expect(updated.id, 'r');
    });
  });
}
