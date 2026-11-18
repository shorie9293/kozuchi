import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';

/// 追記ガードの試練。
///
/// 「照合できた時だけ書く」契約を破損・正常・空・型不正の各入口で検める。
const String _key = 'kozuchi_local_transactions';

const TransactionModel _lunch = TransactionModel(
  amount: -500,
  purpose: 'ランチ',
  category: '食費',
  datetime: '2026-06-01T12:00:00',
);

const TransactionModel _salary = TransactionModel(
  amount: 3000,
  purpose: '給与',
  category: '収入',
  datetime: '2026-06-02T12:00:00',
);

const TransactionModel _book = TransactionModel(
  amount: -800,
  purpose: '書籍',
  category: '教養',
  datetime: '2026-06-03T12:00:00',
);

/// 正常1件の JSON に壊れた要素を継ぎ足した「破損」生文字列
String _brokenMixedRaw() {
  final healthy = jsonEncode([_lunch.toJson()]);
  // 末尾の `]` を「壊れ要素 + ]」に置き換える
  return '${healthy.substring(0, healthy.length - 1)},{"壊れた"}]';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalTransactionRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = const LocalTransactionRepository();
  });

  /// 退避キー（prefix 付き）の一覧
  Future<List<String>> backupKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getKeys()
        .where((k) => k.startsWith(LocalTransactionRepository.backupKeyPrefix))
        .toList();
  }

  group('破損データでは書かない', () {
    test('addTransactions は TransactionStorageCorruptException を投げる', () async {
      SharedPreferences.setMockInitialValues({_key: _brokenMixedRaw()});

      await expectLater(
        repository.addTransactions([_book]),
        throwsA(isA<TransactionStorageCorruptException>()),
      );
    });

    test('原本キーの生文字列は完全一致で不変', () async {
      final raw = _brokenMixedRaw();
      SharedPreferences.setMockInitialValues({_key: raw});

      await expectLater(
        repository.addTransactions([_book]),
        throwsA(isA<TransactionStorageCorruptException>()),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_key), raw);
      expect(prefs.getString(_key) == raw, isTrue);
    });

    test('退避キーへ原本が1件だけ入り、2回撃っても増えない（冪等）', () async {
      final raw = _brokenMixedRaw();
      SharedPreferences.setMockInitialValues({_key: raw});

      await expectLater(
        repository.addTransactions([_book]),
        throwsA(isA<TransactionStorageCorruptException>()),
      );
      final afterFirst = await backupKeys();
      expect(afterFirst, hasLength(1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(afterFirst.single), raw);

      await expectLater(
        repository.addTransactions([_book]),
        throwsA(isA<TransactionStorageCorruptException>()),
      );
      expect(await backupKeys(), hasLength(1));
    });

    test('要素の型不正でも throw し原本不変', () async {
      final raw = jsonEncode([
        {'amount': '円', 'purpose': '壊れ', 'category': '?', 'datetime': 'x'},
      ]);
      SharedPreferences.setMockInitialValues({_key: raw});

      await expectLater(
        repository.addTransactions([_book]),
        throwsA(isA<TransactionStorageCorruptException>()),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_key), raw);
    });
  });

  group('健全データでは従来通り追記する', () {
    test('正常時は既存2件＋新規1件＝3件が順序保持で保存される', () async {
      SharedPreferences.setMockInitialValues({
        _key: jsonEncode([_lunch.toJson(), _salary.toJson()]),
      });

      final returned = await repository.addTransactions([_book]);

      expect(returned.map((t) => t.purpose), ['ランチ', '給与', '書籍']);

      final prefs = await SharedPreferences.getInstance();
      final stored = jsonDecode(prefs.getString(_key)!) as List;
      expect(stored, hasLength(3));
      final purposes = stored
          .map((e) => (e as Map<String, dynamic>)['purpose'] as String)
          .toList();
      expect(purposes, ['ランチ', '給与', '書籍']);
    });

    test('キー不在（verified true）は新規1件を追記できる', () async {
      final returned = await repository.addTransactions([_book]);

      expect(returned, hasLength(1));
      expect(returned.single.purpose, '書籍');

      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString(_key)!), hasLength(1));
    });

    test('空配列は健全＝追記できる', () async {
      SharedPreferences.setMockInitialValues({_key: '[]'});

      final returned = await repository.addTransactions([_book]);

      expect(returned, hasLength(1));
      expect(returned.single.purpose, '書籍');
    });

    test('verified true の往復で JSON 内容が等価', () async {
      SharedPreferences.setMockInitialValues({
        _key: jsonEncode([_lunch.toJson()]),
      });

      await repository.addTransactions([_book]);

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key)!;
      final expected = jsonEncode([_lunch.toJson(), _book.toJson()]);

      expect(jsonEncode(jsonDecode(stored)), expected);
    });
  });

  group('archiveCorruptData', () {
    test('破損時は退避して true、原本は削除しない', () async {
      final raw = _brokenMixedRaw();
      SharedPreferences.setMockInitialValues({_key: raw});

      expect(await repository.archiveCorruptData(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_key), raw);
      final keys = await backupKeys();
      expect(keys, hasLength(1));
      expect(prefs.getString(keys.single), raw);
    });

    test('健全時・キー不在は false', () async {
      expect(await repository.archiveCorruptData(), isFalse);

      SharedPreferences.setMockInitialValues({
        _key: jsonEncode([_lunch.toJson()]),
      });
      expect(await repository.archiveCorruptData(), isFalse);
      expect(await backupKeys(), isEmpty);
    });
  });
}