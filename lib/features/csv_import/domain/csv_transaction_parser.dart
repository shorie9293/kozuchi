import 'package:kozuchi/domain/models/transaction_model.dart';

/// CSVパースエラー
class CsvParseException implements Exception {
  final String message;
  final int? line; // 1-based
  CsvParseException(this.message, {this.line});

  @override
  String toString() =>
      'CsvParseException: $message${line != null ? '（行 $line）' : ''}';
}

/// パース結果（成功した取引とスキップされたエラー）
class CsvParseResult {
  final List<TransactionModel> transactions;
  final List<CsvParseException> errors;
  const CsvParseResult({
    required this.transactions,
    required this.errors,
  });
}

/// 列レイアウト（ヘッダから検出した各カラムの位置）
class _ColumnLayout {
  final int? dateIndex;
  final int? descIndex;
  final int? incomeIndex;
  final int? expenseIndex;
  const _ColumnLayout({
    this.dateIndex,
    this.descIndex,
    this.incomeIndex,
    this.expenseIndex,
  });

  /// 入金/出金の2列モードか
  bool get isTwoColumn => incomeIndex != null || expenseIndex != null;
}

/// 銀行明細CSVパーサ
///
/// 典型的な銀行明細CSV（日付, 摘要, 金額）を [TransactionModel] へ変換する。
/// ヘッダ行を検出し、列の役割（日付・摘要・入金・出金）を自動判定する。
///
/// 対応フォーマット:
/// - ジェネリック: `date,description,amount`（負符号/▲で支出を表す）
/// - 日本の銀行明細: 入金/出金 列（出金は負の支出として扱う）
class CsvTransactionParser {
  const CsvTransactionParser();

  static final RegExp _dateJa = RegExp(r'^(\d{4})年(\d{1,2})月(\d{1,2})日');
  static final RegExp _dateCompact = RegExp(r'^(\d{4})(\d{2})(\d{2})$');
  static final RegExp _dateSeparated =
      RegExp(r'^(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})(?:[T ].*)?$');

  /// CSV文字列をパースする。
  ///
  /// 不正行はスキップされ、[CsvParseResult.errors] に収集される。
  CsvParseResult parse(String csv) {
    final rows = _splitCsv(csv);
    if (rows.isEmpty) {
      return const CsvParseResult(transactions: [], errors: []);
    }

    final transactions = <TransactionModel>[];
    final errors = <CsvParseException>[];

    // ヘッダ検出
    int startRow = 0;
    _ColumnLayout layout;
    if (_looksLikeHeader(rows.first)) {
      layout = _detectColumns(rows.first);
      startRow = 1;
    } else {
      layout = const _ColumnLayout();
    }

    for (var i = startRow; i < rows.length; i++) {
      final cells = rows[i];
      if (cells.isEmpty) continue;
      final trimmed = cells.map((c) => c.trim()).toList();
      if (trimmed.length == 1 && trimmed.first.isEmpty) continue;
      if (trimmed.first.startsWith('#')) continue;

      try {
        final txs = _parseRow(trimmed, layout, i + 1);
        transactions.addAll(txs);
      } on CsvParseException catch (e) {
        errors.add(e);
      }
    }

    return CsvParseResult(transactions: transactions, errors: errors);
  }

  /// ヘッダ行かどうかを判定する
  bool _looksLikeHeader(List<String> cells) {
    for (final cell in cells) {
      final c = cell.toLowerCase();
      if (c.contains('日付') ||
          c.contains('日時') ||
          c.contains('取引日') ||
          c.contains('年月日') ||
          c.contains('date') ||
          c.contains('金額') ||
          c.contains('amount') ||
          c.contains('入金') ||
          c.contains('出金') ||
          c.contains('預入') ||
          c.contains('支払') ||
          c.contains('摘要') ||
          c.contains('お名前') ||
          c.contains('残高') ||
          c.contains('desc') ||
          c.contains('明細')) {
        return true;
      }
    }
    return false;
  }

