import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/data/recurring_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction_generator.dart';

/// 定期取引の自動記録結果
class RecurringAutoRecordResult {
  final int generatedCount;
  final List<TransactionModel> transactions;

  /// 保存データが破損していて自動記帳を**見送った**か。
  ///
  /// 0件計上を「定期取引が無い」と混同しないためのフラグ。
  final bool storageUnverified;

  /// 見送り・失敗の理由（正常時は null）
  final String? errorMessage;

  const RecurringAutoRecordResult({
    required this.generatedCount,
    required this.transactions,
    this.storageUnverified = false,
    this.errorMessage,
  });
}

/// 定期取引の自動記録オーケストレータ
///
/// アプリ起動時などに呼び出され、各定期取引定義について
/// 前回生成日時（lastGenerated）以降に発生する取引を生成し、
/// ローカル取引リポジトリへ追記する。lastGenerated を進めることで
/// 同一取引の重複生成を防ぐ。
class RecurringAutoRecorder {
  final RecurringTransactionRepository recurringRepository;
  final LocalTransactionRepository transactionRepository;
  final RecurringTransactionGenerator generator;
  final DateTime Function() clock;

  const RecurringAutoRecorder({
    this.recurringRepository = const RecurringTransactionRepository(),
    this.transactionRepository = const LocalTransactionRepository(),
    this.generator = const RecurringTransactionGenerator(),
    DateTime Function()? clock,
  }) : clock = clock ?? _systemNow;

  static DateTime _systemNow() => DateTime.now();

  /// アプリ起動時の自動記録を実行する。
  ///
  /// 追記（addTransactions）に失敗した場合は例外をそのまま伝播させ、
  /// lastGenerated は前進させない。これにより次回起動時に同じ期間が
  /// 再生成され、取引が静かに欠落することがない。
  Future<RecurringAutoRecordResult> run() async {
    final now = clock();
    final defsResult = await recurringRepository.loadDefinitionsResult();
    // 破損した定義を根拠に取引を生まない（不信なデータで副作用を起こさない）
    if (!defsResult.verified) {
      return RecurringAutoRecordResult(
        generatedCount: 0,
        transactions: const [],
        storageUnverified: true,
        errorMessage: defsResult.errorMessage,
      );
    }
    final lastGeneratedResult =
        await recurringRepository.loadLastGeneratedResult();
    // 進捗が読めないと「全部が未生成」に見え、過去分を二重計上する
    if (!lastGeneratedResult.verified) {
      return RecurringAutoRecordResult(
        generatedCount: 0,
        transactions: const [],
        storageUnverified: true,
        errorMessage: lastGeneratedResult.errorMessage,
      );
    }
    final definitions = defsResult.definitions;
    final generated = <TransactionModel>[];
    // 追記が成功した後でまとめて前進させる定義ID
    final advancedIds = <String>[];

    for (final def in definitions) {
      if (!def.isActive) continue;

      final lastGenerated = lastGeneratedResult.valueFor(def.id);
      final due = generator.generateFor(def, now);

      final List<TransactionModel> newOnes;
      if (lastGenerated != null) {
        final lastDay = DateTime(
            lastGenerated.year, lastGenerated.month, lastGenerated.day);
        // 前回生成日時より後（厳密に）の発生分のみ
        newOnes =
            due.where((t) => _isStrictlyAfter(t.datetime, lastDay)).toList();
      } else {
        // lastGenerated 未設定なら startDate 以降すべて
        newOnes = due;
      }

      generated.addAll(newOnes);
      advancedIds.add(def.id);
    }

    if (generated.isNotEmpty) {
      await transactionRepository.addTransactions(generated);
    }

    // 追記成功後にのみ前進させる（0件でも前進させ、無駄な再走査を防ぐ）
    for (final id in advancedIds) {
      await recurringRepository.saveLastGenerated(id, now);
    }

    return RecurringAutoRecordResult(
      generatedCount: generated.length,
      transactions: generated,
    );
  }

  /// 指定日時が [day] より厳密に後かを判定する
  bool _isStrictlyAfter(String iso, DateTime day) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return false;
    final d = DateTime(dt.year, dt.month, dt.day);
    return d.isAfter(day);
  }
}
