import '../models/income_entry.dart';
import 'income_repository.dart';

/// 収入記録を [IncomeEntry] として永続化するサービス。
///
/// [ExpenseEntryRecordingService]（支出版）と対になる。
/// 収入入力フロー（IncomeInputScreen → MainScreen）から呼び出され、
/// 保存失敗でも記録フローを妨げないよう防御する。
class IncomeEntryRecordingService {
  final IncomeRepository repository;
  final DateTime Function() clock;

  const IncomeEntryRecordingService({
    required this.repository,
    DateTime Function()? clock,
  }) : clock = clock ?? _systemNow;

  static DateTime _systemNow() => DateTime.now();

  /// 収入を記録し、保存済みの [IncomeEntry] を返す。
  ///
  /// 金額が0以下の場合は保存せず null を返す。保存に失敗した場合も
  /// 例外を伝播せず null を返す（収入記録フローを妨げないための防御）。
  Future<IncomeEntry?> record({
    required int amount,
    required String source,
    String? note,
  }) async {
    if (amount <= 0) return null;
    if (source.trim().isEmpty) return null;
    final entry = IncomeEntry(
      id: 'inc_${clock().microsecondsSinceEpoch}',
      amount: amount,
      source: source.trim(),
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
