import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/csv_export/data/csv_file_sharer.dart';
import 'package:kozuchi/features/csv_export/domain/csv_bytes.dart';
import 'package:kozuchi/features/csv_export/domain/local_csv_export_service.dart';

/// 共有された内容を記録するだけのフェイク（実ファイルI/Oを持たない）。
class _RecordingCsvFileSharer implements CsvFileSharer {
  String? lastCsv;
  String? lastFileName;

  @override
  Future<void> share({required String csv, required String fileName}) async {
    lastCsv = csv;
    lastFileName = fileName;
  }
}

ExpenseEntry _entry({
  required String id,
  required DateTime date,
  int amount = 1200,
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
  group('withUtf8Bom', () {
    test('先頭に U+FEFF を1つだけ付ける', () {
      expect(withUtf8Bom('日付,金額'), '\uFEFF日付,金額');
      expect(withUtf8Bom('日付,金額').length, '日付,金額'.length + 1);
    });
  });

  group('csvBytes', () {
    const csv = '日付,金額\n2026-11-01,1200';

    test('先頭3バイトが EF BB BF になる', () {
      final bytes = csvBytes(csv);
      expect(bytes.length, greaterThanOrEqualTo(3));
      expect(bytes.sublist(0, 3), <int>[0xEF, 0xBB, 0xBF]);
    });

    test('BOM以降は元の文字列のUTF-8と一致する', () {
      final bytes = csvBytes(csv);
      expect(utf8.decode(bytes.sublist(3)), csv);
    });

    test('日本語は3バイトで符号化される（codeUnits では壊れる）', () {
      final bytes = csvBytes('円');
      // BOM 3 + '円' 3
      expect(bytes.length, 6);
      expect(bytes.sublist(3), <int>[0xE5, 0x86, 0x86]);
      expect(utf8.decode(bytes.sublist(3)), '円');
    });

    test('BOMは先頭に1つだけ付く（バイト列で検証）', () {
      // 注: Dart の utf8.decode は先頭BOMを黙って落とすため、文字列ではなく
      // バイト列で BOM の個数を数える。
      final bytes = csvBytes('abc');
      expect(bytes.sublist(0, 3), <int>[0xEF, 0xBB, 0xBF]);
      expect(bytes.length, 6); // BOM 3 + 'abc' 3
      expect(bytes.sublist(3, 6), <int>[0x61, 0x62, 0x63]);
    });
  });

  group('純粋CSV生成関数はBOMを含まない（従来契約の固定）', () {
    const service = LocalCsvExportService();

    test('buildCsv の戻り値に U+FEFF が含まれない', () {
      final csv = service.buildCsv(
        entries: [
          _entry(id: 'a', date: DateTime(2026, 11, 1), category: '食費'),
        ],
      );
      expect(csv.contains('\uFEFF'), isFalse);
      expect(csv.startsWith('date,category,amount,note\r\n'), isTrue);
    });

    test('buildCsv は該当0件でもヘッダのみを返し BOM を含まない', () {
      final csv = service.buildCsv(entries: const []);
      expect(csv, 'date,category,amount,note\r\n');
      expect(csv.contains('\uFEFF'), isFalse);
    });
  });

  group('CsvFileSharer へ渡る csv は BOM を含まない（BOMは共有層の責務）', () {
    test('フェイクに渡った文字列はBOM無しで、名前も維持される', () async {
      final fake = _RecordingCsvFileSharer();
      const service = LocalCsvExportService();
      final csv = service.buildCsv(
        entries: [
          _entry(
            id: 'a',
            date: DateTime(2026, 11, 1),
            category: '食費',
            note: '円',
          ),
        ],
      );

      await fake.share(csv: csv, fileName: 'kozuchi_export_20261101_000000.csv');

      expect(fake.lastCsv, isNotNull);
      expect(fake.lastCsv!.contains('\uFEFF'), isFalse);
      expect(fake.lastCsv, csv);
      expect(fake.lastFileName, 'kozuchi_export_20261101_000000.csv');
    });
  });
}
