import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/core/text/kana_fold.dart';
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
  group('foldKana', () {
    test('ひらがなをカタカナへ変換する', () {
      expect(foldKana('よみかた'), 'ヨミカタ');
      expect(foldKana('あいうえお'), 'アイウエオ');
      expect(foldKana('ゔ'), 'ヴ');
    });

    test('半角カナを全角カタカナへ変換する', () {
      expect(foldKana('ｱｲｳｴｵ'), 'アイウエオ');
      expect(foldKana('ﾄｳｷｮｳ'), 'トウキョウ');
      expect(foldKana('ｦｰｯ'), 'ヲーッ');
    });

    test('半角カナ＋濁点/半濁点を合成する', () {
      expect(foldKana('ｶﾞ'), 'ガ');
      expect(foldKana('ｷﾞｸﾞｼﾞｮｳ'), 'ギグジョウ');
      expect(foldKana('ﾊﾟﾝ'), 'パン');
      expect(foldKana('ｳﾞ'), 'ヴ');
      expect(foldKana('ﾜﾞ'), 'ヷ');
    });

    test('カタカナ・漢字・ASCIIは不変', () {
      expect(foldKana('ヨミカタ'), 'ヨミカタ');
      expect(foldKana('食費'), '食費');
      expect(foldKana('ABC-123 abc'), 'ABC-123 abc');
      expect(foldKana(''), '');
    });

    test('小書きのか・け（ゕ・ゖ）も変換する', () {
      expect(foldKana('ゕ'), 'ヵ');
      expect(foldKana('ゖ'), 'ヶ');
      expect(foldKana('ゕゖ'), 'ヵヶ');
    });

    test('冪等である（foldKana(foldKana(x)) == foldKana(x)）', () {
      const samples = [
        'よみかた',
        'ｶﾞｯｺｳ',
        'ﾊﾟﾝ と コーヒー',
        'ヨミカタ',
        'ABC１２３',
        'ゕゖゔ',
        '食費',
        '',
        'ﾞ',
        'ｦﾞ',
      ];
      for (final sample in samples) {
        final once = foldKana(sample);
        expect(foldKana(once), once, reason: 'not idempotent: $sample');
      }
    });
  });

  group('normalizeForSearch', () {
    test('既存 normalizeKeyword の結果にかな畳み込みを重ねる', () {
      expect(
        TransactionQueryService.normalizeKeyword('よみかた'),
        'よみかた',
      );
      expect(
        TransactionQueryService.normalizeForSearch('よみかた'),
        'ヨミカタ',
      );
      expect(
        TransactionQueryService.normalizeForSearch(' ＡＢＣ　ｶﾞ '),
        'abc ガ',
      );
    });
  });

  group('検索統合: かな表記ゆれ', () {
    test('カテゴリ「ヨミカタ」が「よみかた」でヒットする', () {
      final tx = _tx(category: 'ヨミカタ');
      final filter = const TransactionFilter(keyword: 'よみかた');
      expect(TransactionQueryService.matches(tx, filter), isTrue);
    });

    test('カテゴリ「ヨミカタ」が半角ｶﾅ「ﾖﾐｶﾀ」でヒットする', () {
      final tx = _tx(category: 'ヨミカタ');
      final filter = const TransactionFilter(keyword: 'ﾖﾐｶﾀ');
      expect(TransactionQueryService.matches(tx, filter), isTrue);
    });

    test('濁点付き半角カナ「ｺﾞﾊﾝ」が「ごはん」でヒットする', () {
      final tx = _tx(purpose: 'ごはん');
      final filter = const TransactionFilter(keyword: 'ｺﾞﾊﾝ');
      expect(TransactionQueryService.matches(tx, filter), isTrue);
    });

    test('既存の検索挙動は不変（ASCII大小・全角英数・部分一致）', () {
      final tx = _tx(purpose: 'Lunch', category: 'Food');
      expect(
        TransactionQueryService.matches(
          tx,
          const TransactionFilter(keyword: 'ＬＵＮＣＨ'),
        ),
        isTrue,
      );
      expect(
        TransactionQueryService.matches(
          tx,
          const TransactionFilter(keyword: 'zzz'),
        ),
        isFalse,
      );
      expect(
        TransactionQueryService.matches(
          _tx(category: '食費'),
          const TransactionFilter(keyword: '食'),
        ),
        isTrue,
      );
    });
  });
}
