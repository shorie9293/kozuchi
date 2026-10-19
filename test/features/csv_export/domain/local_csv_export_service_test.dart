import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/csv_export/domain/local_csv_export_service.dart';

ExpenseEntry _entry({
  required String id,
  required DateTime date,
  int amount = 1000,
  String category = '食費',
  String? note,
}) {
  return ExpenseEntry(
    id: id,
    amount: amount,
    category: category,
    date: date,
    note: note,
  );
}

void main() {
  const service = LocalCsvExportService();

  group('header', () {
    test('列見出しは date,category,amount,note の順で固定される', () {
      expect(LocalCsvExportService.headerColumns,
          ['date', 'category', 'amount', 'note']);
      expect(service.header, 'date,category,amount,note');
    });
  });

  group('selectEntries', () {
    test('期間指定なしなら全件を返す', () {
      final entries = [
        _entry(id: 'a', date: DateTime(2026, 1, 1)),
        _entry(id: 'b', date: DateTime(2026, 2, 1)),
      ];
      expect(service.selectEntries(entries).length, 2);
    });

    test('開始日・終了日は両端を含み、時刻は無視して日単位で判定する', () {
      final entries = [
        _entry(id: 'before', date: DateTime(2026, 1, 4, 23, 59)),
        _entry(id: 'start', date: DateTime(2026, 1, 5, 23, 59)),
        _entry(id: 'end', date: DateTime(2026, 1, 10, 0, 1)),
        _entry(id: 'after', date: DateTime(2026, 1, 11, 0, 0)),
      ];

      final selected = service.selectEntries(
        entries,
        startDate: DateTime(2026, 1, 5),
        endDate: DateTime(2026, 1, 10),
      );

      expect(selected.map((e) => e.id), ['start', 'end']);
    });

    test('片側だけの指定は反対側を無制限にする', () {
      final entries = [
        _entry(id: 'a', date: DateTime(2025, 12, 31)),
        _entry(id: 'b', date: DateTime(2026, 3, 1)),
      ];

      expect(
        service
            .selectEntries(entries, startDate: DateTime(2026, 1, 1))
            .map((e) => e.id),
        ['b'],
      );
      expect(
        service
            .selectEntries(entries, endDate: DateTime(2025, 12, 31))
            .map((e) => e.id),
        ['a'],
      );
    });

    test('並びは日付昇順→同時刻は id 昇順の決定的順序', () {
      final entries = [
        _entry(id: 'z', date: DateTime(2026, 1, 2)),
        _entry(id: 'b', date: DateTime(2026, 1, 1)),
        _entry(id: 'a', date: DateTime(2026, 1, 1)),
      ];

      expect(
        service.selectEntries(entries).map((e) => e.id),
        ['a', 'b', 'z'],
      );
    });

    test('入力リストを破壊しない', () {
      final entries = [
        _entry(id: 'b', date: DateTime(2026, 1, 2)),
        _entry(id: 'a', date: DateTime(2026, 1, 1)),
      ];
      final originalOrder = entries.map((e) => e.id).toList();

      service.selectEntries(entries);

      expect(entries.map((e) => e.id), originalOrder);
    });
  });

  group('buildCsv', () {
    test('0件でもヘッダ行のみを返す（空文字列にしない）', () {
      expect(service.buildCsv(entries: const []), 'date,category,amount,note\r\n');
    });

    test('CRLF 区切りで最終行にも CRLF を付す', () {
      final csv = service.buildCsv(
        entries: [_entry(id: 'a', date: DateTime(2026, 1, 5), category: '食費')],
      );

      expect(csv, 'date,category,amount,note\r\n2026-01-05,食費,1000,\r\n');
      expect(csv.endsWith('\r\n'), isTrue);
      expect(csv.contains('\n') && !csv.contains('\r\n'), isFalse);
    });

    test('金額は桁区切りなしの整数、備考なしは空欄', () {
      final csv = service.buildCsv(
        entries: [
          _entry(id: 'a', date: DateTime(2026, 1, 5), amount: 1234567),
        ],
      );

      expect(csv, contains(',1234567,'));
      expect(csv, isNot(contains('1,234,567')));
      expect(csv.split('\r\n')[1].endsWith(','), isTrue);
    });

    test('カンマ・引用符・改行を含む値は引用符で包み引用符を二重化する', () {
      final csv = service.buildCsv(
        entries: [
          _entry(
            id: 'a',
            date: DateTime(2026, 1, 5),
            category: '食費,外食',
            note: 'メモ "引用" 付き\n二行目',
          ),
        ],
      );

      expect(csv, contains('"食費,外食"'));
      expect(csv, contains('"メモ ""引用"" 付き\n二行目"'));
    });

    test('期間指定は selectEntries と同じ意味論で行を絞る', () {
      final entries = [
        _entry(id: 'in', date: DateTime(2026, 1, 5)),
        _entry(id: 'out', date: DateTime(2026, 2, 5)),
      ];

      final csv = service.buildCsv(
        entries: entries,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      );

      expect(csv.split('\r\n').where((l) => l.isNotEmpty).length, 2);
      expect(csv, contains('2026-01-05'));
      expect(csv, isNot(contains('2026-02-05')));
    });
  });

  group('fileNameFor', () {
    test('YYYYMMDD_HHMMSS 形式の .csv を返す（時刻は引数由来）', () {
      expect(
        service.fileNameFor(DateTime(2026, 1, 5, 7, 8, 9)),
        'kozuchi_export_20260105_070809.csv',
      );
    });
  });
}
