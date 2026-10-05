import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_edit/domain/services/transaction_edit_service.dart';

void main() {
  group('TransactionEditService.parseAmount', () {
    test('半角数字をそのままパースする', () {
      expect(TransactionEditService.parseAmount('500'), 500);
    });

    test('カンマ区切りを許容する', () {
      expect(TransactionEditService.parseAmount('1,200'), 1200);
    });

    test('全角数字を半角へ正規化してパースする', () {
      expect(TransactionEditService.parseAmount('１２３'), 123);
    });

    test('前後の空白を許容する', () {
      expect(TransactionEditService.parseAmount(' 800 '), 800);
    });

    test('0以下は不正（null）', () {
      expect(TransactionEditService.parseAmount('0'), isNull);
      expect(TransactionEditService.parseAmount('-100'), isNull);
    });

    test('空文字・非数は不正（null）', () {
      expect(TransactionEditService.parseAmount(''), isNull);
      expect(TransactionEditService.parseAmount('abc'), isNull);
      expect(TransactionEditService.parseAmount('１００円'), isNull);
    });
  });

  group('TransactionEditService.buildEdited', () {
    final original = TransactionModel(
      amount: -500,
      purpose: '昼食',
      category: '食費',
      datetime: '2026-10-05T12:00:00.000',
      receiptImagePath: '/receipt/a.jpg',
      id: 'entry-1',
    );

    test('金額・カテゴリ・日付・メモを差し替えた取引を返す', () {
      final edited = TransactionEditService.buildEdited(
        original: original,
        amountText: '1,000',
        category: '交通費',
        date: DateTime(2026, 10, 6, 9, 30),
        note: '電車代',
      );
      expect(edited, isNotNull);
      expect(edited!.amount, -1000); // 支出は負値を保持
      expect(edited.category, '交通費');
      expect(edited.purpose, '電車代');
      expect(edited.datetime, DateTime(2026, 10, 6, 9, 30).toIso8601String());
      // 編集対象外のフィールドは保持
      expect(edited.id, 'entry-1');
      expect(edited.receiptImagePath, '/receipt/a.jpg');
    });

    test('メモがカテゴリと同一なら用途はカテゴリに寄る', () {
      final edited = TransactionEditService.buildEdited(
        original: original,
        amountText: '500',
        category: '食費',
        date: DateTime(2026, 10, 5),
        note: '食費',
      );
      expect(edited!.purpose, '食費');
    });

    test('メモが空なら用途はカテゴリに寄る', () {
      final edited = TransactionEditService.buildEdited(
        original: original,
        amountText: '500',
        category: '食費',
        date: DateTime(2026, 10, 5),
        note: '',
      );
      expect(edited!.purpose, '食費');
    });

    test('収入の取引は金額を正値のまま保つ', () {
      final income = TransactionModel(
        amount: 3000,
        purpose: 'お小遣い',
        category: 'その他',
        datetime: '2026-10-05T10:00:00.000',
        id: 'entry-2',
      );
      final edited = TransactionEditService.buildEdited(
        original: income,
        amountText: '5000',
        category: 'その他',
        date: DateTime(2026, 10, 5),
        note: '',
      );
      expect(edited!.amount, 5000);
      expect(edited.isIncome, isTrue);
    });

    test('金額不正はnull（元の取引を壊さない）', () {
      final edited = TransactionEditService.buildEdited(
        original: original,
        amountText: '0',
        category: '食費',
        date: DateTime(2026, 10, 5),
        note: '',
      );
      expect(edited, isNull);
    });

    test('カテゴリ空はnull', () {
      final edited = TransactionEditService.buildEdited(
        original: original,
        amountText: '500',
        category: '  ',
        date: DateTime(2026, 10, 5),
        note: '',
      );
      expect(edited, isNull);
    });

    test('全角カテゴリ・全角メモを正規化する', () {
      final edited = TransactionEditService.buildEdited(
        original: original,
        amountText: '５００',
        category: '交通費',
        date: DateTime(2026, 10, 5),
        note: '定期券',
      );
      expect(edited!.amount, -500);
    });
  });
}
