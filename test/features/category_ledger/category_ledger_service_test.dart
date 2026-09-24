import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/category_ledger/domain/category_ledger.dart';
import 'package:kozuchi/features/category_ledger/domain/category_ledger_service.dart';
import 'package:kozuchi/features/category_ledger/domain/category_usage.dart';

ExpenseEntry _entry(String id, String category, int amount) {
  return ExpenseEntry(
    id: id,
    amount: amount,
    category: category,
    date: DateTime(2026, 9, 1),
  );
}

void main() {
  const service = CategoryLedgerService();

  group('normalize', () {
    test('全角スペース→半角・連続空白→単一・前後trim', () {
      expect(CategoryLedgerService.normalize('  食費　'), '食費');
      expect(CategoryLedgerService.normalize('食費　　娯楽'), '食費 娯楽');
      expect(CategoryLedgerService.normalize('  食   費 '), '食 費');
    });

    test('defaultNames は既定カテゴリと一致', () {
      expect(CategoryLedgerService.defaultNames.toList(), [
        '食費',
        '交通費',
        '娯楽',
        '住居費',
        '光熱費',
        '医療費',
        '教育費',
        '交際費',
        '衣服費',
        '通信費',
        '日用品',
        'その他',
      ]);
    });
  });

  group('validateNew / add', () {
    test('不変条件1: 空文字・空白のみ・超長は empty / tooLong', () {
      final ledger = CategoryLedger.defaults();
      expect(service.validateNew(ledger, ''), CategoryNameError.empty);
      expect(service.validateNew(ledger, '  '), CategoryNameError.empty);
      expect(
        service.validateNew(ledger, 'あ' * 13),
        CategoryNameError.tooLong,
      );
      expect(service.validateNew(ledger, 'あ' * 12), isNull);
      expect(() => service.add(ledger, ''), throwsArgumentError);
      expect(() => service.add(ledger, '   '), throwsArgumentError);
      expect(() => service.add(ledger, 'あ' * 13), throwsArgumentError);
    });

    test('不変条件2: 重複（前後空白・全角スペース違い）は duplicate', () {
      final ledger = CategoryLedger(['食費']);
      expect(
        service.validateNew(ledger, ' 食費 '),
        CategoryNameError.duplicate,
      );
      // 全角スペースは半角に正規化されるため「食 費」同士は重複
      final spaced = CategoryLedger(['食 費']);
      expect(
        service.validateNew(spaced, '食　費'),
        CategoryNameError.duplicate,
      );
      expect(() => service.add(ledger, '食費'), throwsArgumentError);
    });

    test('add は末尾に追加する', () {
      final ledger = CategoryLedger.defaults();
      final added = service.add(ledger, 'ペット費');
      expect(added.categories.last, 'ペット費');
      expect(added.length, 13);
      // 元の台帳は不変
      expect(ledger.length, 12);
    });
  });

  group('rename', () {
    test('不変条件3: 存在しない from は ArgumentError', () {
      final ledger = CategoryLedger.defaults();
      expect(
        () => service.rename(ledger, 'ペット費', '動物費'),
        throwsArgumentError,
      );
    });

    test('不変条件3: 同一名への rename は no-op', () {
      final ledger = CategoryLedger.defaults();
      final renamed = service.rename(ledger, '食費', '食費');
      expect(renamed, ledger);
      expect(renamed.categories, ledger.categories);
    });

    test('rename は順序を保持する', () {
      final ledger = CategoryLedger(['a', 'b', 'c']);
      final renamed = service.rename(ledger, 'b', 'x');
      expect(renamed.categories, ['a', 'x', 'c']);
    });

    test('rename 後の台帳で同一内容にならない（旧名は消える）', () {
      final ledger = CategoryLedger(['食費', '娯楽']);
      final renamed = service.rename(ledger, '食費', 'グルメ');
      expect(renamed.contains('食費'), isFalse);
      expect(renamed.contains('グルメ'), isTrue);
    });

    test('他カテゴリ名への rename は ArgumentError', () {
      final ledger = CategoryLedger(['食費', '娯楽']);
      expect(() => service.rename(ledger, '食費', '娯楽'), throwsArgumentError);
    });
  });

  group('remove', () {
    test('不変条件4: 最後の1件は削除できない', () {
      final ledger = CategoryLedger(['唯一']);
      expect(() => service.remove(ledger, '唯一'), throwsArgumentError);
    });

    test('存在しない名前は ArgumentError', () {
      final ledger = CategoryLedger.defaults();
      expect(() => service.remove(ledger, 'ペット費'), throwsArgumentError);
    });

    test('削除できる', () {
      final ledger = CategoryLedger(['a', 'b']);
      final removed = service.remove(ledger, 'a');
      expect(removed.categories, ['b']);
    });
  });

  group('reset / isDefault', () {
    test('不変条件5: reset で既定に戻る', () {
      final modified = service.add(CategoryLedger.defaults(), 'ペット費');
      final reset = service.reset();
      expect(reset.isDefault, isTrue);
      expect(reset, CategoryLedger.defaults());
      expect(modified.isDefault, isFalse);
    });
  });

  group('usage', () {
    test('不変条件6: 台帳順 → 孤立カテゴリ（amount降順→名前昇順）', () {
      final ledger = CategoryLedger(['a', 'b', 'c']);
      final entries = [
        _entry('1', 'z', 500),
        _entry('2', 'y', 800),
        _entry('3', 'z', 100),
        _entry('4', 'a', 300),
      ];
      final usages = service.usage(ledger, entries);
      expect(usages.map((u) => u.category).toList(), [
        'a', 'b', 'c', // 台帳順（実績0含む）
        'y', 'z', // 孤立: amount降順
      ]);
      expect(usages[0].inLedger, isTrue);
      expect(usages[0].count, 1);
      expect(usages[0].amount, 300);
      expect(usages[1].count, 0);
      expect(usages[1].amount, 0);
      expect(usages[3].inLedger, isFalse);
      expect(usages[3].amount, 800);
      expect(usages[4].amount, 600);
    });

    test('不変条件6: 空白カテゴリは除外（amount<=0 は ExpenseEntry の assert により生成不可・サービス側は防御的に除外）', () {
      final ledger = CategoryLedger(['a']);
      final entries = [
        _entry('1', 'a', 100),
        _entry('3', '  ', 200),
        _entry('4', '　', 300),
      ];
      final usages = service.usage(ledger, entries);
      expect(usages.length, 1);
      expect(usages.first.category, 'a');
      expect(usages.first.count, 1);
      expect(usages.first.amount, 100);
    });

    test('実績0の台帳カテゴリも含まれる', () {
      final ledger = CategoryLedger.defaults();
      final usages = service.usage(ledger, []);
      expect(usages.length, ledger.length);
      expect(usages.every((u) => u.inLedger && u.count == 0), isTrue);
    });
  });

  group('isInUse', () {
    test('amount>0 のエントリに現れるか', () {
      final entries = [_entry('1', '食費', 100)];
      expect(service.isInUse('食費', entries), isTrue);
      expect(service.isInUse('娯楽', entries), isFalse);
      // amount<=0 は無視（ExpenseEntry の assert により生成不可だが、
      // サービス側は防御的にフィルタしている）
      expect(
        service.isInUse('食費', const <ExpenseEntry>[]),
        isFalse,
      );
    });
  });

  group('emojiFor', () {
    test('既知カテゴリ', () {
      expect(service.emojiFor('食費'), '🍙');
      expect(service.emojiFor('娯楽'), '🎮');
      expect(service.emojiFor('交通費'), '🚃');
      expect(service.emojiFor('光熱費'), '💡');
      expect(service.emojiFor('交際費'), '🎁');
      expect(service.emojiFor('日用品'), '🧻');
      expect(service.emojiFor('その他'), '📦');
    });

    test('未知カテゴリは 📦・例外を投げない', () {
      expect(service.emojiFor('ペット費'), '📦');
      expect(service.emojiFor(''), '📦');
    });
  });

  group('CategoryUsage', () {
    test('等価性', () {
      const a = CategoryUsage(
        category: 'a',
        count: 1,
        amount: 100,
        inLedger: true,
      );
      const b = CategoryUsage(
        category: 'a',
        count: 1,
        amount: 100,
        inLedger: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}