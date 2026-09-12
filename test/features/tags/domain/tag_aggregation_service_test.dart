import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/tags/domain/models/expense_tag.dart';
import 'package:kozuchi/features/tags/domain/models/tagged_transaction.dart';
import 'package:kozuchi/features/tags/domain/tag_aggregation_service.dart';

TransactionModel _tx({
  required int amount,
  required String purpose,
  String datetime = '2026-09-12T10:00:00',
  String category = '食費',
}) =>
    TransactionModel(
      amount: amount,
      purpose: purpose,
      category: category,
      datetime: datetime,
    );

String _key(TransactionModel t) => TaggedTransaction.keyOfTransaction(t);

void main() {
  const service = TagAggregationService();

  group('TagTotal', () {
    test('netTotal は 収入 - 支出', () {
      const total = TagTotal(
        tagId: 'a',
        count: 2,
        expenseTotal: 3000,
        incomeTotal: 5000,
      );
      expect(total.netTotal, 2000);
    });

    test('count 0 は isEmpty', () {
      const total = TagTotal(tagId: 'a');
      expect(total.isEmpty, isTrue);
    });
  });

  group('TagAggregationService.summarize', () {
    test('空入力は空結果', () {
      final result = service.summarize(transactions: const []);
      expect(result.totals, isEmpty);
      expect(result.untaggedCount, 0);
      expect(result.isEmpty, isTrue);
    });

    test('タグ無しの取引は untagged に集計される', () {
      final t1 = _tx(amount: -1000, purpose: 'ランチ');
      final t2 = _tx(amount: 5000, purpose: '給与', category: '収入');

      final result = service.summarize(transactions: [t1, t2]);

      expect(result.totals, isEmpty);
      expect(result.untaggedCount, 2);
      expect(result.untaggedExpenseTotal, 1000);
      expect(result.untaggedIncomeTotal, 5000);
      expect(result.isEmpty, isFalse);
    });

    test('単一タグの支出合計は絶対値で加算される', () {
      final t1 = _tx(amount: -1000, purpose: 'A');
      final t2 = _tx(amount: -2500, purpose: 'B');

      final result = service.summarize(
        transactions: [t1, t2],
        assignments: {
          _key(t1): const ['tagA'],
          _key(t2): const ['tagA'],
        },
      );

      final total = result.totalForTag('tagA')!;
      expect(total.count, 2);
      expect(total.expenseTotal, 3500);
      expect(total.incomeTotal, 0);
      expect(result.untaggedCount, 0);
    });

    test('複数タグが付いた取引は各タグに計上される', () {
      final t1 = _tx(amount: -900, purpose: 'A');

      final result = service.summarize(
        transactions: [t1],
        assignments: {
          _key(t1): const ['tagA', 'tagB'],
        },
      );

      expect(result.totalForTag('tagA')!.expenseTotal, 900);
      expect(result.totalForTag('tagB')!.expenseTotal, 900);
      expect(result.totalForTag('tagA')!.count, 1);
      expect(result.totalForTag('tagB')!.count, 1);
    });

    test('重複したタグIDは1回だけ計上する', () {
      final t1 = _tx(amount: -900, purpose: 'A');

      final result = service.summarize(
        transactions: [t1],
        assignments: {
          _key(t1): const ['tagA', 'tagA'],
        },
      );

      expect(result.totalForTag('tagA')!.count, 1);
      expect(result.totalForTag('tagA')!.expenseTotal, 900);
    });

    test('収入は incomeTotal に加算される', () {
      final t1 = _tx(amount: 3000, purpose: '臨時収入', category: '収入');

      final result = service.summarize(
        transactions: [t1],
        assignments: {
          _key(t1): const ['tagA'],
        },
      );

      final total = result.totalForTag('tagA')!;
      expect(total.incomeTotal, 3000);
      expect(total.expenseTotal, 0);
      expect(total.netTotal, 3000);
    });

    test('並び順は支出合計の降順 → タグID昇順', () {
      final t1 = _tx(amount: -500, purpose: 'A');
      final t2 = _tx(amount: -1500, purpose: 'B');
      final t3 = _tx(amount: -500, purpose: 'C');

      final result = service.summarize(
        transactions: [t1, t2, t3],
        assignments: {
          _key(t1): const ['tagB'],
          _key(t2): const ['tagC'],
          _key(t3): const ['tagA'],
        },
      );

      expect(result.totals.map((t) => t.tagId).toList(), ['tagC', 'tagA', 'tagB']);
    });

    test('タグ定義を渡すと実績ゼロのタグも 0 件で含まれる', () {
      final t1 = _tx(amount: -500, purpose: 'A');

      final result = service.summarize(
        transactions: [t1],
        assignments: {
          _key(t1): const ['tagA'],
        },
        tags: const [
          ExpenseTag(id: 'tagA', name: '旅行'),
          ExpenseTag(id: 'tagB', name: 'サブスク'),
        ],
      );

      expect(result.totalForTag('tagA')!.name, '旅行');
      expect(result.totalForTag('tagB')!.name, 'サブスク');
      expect(result.totalForTag('tagB')!.count, 0);
    });

    test('紐付けに現れる未知のタグIDも name 空で集計に含める', () {
      final t1 = _tx(amount: -500, purpose: 'A');

      final result = service.summarize(
        transactions: [t1],
        assignments: {
          _key(t1): const ['unknown'],
        },
      );

      expect(result.totalForTag('unknown')!.name, '');
      expect(result.totalForTag('unknown')!.expenseTotal, 500);
    });

    test('紐付けの無いキーは無視される', () {
      final t1 = _tx(amount: -500, purpose: 'A');

      final result = service.summarize(
        transactions: [t1],
        assignments: {
          'no-such-key': const ['tagA'],
        },
        tags: const [ExpenseTag(id: 'tagA', name: '旅行')],
      );

      expect(result.totalForTag('tagA')!.count, 0);
      expect(result.untaggedCount, 1);
    });

    test('空のタグIDはタグ無しとして扱う', () {
      final t1 = _tx(amount: -500, purpose: 'A');

      final result = service.summarize(
        transactions: [t1],
        assignments: {
          _key(t1): const [''],
        },
      );

      expect(result.totals, isEmpty);
      expect(result.untaggedCount, 1);
    });

    test('日時が不正でも例外を投げず集計する', () {
      final t1 = _tx(amount: -500, purpose: 'A', datetime: 'not-a-date');

      final result = service.summarize(
        transactions: [t1],
        assignments: {
          _key(t1): const ['tagA'],
        },
      );

      expect(result.totalForTag('tagA')!.expenseTotal, 500);
    });
  });

  group('TagAggregationService.filterByTag', () {
    test('指定タグの取引のみ返し、入力順を保持する', () {
      final t1 = _tx(amount: -100, purpose: 'A', datetime: '2026-09-01T00:00:00');
      final t2 = _tx(amount: -200, purpose: 'B', datetime: '2026-09-02T00:00:00');
      final t3 = _tx(amount: -300, purpose: 'C', datetime: '2026-09-03T00:00:00');

      final filtered = service.filterByTag(
        transactions: [t1, t2, t3],
        assignments: {
          _key(t1): const ['tagA'],
          _key(t2): const ['tagB'],
          _key(t3): const ['tagA', 'tagB'],
        },
        tagId: 'tagA',
      );

      expect(filtered.map((t) => t.purpose).toList(), ['A', 'C']);
    });

    test('tagId が null の場合はタグ無しのみ返す', () {
      final t1 = _tx(amount: -100, purpose: 'A');
      final t2 = _tx(amount: -200, purpose: 'B');

      final filtered = service.filterByTag(
        transactions: [t1, t2],
        assignments: {
          _key(t2): const ['tagA'],
        },
      );

      expect(filtered.map((t) => t.purpose).toList(), ['A']);
    });

    test('該当が無ければ空リスト', () {
      final t1 = _tx(amount: -100, purpose: 'A');

      final filtered = service.filterByTag(
        transactions: [t1],
        assignments: {
          _key(t1): const ['tagA'],
        },
        tagId: 'tagZ',
      );

      expect(filtered, isEmpty);
    });
  });
}
