import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/csv_import/domain/csv_transaction_parser.dart';

void main() {
  const parser = CsvTransactionParser();

  group('CsvTransactionParser', () {
    test('ジェネリック形式（date,description,amount）を正しくパースする', () {
      const csv = 'date,description,amount\n'
          '2026-06-01,Salary,+300000\n'
          '2026-06-02,Coffee,-450\n';
      final result = parser.parse(csv);

      expect(result.transactions, hasLength(2));
      expect(result.errors, isEmpty);

      final salary = result.transactions[0];
      expect(salary.amount, 300000);
      expect(salary.isIncome, isTrue);
      expect(salary.purpose, 'Salary');
      expect(salary.datetime, startsWith('2026-06-01'));

      final coffee = result.transactions[1];
      expect(coffee.amount, -450);
      expect(coffee.isIncome, isFalse);
      expect(coffee.purpose, 'Coffee');
      expect(coffee.datetime, startsWith('2026-06-02'));
    });

    test('日本の銀行明細形式（入金/出金列）を正しくパースする', () {
      const csv = '日付,摘要,入金,出金\n'
          '2026/06/01,給与,300000,\n'
          '2026/06/02,コンビニ,,450\n';
      final result = parser.parse(csv);

      expect(result.transactions, hasLength(2));
      expect(result.errors, isEmpty);

      final income = result.transactions[0];
      expect(income.amount, 300000);
      expect(income.isIncome, isTrue);
      expect(income.purpose, '給与');

      final expense = result.transactions[1];
      expect(expense.amount, -450);
      expect(expense.isIncome, isFalse);
      expect(expense.purpose, 'コンビニ');
    });

    test('入金/出金列で両方値がある場合は出金を優先しない（入出金を別々に扱う）', () {
      const csv = '日付,摘要,入金,出金\n'
          '2026/06/03,両建て,1000,200\n';
      // 両列が入る場合は各列にそれぞれ1取引を生成する
      final result = parser.parse(csv);

      expect(result.transactions, hasLength(2));
      expect(result.transactions[0].amount, 1000);
      expect(result.transactions[1].amount, -200);
    });

    test('金額のカンマ区切りと▲記号（負）を正しく扱う', () {
      // カンマ区切り金額は引用符で囲まれたCSVとして表現される
      const csv = '日付,摘要,入金,出金\n'
          '2026/06/04,家賃,,"▲85,000"\n'
          '2026/06/05,返金,"1,234",\n';
      final result = parser.parse(csv);

      expect(result.transactions[0].amount, -85000);
      expect(result.transactions[1].amount, 1234);
    });

    test('ヘッダなし・日付/摘要/金額の順でもパースできる', () {
      const csv = '2026-06-10,食料品,"-1,200"\n'
          '2026-06-11,受取,+500\n';
      final result = parser.parse(csv);

      expect(result.transactions, hasLength(2));
      expect(result.transactions[0].amount, -1200);
      expect(result.transactions[1].amount, 500);
    });

    test('複数の日付フォーマットを正しく解釈する', () {
      const csv = 'date,desc,amount\n'
          '2026/6/7,スラッシュ短縮,-100\n'
          '20260608,数字連結,+200\n'
          '2026年6月9日,和暦風,-300\n';
      final result = parser.parse(csv);

      expect(result.transactions, hasLength(3));
      expect(result.transactions[0].datetime, startsWith('2026-06-07'));
      expect(result.transactions[1].datetime, startsWith('2026-06-08'));
      expect(result.transactions[2].datetime, startsWith('2026-06-09'));
    });

    test('不正行はスキップされエラーとして収集される', () {
      const csv = 'date,desc,amount\n'
          '2026-06-01,有効,100\n'
          '不正な行\n'
          ',空白日付,-5\n';
      final result = parser.parse(csv);

      expect(result.transactions, hasLength(1));
      expect(result.transactions[0].amount, 100);
      expect(result.errors, isNotEmpty);
      // 各行エラーに欠落理由が含まれる
      expect(result.errors.any((e) => e.message.contains('日付')), isTrue);
    });

    test('空文字列は空結果を返す', () {
      final result = parser.parse('');
      expect(result.transactions, isEmpty);
      expect(result.errors, isEmpty);
    });

    test('空行・コメント行は無視される', () {
      const csv = 'date,desc,amount\n'
          '\n'
          '# これはコメント\n'
          '2026-06-01,購入,-10\n';
      final result = parser.parse(csv);

      expect(result.transactions, hasLength(1));
    });

    test('ヘッダの日付・金額キーワードを含む行はヘッダとして判定されスキップされる', () {
      const csv = '取引日,お名前,支払金額,預入金額,残高\n'
          '2026/06/01,スーパー,1500,,100000\n';
      final result = parser.parse(csv);

      // 支払金額=1500 → 支出
      expect(result.transactions, hasLength(1));
      expect(result.transactions[0].amount, -1500);
    });
  });
}