  /// ヘッダ行から列レイアウトを検出する
  _ColumnLayout _detectColumns(List<String> header) {
    int? dateIndex;
    int? descIndex;
    int? incomeIndex;
    int? expenseIndex;

    for (var i = 0; i < header.length; i++) {
      final c = header[i].toLowerCase();
      if (dateIndex == null &&
          (c.contains('日付') ||
              c.contains('日時') ||
              c.contains('取引日') ||
              c.contains('年月日') ||
              c.contains('date'))) {
        dateIndex = i;
      } else if (incomeIndex == null &&
          (c.contains('入金') || c.contains('預入') || c.contains('収入'))) {
        incomeIndex = i;
      } else if (expenseIndex == null &&
          (c.contains('出金') || c.contains('支払') || c.contains('払込'))) {
        expenseIndex = i;
      } else if (descIndex == null &&
          (c.contains('摘要') ||
              c.contains('内容') ||
              c.contains('お名前') ||
              c.contains('明細') ||
              c.contains('用途') ||
              c.contains('desc'))) {
        descIndex = i;
      }
    }

    return _ColumnLayout(
      dateIndex: dateIndex,
      descIndex: descIndex,
      incomeIndex: incomeIndex,
      expenseIndex: expenseIndex,
    );
  }

  /// 1行を取引リストへ変換する
  List<TransactionModel> _parseRow(
    List<String> cells,
    _ColumnLayout layout,
    int line,
  ) {
    // 2列モード（入金/出金）でパース
    if (layout.isTwoColumn) {
      return _parseTwoColumnRow(cells, layout, line);
    }
    final tx = _parseGenericRow(cells, line);
    return [tx];
  }

  /// 入金/出金2列モード
  List<TransactionModel> _parseTwoColumnRow(
    List<String> cells,
    _ColumnLayout layout,
    int line,
  ) {
    final date = _cell(cells, layout.dateIndex);
    final dt = _parseDate(date);
    if (dt == null) {
      throw CsvParseException('日付を解釈できません', line: line);
    }
    final desc = (_cell(cells, layout.descIndex) ?? '').trim();
    final purpose = desc.isEmpty ? '（摘要なし）' : desc;

    final incomeRaw = layout.incomeIndex != null
        ? _cell(cells, layout.incomeIndex) ?? ''
        : '';
    final expenseRaw = layout.expenseIndex != null
        ? _cell(cells, layout.expenseIndex) ?? ''
        : '';

    final results = <TransactionModel>[];

    if (incomeRaw.trim().isNotEmpty) {
      final amount = _parseAmount(incomeRaw);
      if (amount == null || amount == 0) {
        throw CsvParseException('入金額を解釈できません: $incomeRaw', line: line);
      }
      results.add(TransactionModel(
        amount: amount.abs(),
        purpose: purpose,
        category: '収入',
        datetime: _iso(dt),
      ));
    }

    if (expenseRaw.trim().isNotEmpty) {
      final amount = _parseAmount(expenseRaw);
      if (amount == null || amount == 0) {
        throw CsvParseException('出金額を解釈できません: $expenseRaw', line: line);
      }
      results.add(TransactionModel(
        amount: -amount.abs(),
        purpose: purpose,
        category: 'その他',
        datetime: _iso(dt),
      ));
    }

    if (results.isEmpty) {
      throw CsvParseException('入金・出金のいずれもありません', line: line);
    }
    return results;
  }

