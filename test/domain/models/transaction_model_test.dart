import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';

void main() {
  group('TransactionModel', () {
    test('全フィールドを指定して生成できる', () {
      final t = TransactionModel(
        amount: 1000,
        purpose: '給与',
        category: '収入',
        datetime: '2026-06-23T10:00:00',
      );
      expect(t.amount, 1000);
      expect(t.purpose, '給与');
      expect(t.category, '収入');
      expect(t.datetime, '2026-06-23T10:00:00');
    });

    test('正のamountは収入と判定される', () {
      final t = TransactionModel(
        amount: 5000,
        purpose: '給与',
        category: '収入',
        datetime: '2026-06-23T10:00:00',
      );
      expect(t.isIncome, isTrue);
    });

    test('負のamountは支出と判定される', () {
      final t = TransactionModel(
        amount: -3000,
        purpose: '食費',
        category: '食費',
        datetime: '2026-06-23T12:00:00',
      );
      expect(t.isIncome, isFalse);
    });

    test('0のamountは収入と判定される（境界値）', () {
      final t = TransactionModel(
        amount: 0,
        purpose: '調整',
        category: 'その他',
        datetime: '2026-06-23T00:00:00',
      );
      expect(t.isIncome, isTrue);
    });

    test('absAmountは絶対値を返す', () {
      final income = TransactionModel(
        amount: 5000,
        purpose: '給与',
        category: '収入',
        datetime: '2026-06-23T10:00:00',
      );
      final expense = TransactionModel(
        amount: -3000,
        purpose: '食費',
        category: '食費',
        datetime: '2026-06-23T12:00:00',
      );
      expect(income.absAmount, 5000);
      expect(expense.absAmount, 3000);
    });

    test('JSON変換の往復でデータが保持される', () {
      final original = TransactionModel(
        amount: -1500,
        purpose: '家賃',
        category: '住居費',
        datetime: '2026-06-01T09:00:00',
      );
      final json = original.toJson();
      final restored = TransactionModel.fromJson(json);
      expect(restored.amount, original.amount);
      expect(restored.purpose, original.purpose);
      expect(restored.category, original.category);
      expect(restored.datetime, original.datetime);
      expect(restored.isIncome, original.isIncome);
    });
  });
}
