import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/quick_template/domain/models/expense_template.dart';

void main() {
  group('ExpenseTemplate', () {
    test('生成できる（正の金額・非空用途・非空カテゴリ）', () {
      final now = DateTime(2026, 9, 17);
      final t = ExpenseTemplate(
        id: 't1',
        amount: 500,
        purpose: '昼食',
        category: '食費',
        useCount: 3,
        lastUsedAt: now,
        createdAt: now,
      );
      expect(t.id, 't1');
      expect(t.amount, 500);
      expect(t.purpose, '昼食');
      expect(t.category, '食費');
      expect(t.useCount, 3);
      expect(t.lastUsedAt, now);
    });

    test('JSON往復で元に戻る', () {
      final t = ExpenseTemplate(
        id: 't1',
        amount: 800,
        purpose: 'コーヒー',
        category: '娯楽',
        useCount: 2,
        lastUsedAt: DateTime(2026, 9, 16, 10),
        createdAt: DateTime(2026, 9, 1),
      );
      final restored = ExpenseTemplate.fromJson(t.toJson());
      expect(restored, t);
    });

    test('lastUsedAt が null でもJSON往復できる', () {
      final t = ExpenseTemplate(
        id: 't1',
        amount: 300,
        purpose: '切符',
        category: '交通',
        useCount: 0,
        createdAt: DateTime(2026, 9, 1),
      );
      final restored = ExpenseTemplate.fromJson(t.toJson());
      expect(restored, t);
      expect(restored.lastUsedAt, isNull);
    });

    test('tryFromJson は破損データを null で読み飛ばす', () {
      final now = DateTime(2026, 9, 1);
      expect(
        ExpenseTemplate.tryFromJson({
          'id': 't1',
          'amount': 0, // 不正
          'purpose': 'x',
          'category': '食費',
          'useCount': 0,
          'createdAt': now.toIso8601String(),
        }),
        isNull,
      );
      expect(
        ExpenseTemplate.tryFromJson({
          'id': 't1',
          'amount': 100,
          'purpose': '', // 不正
          'category': '食費',
          'useCount': 0,
          'createdAt': now.toIso8601String(),
        }),
        isNull,
      );
      expect(
        ExpenseTemplate.tryFromJson({
          'id': 't1',
          'amount': 100,
          'purpose': 'x',
          'category': '', // 不正
          'useCount': 0,
          'createdAt': now.toIso8601String(),
        }),
        isNull,
      );
      expect(
        ExpenseTemplate.tryFromJson({
          'id': 't1',
          'amount': 100,
          'purpose': 'x',
          'category': '食費',
          'useCount': -1, // 不正
          'createdAt': now.toIso8601String(),
        }),
        isNull,
      );
      expect(
        ExpenseTemplate.tryFromJson({
          'id': 't1',
          'amount': 100,
          'purpose': 'x',
          'category': '食費',
          'useCount': 0,
          'createdAt': 'not-a-date', // 不正
        }),
        isNull,
      );
    });

    test('copyWith は一部フィールドのみ変更する', () {
      final t = ExpenseTemplate(
        id: 't1',
        amount: 500,
        purpose: '昼食',
        category: '食費',
        useCount: 0,
        createdAt: DateTime(2026, 9, 1),
      );
      final copied = t.copyWith(amount: 600, useCount: 1);
      expect(copied.amount, 600);
      expect(copied.useCount, 1);
      expect(copied.purpose, '昼食');
      expect(copied.category, '食費');
      expect(copied.createdAt, t.createdAt);
    });

    test('値等価（== / hashCode）', () {
      final a = ExpenseTemplate(
        id: 't1',
        amount: 500,
        purpose: '昼食',
        category: '食費',
        useCount: 0,
        createdAt: DateTime(2026, 9, 1),
      );
      final b = ExpenseTemplate(
        id: 't1',
        amount: 500,
        purpose: '昼食',
        category: '食費',
        useCount: 0,
        createdAt: DateTime(2026, 9, 1),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