  /// ジェネリックモード（date, desc, amount の位置を推測）
  TransactionModel _parseGenericRow(List<String> cells, int line) {
    int? dateIndex;
    final textIndices = <int>[];
    final numericIndices = <int>[];

    for (var i = 0; i < cells.length; i++) {
      final cell = cells[i].trim();
      if (cell.isEmpty) continue;
      if (dateIndex == null && _parseDate(cell) != null) {
        dateIndex = i;
      } else if (_parseAmount(cell) != null) {
        numericIndices.add(i);
      } else {
        textIndices.add(i);
      }
    }

    if (dateIndex == null) {
      throw CsvParseException('日付を解釈できません', line: line);
    }
    final dt = _parseDate(cells[dateIndex])!;

    if (numericIndices.isEmpty) {
      throw CsvParseException('金額を解釈できません', line: line);
    }

    // 摘要: 日付・金額以外のテキストセルを連結
    final purposeCells = textIndices.map((i) => cells[i].trim()).where((c) => c.isNotEmpty).toList();
    final purpose = purposeCells.isNotEmpty ? purposeCells.join(' ') : '（摘要なし）';

    final rawAmount = cells[numericIndices.first].trim();
    final amount = _parseAmount(rawAmount);
    if (amount == null || amount == 0) {
      throw CsvParseException('金額を解釈できません: $rawAmount', line: line);
    }

    return TransactionModel(
      amount: amount,
      purpose: purpose,
      category: amount >= 0 ? '収入' : 'その他',
      datetime: _iso(dt),
    );
  }

  String? _cell(List<String> cells, int? index) {
    if (index == null || index < 0 || index >= cells.length) return null;
    return cells[index];
  }

  /// 日付文字列を DateTime へ変換する
  DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;

    final ja = _dateJa.firstMatch(s);
    if (ja != null) {
      return DateTime(int.parse(ja[1]!), int.parse(ja[2]!), int.parse(ja[3]!));
    }

    final compact = _dateCompact.firstMatch(s);
    if (compact != null) {
      final y = int.parse(compact[1]!);
      final m = int.parse(compact[2]!);
      final d = int.parse(compact[3]!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return DateTime(y, m, d);
      }
      return null;
    }

    final sep = _dateSeparated.firstMatch(s);
    if (sep != null) {
      final y = int.parse(sep[1]!);
      final m = int.parse(sep[2]!);
      final d = int.parse(sep[3]!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return DateTime(y, m, d);
      }
      return null;
    }

    return null;
  }

  /// 金額文字列を int へ変換する。
  ///
  /// 負符号・▲・△ は支出として負値になる。カンマ・円記号は除去する。
  int? _parseAmount(String? raw) {
    if (raw == null) return null;
    var s = raw
        .replaceAll(',', '')
        .replaceAll('¥', '')
        .replaceAll('￥', '')
        .replaceAll('円', '')
        .replaceAll('\\', '')
        .trim();
    if (s.isEmpty) return null;

    var negative = false;
    if (s.startsWith('▲') || s.startsWith('△')) {
      negative = true;
      s = s.substring(1).trim();
    }
    if (s.startsWith('-')) {
      negative = true;
      s = s.substring(1).trim();
    } else if (s.startsWith('+')) {
      s = s.substring(1).trim();
    }

    s = s.replaceAll(RegExp(r'[^0-9.]'), '');
    if (s.isEmpty) return null;

    final v = int.tryParse(s.replaceAll('.', ''));
    if (v == null) return null;
    return negative ? -v : v;
  }

  /// ISO 8601 形式（T12:00:00）へ変換
  String _iso(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-${day}T12:00:00';
  }

  /// CSV文字列を行×列の2次元リストへ分割する
  List<List<String>> _splitCsv(String input) {
    final rows = <List<String>>[];
    final current = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      if (c == '"') {
        if (inQuotes && i + 1 < input.length && input[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        current.add(buf.toString());
        buf.clear();
      } else if ((c == '\n' || c == '\r') && !inQuotes) {
        if (c == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
        current.add(buf.toString());
        buf.clear();
        rows.add(current.toList());
        current.clear();
      } else {
        buf.write(c);
      }
    }

    if (buf.isNotEmpty || current.isNotEmpty) {
      current.add(buf.toString());
      rows.add(current.toList());
    }

    return rows;
  }
}
