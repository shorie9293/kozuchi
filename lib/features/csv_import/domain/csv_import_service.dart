import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/csv_import/domain/csv_transaction_parser.dart';
import 'package:kozuchi/features/csv_import/domain/transaction_import_deduplicator.dart';

/// CSVインポート結果
///
/// 既存の4フィールドは required のまま不変。重複スキップ対応で
/// [duplicateCount]・[canVerify]・[unverifiedCount] を任意項目として追加した。
class CsvImportResult {
  /// 書き込んだ（取り込んだ）件数
  final int importedCount;

  /// パース段階でスキップした行数
  final int skippedCount;

  /// スキップ理由・保存失敗などのメッセージ
  final List<String> errorMessages;

  /// 書き込んだ取引
  final List<TransactionModel> transactions;

  /// 重複として除外した件数（照合できた場合のみ意味を持つ）
  final int duplicateCount;

  /// 既存取引と照合できたか。false のとき重複判定は未実施。
  final bool canVerify;

  /// 照合できなかったまま取り込んだ件数（未照合取込をした場合のみ非null）
  final int? unverifiedCount;

  const CsvImportResult({
    required this.importedCount,
    required this.skippedCount,
    required this.errorMessages,
    required this.transactions,
    this.duplicateCount = 0,
    this.canVerify = true,
    this.unverifiedCount,
  });
}

/// 取込前の確認内容（書き込み前の突合結果）
class CsvImportPreview {
  /// 重複判定を含む取込計画
  final ImportPlan plan;

  /// パース段階のエラーメッセージ
  final List<String> errorMessages;

  const CsvImportPreview({
    required this.plan,
    required this.errorMessages,
  });

  /// パースでスキップされた行数
  int get skippedCount => errorMessages.length;
}

/// CSVインポートサービス
///
/// CSV文字列を [CsvTransactionParser] でパースし、
/// 成功した取引を [LocalTransactionRepository] へ永続化する。
/// 取込前の突合（[previewCsv]）と確定（[commitPreview]）を分離し、
/// 重複・未照合という「判断が必要な時」だけ画面側で確認を挟めるようにする。
class CsvImportService {
  final CsvTransactionParser parser;
  final LocalTransactionRepository repository;
  final TransactionImportDeduplicator deduplicator;

  const CsvImportService({
    this.parser = const CsvTransactionParser(),
    this.repository = const LocalTransactionRepository(),
    this.deduplicator = const TransactionImportDeduplicator(),
  });

  /// CSV文字列を突合し、取込計画を返す。**書き込みは一切しない。**
  ///
  /// 既存取引を読めなかった場合は canVerify: false の計画を返す
  /// （照合できていないことを呼び出し側が判別できるようにする）。
  Future<CsvImportPreview> previewCsv(String csv) async {
    final parsed = parser.parse(csv);

    // 既存取引の読込。例外時は「照合できなかった」として扱う
    var existing = const <TransactionModel>[];
    var verified = false;
    try {
      final outcome = await repository.loadAllForVerification();
      existing = outcome.transactions;
      verified = outcome.verified;
    } catch (_) {
      existing = const <TransactionModel>[];
      verified = false;
    }

    final plan = deduplicator.plan(
      incoming: parsed.transactions,
      existing: existing,
      canVerify: verified,
    );

    return CsvImportPreview(
      plan: plan,
      errorMessages: parsed.errors.map((e) => e.toString()).toList(),
    );
  }

  /// 突合済みの計画を確定し、取引を永続化する。
  ///
  /// - 照合できた場合: 既定では新規分のみ書き込む。
  ///   [includeDuplicates] が true なら重複も含めて全件書き込む。
  /// - 照合できなかった場合: [allowUnverified] が true になるまで**書き込まない**。
  ///   true なら全件を書き込む（重複は判定不能なので除外しない）。
  ///
  /// 例外は投げない。保存自体に失敗した場合は書き込み0件として
  /// [CsvImportResult.errorMessages] に1行追加して返す。
  Future<CsvImportResult> commitPreview(
    CsvImportPreview preview, {
    bool includeDuplicates = false,
    bool allowUnverified = false,
  }) async {
    final plan = preview.plan;
    final errorMessages = List<String>.of(preview.errorMessages);

    // 照合できていないのに明示許可がない → 黙って全件追記せず書き込みゼロ
    if (!plan.canVerify && !allowUnverified) {
      return CsvImportResult(
        importedCount: 0,
        skippedCount: errorMessages.length,
        errorMessages: errorMessages,
        transactions: const <TransactionModel>[],
        duplicateCount: 0,
        canVerify: false,
        unverifiedCount: 0,
      );
    }

    final List<TransactionModel> toWrite;
    if (!plan.canVerify) {
      // 未照合の明示取込: 重複判定ができないため全件書き込む
      toWrite = plan.incoming;
    } else {
      toWrite = includeDuplicates ? plan.incoming : plan.fresh;
    }

    final duplicateCount = plan.canVerify ? plan.duplicateCount : 0;

    if (toWrite.isNotEmpty) {
      try {
        await repository.addTransactions(toWrite);
      } catch (_) {
        // 保存失敗は例外を投げず、結果のメッセージとして返す
        return CsvImportResult(
          importedCount: 0,
          skippedCount: errorMessages.length + 1,
          errorMessages: <String>[
            ...errorMessages,
            '取引の保存に失敗しました',
          ],
          transactions: const <TransactionModel>[],
          duplicateCount: duplicateCount,
          canVerify: plan.canVerify,
          unverifiedCount: plan.canVerify ? null : plan.incoming.length,
        );
      }
    }

    return CsvImportResult(
      importedCount: toWrite.length,
      skippedCount: errorMessages.length,
      errorMessages: errorMessages,
      transactions: List<TransactionModel>.of(toWrite),
      duplicateCount: duplicateCount,
      canVerify: plan.canVerify,
      unverifiedCount: plan.canVerify ? null : plan.incoming.length,
    );
  }

  /// CSV文字列をインポートする。
  ///
  /// 不正行はスキップされ、[CsvImportResult.skippedCount] と
  /// [CsvImportResult.errorMessages] に反映される。
  /// 重複は既定でスキップする（明示的に含めたい場合は [commitPreview] を使う）。
  Future<CsvImportResult> importCsv(String csv) async {
    final preview = await previewCsv(csv);
    return commitPreview(preview, includeDuplicates: false);
  }
}
