import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/csv_import/domain/csv_transaction_parser.dart';

/// CSVインポート結果
class CsvImportResult {
  final int importedCount;
  final int skippedCount;
  final List<String> errorMessages;
  final List<TransactionModel> transactions;
  const CsvImportResult({
    required this.importedCount,
    required this.skippedCount,
    required this.errorMessages,
    required this.transactions,
  });
}

/// CSVインポートサービス
///
/// CSV文字列を [CsvTransactionParser] でパースし、
/// 成功した取引を [LocalTransactionRepository] へ永続化する。
class CsvImportService {
  final CsvTransactionParser parser;
  final LocalTransactionRepository repository;

  const CsvImportService({
    this.parser = const CsvTransactionParser(),
    this.repository = const LocalTransactionRepository(),
  });

  /// CSV文字列をインポートする。
  ///
  /// 不正行はスキップされ、[CsvImportResult.skippedCount] と
  /// [CsvImportResult.errorMessages] に反映される。
  Future<CsvImportResult> importCsv(String csv) async {
    final result = parser.parse(csv);

    if (result.transactions.isNotEmpty) {
      await repository.addTransactions(result.transactions);
    }

    return CsvImportResult(
      importedCount: result.transactions.length,
      skippedCount: result.errors.length,
      errorMessages: result.errors.map((e) => e.toString()).toList(),
      transactions: result.transactions,
    );
  }
}
