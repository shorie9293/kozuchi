import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/format/money_format.dart';
import 'package:kozuchi/features/budget/domain/spending_pace.dart' as pace;
import 'package:kozuchi/features/goals/data/goal.dart';
import 'package:kozuchi/features/transaction_filter/presentation/widgets/transaction_query_summary_bar.dart';
import 'package:kozuchi/features/wallet/presentation/wallet_app_keys.dart' as wallet;
import 'package:kozuchi/features/weekly_quest/domain/weekly_quest_progress.dart';

/// 親探針: 金額整形の一元化が「本当に一元化されているか」を外から撃つ。
///
/// 子の試練は個々の関数の入出力しか見ないため、
/// 「同じ値が呼出経路によって違う文字列になる」という本件の病因そのものを
/// 検出できない。ここでは公開されている全経路を同じ入力で並べ、
/// 戻り文字列が完全一致することを不変条件として固定する。
void main() {
  final goal = Goal(
    id: 'g-1',
    userId: 'u-1',
    title: '試練用',
    targetAmount: 100000,
    currentAmount: 0,
    status: 'active',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  /// 正準・委譲スタブを含む「金額を文字列にする公開経路」の全て。
  final Map<String, String Function(int)> paths = <String, String Function(int)>{
    'money_format.formatYen': formatYen,
    'Goal.formatAmount': goal.formatAmount,
    'WeeklyQuestProgress.formatYen': WeeklyQuestProgress.formatYen,
    'TransactionQuerySummaryBar.formatYen':
        TransactionQuerySummaryBar.formatYen,
    'wallet.formatYen': wallet.formatYen,
  };

  group('同じ値は同じ文字列になる（一元化の不変条件）', () {
    for (final int value in <int>[19999, 10000, 0, -1500, 999]) {
      test('$value 円', () {
        final expected = formatYen(value);
        paths.forEach((String name, String Function(int) fn) {
          expect(
            fn(value),
            expected,
            reason: '$name が正準と違う文字列を返した（重複実装の残存）',
          );
        });
      });
    }
  });

  group('記号と符号の流儀', () {
    test('負値は -¥1,500（記号の後ろにマイナスを置かない）', () {
      expect(formatYen(-1500), '-¥1,500');
      paths.forEach((String name, String Function(int) fn) {
        for (final int v in <int>[-1, -999, -1500, -19999]) {
          expect(
            fn(v).contains('¥-'),
            isFalse,
            reason: '$name($v) が ¥- 形式を生成した',
          );
        }
      });
    });

    test('0 は ¥0（-¥0 を生成しない）', () {
      expect(formatYen(0), '¥0');
      expect(formatYenBare(0), '0');
      expect(formatYenSigned(0), '¥0');
      expect(formatYenCompact(0), '¥0');
    });

    test('符号明示は正値のみ + を付す', () {
      expect(formatYenSigned(1000), '+¥1,000');
      expect(formatYenSigned(-1000), '-¥1,000');
    });
  });

  group('万表記は切り捨て（四捨五入で過大に見せない）', () {
    test('19,999 は 1万（2.0万 ではない）', () {
      expect(formatYenCompact(19999), '1万');
      expect(formatYenCompact(19999), isNot(contains('2.0万')));
      expect(formatYenCompact(10000), '1万');
      expect(formatYenCompact(99999), '9万');
      expect(formatYenCompact(-19999), '-1万');
    });

    test('1万未満は通常表記へ委譲する', () {
      expect(formatYenCompact(9999), '¥9,999');
      expect(formatYenCompact(999), '¥999');
    });
  });

  group('他の整形関数と混線していない', () {
    test('記号なし経路は ¥ を含まない', () {
      for (final int v in <int>[0, 999, 19999, -1500]) {
        expect(pace.formatAmount(v).contains('¥'), isFalse);
      }
    });

    test('金額整形は例外を投げない（int 極値）', () {
      for (final int v in <int>[
        -9223372036854775808,
        9223372036854775807,
        -1,
        0,
      ]) {
        expect(() => formatYen(v), returnsNormally);
        expect(() => formatYenBare(v), returnsNormally);
        expect(() => formatYenSigned(v), returnsNormally);
        expect(() => formatYenCompact(v), returnsNormally);
        expect(() => pace.formatAmount(v), returnsNormally);
      }
    });
  });
}
