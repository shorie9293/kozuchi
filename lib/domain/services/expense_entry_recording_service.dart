import '../models/expense_entry.dart';
import 'expense_repository.dart';

/// 支出記録を [ExpenseEntry] として永続化するサービス。
///
/// 支出実行フロー（FAB・試練クエスト）から呼び出され、個別明細を
/// リポジトリ経由で保存する。Supabase・ローカルのどちらにも対応する
/// よう [ExpenseRepository] 抽象に依存する。
class ExpenseEntryRecordingService {
  final ExpenseRepository repository;
  final DateTime Function() clock;

  const ExpenseEntryRecordingService({
    required this.repository,
    DateTime Function()? clock,
  }) : clock = clock ?? _systemNow;

  static DateTime _systemNow() => DateTime.now();

  /// 支出を記録し、保存済みの [ExpenseEntry] を返す。
  ///
  /// 金額が0以下の場合は保存せず null を返す。保存に失敗した場合も
  /// 例外を伝播せず null を返す（支出FABを妨げないための防御）。
  Future<ExpenseEntry?> record({
    required int amount,
    required String category,
    String? note,
  }) async {
    if (amount <= 0) return null;
    final entry = ExpenseEntry(
      id: 'exp_${clock().microsecondsSinceEpoch}',
      amount: amount,
      category: category,
      date: clock(),
      note: (note == null || note.trim().isEmpty) ? null : note,
    );
    try {
      await repository.saveEntry(entry);
      return entry;
    } catch (_) {
      // 保存失敗は記録フローを中断させない
      return null;
    }
  }
}
