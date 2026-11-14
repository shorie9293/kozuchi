import 'package:kozuchi/domain/models/expense_entry.dart';

/// クラウドからの支出明細読込の結果。
///
/// 「読めた件数」だけでは破損行の存在を表現できないため、
/// 読み飛ばした行数と、そもそも照合できたかどうかを併せて返す。
///
/// - [skippedCount] — 型不整合などで読み飛ばした行数（0 なら全行読めた）。
/// - [canVerify] — 応答がリストとして解釈できたか。
///   `false` は「照合そのものができなかった」を意味し、[entries] は空。
class ExpenseEntriesLoadResult {
  final List<ExpenseEntry> entries;
  final int skippedCount;
  final bool canVerify;

  const ExpenseEntriesLoadResult({
    required this.entries,
    required this.skippedCount,
    required this.canVerify,
  });
}
