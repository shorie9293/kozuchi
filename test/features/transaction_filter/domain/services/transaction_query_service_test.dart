import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_filter/domain/services/transaction_query_service.dart';

TransactionModel _tx({
  int amount = -100,
  String purpose = 'ランチ',
  String category = '食費',
  String datetime = '2026-06-15T12:00:00',
}) {
  return TransactionModel(
    amount: amount,
    purpose: purpose,
    category: category,
    datetime: datetime,
  );
}

void main() {
  group('normalizeKeyword', () {
    test('lowercases ASCII', () {
      expect(TransactionQueryService.normalizeKeyword('ABC'), 'abc');
    });

    test('converts full-width alphanumerics to half-width', () {
      expect(TransactionQueryService.normalizeKeyword('ＡＢＣ１２３'), 'abc123');
    });

    test('converts full-width space to half-width', () {
      expect(TransactionQueryService.normalizeKeyword('ａ　ｂ'), 'a b');
    });

    test('trims and compresses whitespace', () {
      expect(TransactionQueryService.normalizeKeyword('  a   b  '), 'a b');
      expect(TransactionQueryService.normalizeKeyword('　ｘ　　ｙ　'), 'x y');
    });

    test('empty string stays empty', () {
      expect(TransactionQueryService.normalizeKeyword(''), '');
      expect(TransactionQueryService.normalizeKeyword('   '), '');
    });

    test('preserves Japanese characters', () {
      expect(TransactionQueryService.normalizeKeyword('食費'), '食費');
    });
  });

  group('TransactionFilter new fields', () {
    test('default filter has empty keyword and sets', () {
      const filter = TransactionFilter();
      expect(filter.keyword, '');
      expect(filter.categories, isEmpty);
      expect(filter.tagIds, isEmpty);
      expect(filter.hasKeyword, isFalse);
      expect(filter.isDefault, isTrue);
      expect(filter.activeFilterCount, 0);
    });

    test('old call sites still work (backward compatible const)', () {
      const filter = TransactionFilter(type: TransactionFilterType.expense);
      expect(filter.type, TransactionFilterType.expense);
      expect(filter.isDefault, isFalse);
    });

    test('copyWith sets new fields', () {
      const original = TransactionFilter();
      final modified = original.copyWith(
        keyword: '食費',
        categories: {'a', 'b'},
        tagIds: {'t1'},
      );
      expect(modified.keyword, '食費');
      expect(modified.categories, {'a', 'b'});
      expect(modified.tagIds, {'t1'});
    });

    test('copyWith preserves new fields when not specified', () {
      const original = TransactionFilter(keyword: '食費', categories: {'a'});
      final modified = original.copyWith(type: TransactionFilterType.income);
      expect(modified.keyword, '食費');
      expect(modified.categories, {'a'});
    });

    test('copyWith clearKeyword resets keyword', () {
      const original = TransactionFilter(keyword: '食費');
      final cleared = original.copyWith(clearKeyword: true);
      expect(cleared.keyword, '');
      expect(cleared.hasKeyword, isFalse);
    });

    test('copyWith clearKeyword ignores keyword argument', () {
      const original = TransactionFilter(keyword: '食費');
      final cleared = original.copyWith(keyword: 'x', clearKeyword: true);
      expect(cleared.keyword, '');
    });

    test('copyWith defensive-copies sets', () {
      final cats = {'a'};
      final tags = {'t'};
      final filter = const TransactionFilter().copyWith(categories: cats, tagIds: tags);
      cats.add('b');
      tags.add('t2');
      expect(filter.categories, {'a'});
      expect(filter.tagIds, {'t'});
    });

    test('equality is order-independent for sets', () {
      final a = const TransactionFilter().copyWith(categories: {'a', 'b'}, tagIds: {'t1', 't2'});
      final b = const TransactionFilter().copyWith(categories: {'b', 'a'}, tagIds: {'t2', 't1'});
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different keyword creates inequality', () {
      const a = TransactionFilter(keyword: 'a');
      const b = TransactionFilter(keyword: 'b');
      expect(a, isNot(equals(b)));
    });

    test('different categories create inequality', () {
      final a = const TransactionFilter().copyWith(categories: {'a'});
      final b = const TransactionFilter().copyWith(categories: {'b'});
      expect(a, isNot(equals(b)));
    });

    test('toJson omits empty new fields', () {
      final json = const TransactionFilter().toJson();
      expect(json.containsKey('keyword'), isFalse);
      expect(json.containsKey('categories'), isFalse);
      expect(json.containsKey('tagIds'), isFalse);
    });

    test('toJson includes non-empty new fields', () {
      final filter = const TransactionFilter().copyWith(
        keyword: '食費',
        categories: {'a', 'b'},
        tagIds: {'t1'},
      );
      final json = filter.toJson();
      expect(json['keyword'], '食費');
      expect(json['categories'], isA<List<String>>());
      expect((json['categories'] as List).toSet(), {'a', 'b'});
      expect((json['tagIds'] as List).toSet(), {'t1'});
    });

    test('fromJson roundtrip with new fields', () {
      final filter = const TransactionFilter().copyWith(
        keyword: '食費',
        categories: {'a', 'b'},
        tagIds: {'t1', 't2'},
      );
      final restored = TransactionFilter.fromJson(filter.toJson());
      expect(restored, equals(filter));
    });

    test('fromJson reads old JSON without new fields', () {
      final json = <String, dynamic>{'type': 'income', 'startDate': '2026-06-01'};
      final filter = TransactionFilter.fromJson(json);
      expect(filter.type, TransactionFilterType.income);
      expect(filter.keyword, '');
      expect(filter.categories, isEmpty);
      expect(filter.tagIds, isEmpty);
    });

    test('fromJson tolerates type mismatch for new fields', () {
      final json = <String, dynamic>{
        'keyword': 123,
        'categories': 'not-a-list',
        'tagIds': [1, 2, null, 'ok'],
      };
      final filter = TransactionFilter.fromJson(json);
      expect(filter.keyword, '');
      expect(filter.categories, isEmpty);
      expect(filter.tagIds, {'ok'});
    });

    test('hasKeyword is false for whitespace-only keyword', () {
      const filter = TransactionFilter(keyword: '   ');
      expect(filter.hasKeyword, isFalse);
      expect(filter.isDefault, isTrue);
    });

    test('activeFilterCount counts each condition', () {
      expect(
        const TransactionFilter(type: TransactionFilterType.income).activeFilterCount,
        1,
      );
      expect(
        TransactionFilter(startDate: DateTime(2026, 1, 1)).activeFilterCount,
        1,
      );
      expect(
        TransactionFilter(endDate: DateTime(2026, 1, 1)).activeFilterCount,
        1,
      );
      expect(const TransactionFilter(keyword: 'x').activeFilterCount, 1);
      expect(
        const TransactionFilter().copyWith(categories: {'a'}).activeFilterCount,
        1,
      );
      expect(const TransactionFilter().copyWith(tagIds: {'t'}).activeFilterCount, 1);
      expect(
        TransactionFilter(
          type: TransactionFilterType.expense,
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 31),
          keyword: 'x',
        ).activeFilterCount,
        4,
      );
      expect(
        const TransactionFilter().copyWith(
          categories: {'a'},
          tagIds: {'t'},
        ).activeFilterCount,
        2,
      );
    });

    test('isDefault false when any new field set', () {
      expect(const TransactionFilter(keyword: 'x').isDefault, isFalse);
      expect(
        const TransactionFilter().copyWith(categories: {'a'}).isDefault,
        isFalse,
      );
      expect(const TransactionFilter().copyWith(tagIds: {'t'}).isDefault, isFalse);
    });
  });

  group('TransactionQueryService.matches', () {
    test('type income matches only income', () {
      const filter = TransactionFilter(type: TransactionFilterType.income);
      expect(
        TransactionQueryService.matches(
          _tx(amount: 100),
          filter,
        ),
        isTrue,
      );
      expect(
        TransactionQueryService.matches(
          _tx(amount: -100),
          filter,
        ),
        isFalse,
      );
    });

    test('type expense matches only expense', () {
      const filter = TransactionFilter(type: TransactionFilterType.expense);
      expect(
        TransactionQueryService.matches(_tx(amount: -100), filter),
        isTrue,
      );
      expect(TransactionQueryService.matches(_tx(amount: 100), filter), isFalse);
    });

    test('type all matches everything (amount 0 is income)', () {
      const filter = TransactionFilter();
      expect(TransactionQueryService.matches(_tx(amount: 0), filter), isTrue);
    });

    test('date range is inclusive on both ends', () {
      final filter = TransactionFilter(
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
      );
      expect(
        TransactionQueryService.matches(
          _tx(datetime: '2026-06-01T00:00:00'),
          filter,
        ),
        isTrue,
      );
      expect(
        TransactionQueryService.matches(
          _tx(datetime: '2026-06-30T23:59:59'),
          filter,
        ),
        isTrue,
      );
      expect(
        TransactionQueryService.matches(
          _tx(datetime: '2026-05-31T23:59:59'),
          filter,
        ),
        isFalse,
      );
      expect(
        TransactionQueryService.matches(
          _tx(datetime: '2026-07-01T00:00:00'),
          filter,
        ),
        isFalse,
      );
    });

    test('invalid datetime excludes when date filter active', () {
      final filter = TransactionFilter(startDate: DateTime(2026, 6, 1));
      expect(
        TransactionQueryService.matches(_tx(datetime: 'not-a-date'), filter),
        isFalse,
      );
    });

    test('invalid datetime passes when no date filter', () {
      const filter = TransactionFilter();
      expect(
        TransactionQueryService.matches(_tx(datetime: 'not-a-date'), filter),
        isTrue,
      );
    });

    test('keyword matches purpose partially', () {
      const filter = TransactionFilter(keyword: 'ランチ');
      expect(TransactionQueryService.matches(_tx(purpose: '昼のランチ代'), filter), isTrue);
      expect(TransactionQueryService.matches(_tx(purpose: '夕食'), filter), isFalse);
    });

    test('keyword matches category partially', () {
      const filter = TransactionFilter(keyword: '食');
      expect(TransactionQueryService.matches(_tx(category: '食費'), filter), isTrue);
      expect(TransactionQueryService.matches(_tx(category: '交通費'), filter), isFalse);
    });

    test('keyword is normalized (full-width, case, whitespace)', () {
      const filter = TransactionFilter(keyword: 'ＣＡＦＥ　Ｌａｔｅ');
      expect(
        TransactionQueryService.matches(_tx(purpose: 'cafe late'), filter),
        isTrue,
      );
    });

    test('empty keyword matches everything', () {
      const filter = TransactionFilter(keyword: '');
      expect(TransactionQueryService.matches(_tx(purpose: ''), filter), isTrue);
    });

    test('categories filter matches membership', () {
      final filter = const TransactionFilter().copyWith(categories: {'食費', '雑費'});
      expect(TransactionQueryService.matches(_tx(category: '食費'), filter), isTrue);
      expect(TransactionQueryService.matches(_tx(category: '交通費'), filter), isFalse);
    });

    test('empty categories matches everything', () {
      const filter = TransactionFilter();
      expect(TransactionQueryService.matches(_tx(category: '交通費'), filter), isTrue);
    });

    test('tagIds match with OR semantics', () {
      final filter = TransactionFilter().copyWith(tagIds: {'t1', 't2'});
      final tx = _tx();
      final key = 'datetime|amount|purpose|category';
      final assignments = <String, List<String>>{};
      expect(
        TransactionQueryService.matches(
          tx,
          filter,
          tagAssignments: assignments,
        ),
        isFalse,
      );
      // 正しいキーで紐付け（keyOfTransaction 形式を直接構築）
      final realKey =
          '${tx.datetime}|${tx.amount}|${tx.purpose}|${tx.category}';
      assignments[realKey] = ['t9'];
      expect(
        TransactionQueryService.matches(tx, filter, tagAssignments: assignments),
        isFalse,
      );
      assignments[realKey] = ['t2'];
      expect(
        TransactionQueryService.matches(tx, filter, tagAssignments: assignments),
        isTrue,
      );
      expect(key, isNotEmpty); // shape sanity
    });

    test('empty tagIds matches everything without assignments', () {
      const filter = TransactionFilter();
      expect(
        TransactionQueryService.matches(_tx(), filter, tagAssignments: const {}),
        isTrue,
      );
    });

    test('compound AND: all conditions must hold', () {
      final filter = TransactionFilter(
        type: TransactionFilterType.expense,
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
        keyword: 'ランチ',
      );
      expect(
        TransactionQueryService.matches(
          _tx(amount: -500, purpose: '昼のランチ', datetime: '2026-06-10T12:00:00'),
          filter,
        ),
        isTrue,
      );
      // keyword mismatch
      expect(
        TransactionQueryService.matches(
          _tx(amount: -500, purpose: '電車賃', datetime: '2026-06-10T12:00:00'),
          filter,
        ),
        isFalse,
      );
      // type mismatch
      expect(
        TransactionQueryService.matches(
          _tx(amount: 500, purpose: '昼のランチ', datetime: '2026-06-10T12:00:00'),
          filter,
        ),
        isFalse,
      );
      // date mismatch
      expect(
        TransactionQueryService.matches(
          _tx(amount: -500, purpose: '昼のランチ', datetime: '2026-07-10T12:00:00'),
          filter,
        ),
        isFalse,
      );
    });
  });

  group('TransactionQueryService.apply', () {
    test('preserves input order', () {
      final txs = [
        _tx(purpose: 'b'),
        _tx(purpose: 'a'),
        _tx(purpose: 'c'),
      ];
      const filter = TransactionFilter();
      final result = TransactionQueryService.apply(
        transactions: txs,
        filter: filter,
      );
      expect(result.map((t) => t.purpose).toList(), ['b', 'a', 'c']);
    });

    test('is non-destructive', () {
      final txs = [_tx(purpose: 'ランチ'), _tx(purpose: '電車')];
      final filter = const TransactionFilter().copyWith(keyword: 'ランチ');
      TransactionQueryService.apply(transactions: txs, filter: filter);
      expect(txs.length, 2);
    });

    test('filters by combined conditions', () {
      final txs = [
        _tx(amount: -100, category: '食費'),
        _tx(amount: -200, category: '交通費'),
        _tx(amount: 300, category: '食費'),
      ];
      final filter = const TransactionFilter().copyWith(categories: {'食費'});
      final result = TransactionQueryService.apply(
        transactions: txs,
        filter: filter,
      );
      expect(result.length, 2);
      expect(result.every((t) => t.category == '食費'), isTrue);
    });

    test('empty input returns empty', () {
      final result = TransactionQueryService.apply(
        transactions: const [],
        filter: const TransactionFilter(),
      );
      expect(result, isEmpty);
    });
  });

  group('TransactionQueryService.query', () {
    test('aggregates income, expense and net', () {
      final txs = [
        _tx(amount: 1000, purpose: '給料'),
        _tx(amount: -300, purpose: 'ランチ'),
        _tx(amount: -200, purpose: '電車'),
        _tx(amount: 500, purpose: '副収入'),
      ];
      final result = TransactionQueryService.query(
        transactions: txs,
        filter: const TransactionFilter(),
      );
      expect(result.count, 4);
      expect(result.totalIncome, 1500);
      expect(result.totalExpense, 500);
      expect(result.net, 1000);
      expect(result.isEmpty, isFalse);
    });

    test('empty list returns zeros', () {
      final result = TransactionQueryService.query(
        transactions: const [],
        filter: const TransactionFilter(),
      );
      expect(result.count, 0);
      expect(result.totalIncome, 0);
      expect(result.totalExpense, 0);
      expect(result.net, 0);
      expect(result.isEmpty, isTrue);
    });

    test('no matches returns zeros with empty list', () {
      final result = TransactionQueryService.query(
        transactions: [_tx(purpose: 'ランチ')],
        filter: const TransactionFilter().copyWith(keyword: '存在しない'),
      );
      expect(result.count, 0);
      expect(result.net, 0);
    });

    test('zero amount counts as income', () {
      final result = TransactionQueryService.query(
        transactions: [_tx(amount: 0)],
        filter: const TransactionFilter(),
      );
      expect(result.totalIncome, 0);
      expect(result.totalExpense, 0);
      expect(result.count, 1);
    });

    test('result equality works', () {
      final tx = _tx(amount: -100);
      final a = TransactionQueryService.query(
        transactions: [tx],
        filter: const TransactionFilter(),
      );
      final b = TransactionQueryService.query(
        transactions: [tx],
        filter: const TransactionFilter(),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      final c = TransactionQueryService.query(
        transactions: [_tx(amount: -200)],
        filter: const TransactionFilter(),
      );
      expect(a, isNot(equals(c)));
    });

    test('transactions list is unmodifiable', () {
      final result = TransactionQueryService.query(
        transactions: [_tx()],
        filter: const TransactionFilter(),
      );
      expect(() => result.transactions.add(_tx()), throwsUnsupportedError);
    });
  });

  group('TransactionQueryService with TaggedTransaction', () {
    test('keyOfTransaction-based tag filtering', () {
      final tx = _tx(amount: -500, purpose: 'ランチ', category: '食費');
      final key = '${tx.datetime}|${tx.amount}|${tx.purpose}|${tx.category}';
      final filter = const TransactionFilter().copyWith(tagIds: {'tag-a'});
      expect(
        TransactionQueryService.matches(
          tx,
          filter,
          tagAssignments: {key: ['tag-a']},
        ),
        isTrue,
      );
      expect(
        TransactionQueryService.matches(
          tx,
          filter,
          tagAssignments: {key: ['tag-b']},
        ),
        isFalse,
      );
    });
  });
}