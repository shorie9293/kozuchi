import 'package:kozuchi/domain/models/expense_entry.dart';

/// 端末が持つ支出明細からCSVを組み立てる純粋サービス。
///
/// 旧 [CsvExportService] は `localhost:8080` のAPIを叩くが、そのAPIは
/// 現行のアプリ構成には存在しない（取引履歴画面も旧APIからは離脱済み）。
/// よって画面から到達可能にするにあたり、既定の出力は「端末の支出明細」から
/// 生成する。日付の判定は日単位・両端を含み、並びは決定的（日付昇順→id昇順）。
class LocalCsvExportService {
  const LocalCsvExportService();

  /// CSVの列見出し。順序は保存形式の契約として固定する。
  static const List<String> headerColumns = ['date', 'category', 'amount', 'note'];

  /// ヘッダ行（カンマ区切り）。
  String get header => headerColumns.join(',');

  /// 期間内のエントリを抽出して決定的に並べる。
  ///
  /// - [startDate] / [endDate] が null の側は無制限（全日）。
  /// - 比較は日単位（時刻は無視）。両端を含む。
  /// - 入力リストは破壊しない。
  List<ExpenseEntry> selectEntries(
    List<ExpenseEntry> entries, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final startDay = startDate == null ? null : _dayOnly(startDate);
    final endDay = endDate == null ? null : _dayOnly(endDate);

    final selected = entries.where((entry) {
      final day = _dayOnly(entry.date);
      if (startDay != null && day.isBefore(startDay)) return false;
      if (endDay != null && day.isAfter(endDay)) return false;
      return true;
    }).toList();

    selected.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return a.id.compareTo(b.id);
    });
    return selected;
  }

  /// RFC4180風のCSV文字列を組み立てる。
  ///
  /// 改行は CRLF、最終行にも CRLF を付す。該当0件でもヘッダ行を返す
  /// （空文字列を返すと「失敗した」のか「0件だった」のか区別できない）。
  String buildCsv({
    required List<ExpenseEntry> entries,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final rows = selectEntries(
      entries,
      startDate: startDate,
      endDate: endDate,
    );

    final buffer = StringBuffer()
      ..write(header)
      ..write('\r\n');

    for (final entry in rows) {
      buffer
        ..write(_formatDate(entry.date))
        ..write(',')
        ..write(_escape(entry.category))
        ..write(',')
        ..write(entry.amount.toString())
        ..write(',')
        ..write(_escape(entry.note ?? ''))
        ..write('\r\n');
    }
    return buffer.toString();
  }

  /// 書き出しファイル名。時刻を引数で受ける（実時計を直読みしない）。
  String fileNameFor(DateTime now) {
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}${two(now.second)}';
    return 'kozuchi_export_$stamp.csv';
  }

  DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  /// カンマ・引用符・改行を含む値だけを引用符で包み、引用符は二重化する。
  String _escape(String value) {
    final needsQuote = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuote) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
