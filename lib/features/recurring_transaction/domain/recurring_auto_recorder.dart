import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/data/recurring_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction_generator.dart';

/// 定期取引の自動記録結果
class RecurringAutoRecordResult {
  final int generatedCount;
  final List<TransactionModel> transactions;
  const RecurringAutoRecordResult({
    required this.generatedCount,
    required this.transactions,
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
  /// 通常は呼び出し側で try/catch により握りつぶし、起動を妨げない。
  Future<RecurringAutoRecordResult> run() async {
    final now = clock();
    final definitions = await recurringRepository.loadDefinitions();
    final generated = <TransactionModel>[];

    for (final def in definitions) {
      if (!def.isActive) continue;

      final lastGenerated = await recurringRepository.loadLastGenerated(def.id);
      final due = generator.generateFor(def, now);

      final List<TransactionModel> newOnes;
      if (lastGenerated != null) {
        final lastDay =
            DateTime(lastGenerated.year, lastGenerated.month, lastGenerated.day);
        // 前回生成日時より後（厳密に）の発生分のみ
        newOnes = due.where((t) => _isStrictlyAfter(t.datetime, lastDay)).toList();
      } else {
        // lastGenerated 未設定なら startDate 以降すべて
        newOnes = due;
      }

      generated.addAll(newOnes);
      // lastGenerated を now に進める（発生有無に関わらず）
      await recurringRepository.saveLastGenerated(def.id, now);
    }

    if (generated.isNotEmpty) {
      await transactionRepository.addTransactions(generated);
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
