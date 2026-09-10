import 'budget_rollover.dart';

/// 予算の月次繰り越し計算サービス
///
/// 前月の予算と支出から、当月へ繰り越す残額（または前月の超過額）を算出する
/// 純粋ロジック。I/Oを持たず試練（テスト）可能。
class BudgetRolloverService {
  /// 繰越上限額（円、nullは無制限）
  ///
  /// 前月の残額が上限を超える場合、繰越額は上限で頭打ちになる。
  final int? carryOverCap;

  const BudgetRolloverService({this.carryOverCap})
      : assert(carryOverCap == null || carryOverCap >= 0,
            '繰越上限は0以上である必要があります');

  /// 繰り越し結果を算出する
  ///
  /// [baseBudget] 当月の基本予算額。
  /// [previousBudget] 前月の予算額（0以下＝未設定なら繰越も超過判定も行わない）。
  /// [previousSpent] 前月の支出額。
  /// [enabled] 繰り越しが無効なら繰越を行わず、超過警告のみ算出する。
  BudgetRollover compute({
    required int baseBudget,
    required int previousBudget,
    required int previousSpent,
    bool enabled = true,
  }) {
    if (baseBudget < 0) {
      throw ArgumentError.value(baseBudget, 'baseBudget', '予算額は0以上である必要があります');
    }
    if (previousSpent < 0) {
      throw ArgumentError.value(
          previousSpent, 'previousSpent', '支出額は0以上である必要があります');
    }

    // 前月予算が未設定の場合は判定材料がないため中立を返す
    if (previousBudget <= 0) {
      return BudgetRollover(
        baseBudget: baseBudget,
        enabled: enabled,
        cap: carryOverCap,
      );
    }

    final remaining = previousBudget - previousSpent;

    // 超過: 残額がマイナス → 超過額を警告として返す（繰越は行わない）
    if (remaining < 0) {
      return BudgetRollover(
        baseBudget: baseBudget,
        overspend: -remaining,
        enabled: enabled,
        cap: carryOverCap,
      );
    }

    // 繰り越し無効時は残額を繰り越さない
    if (!enabled) {
      return BudgetRollover(
        baseBudget: baseBudget,
        enabled: false,
        cap: carryOverCap,
      );
    }

    var carry = remaining;
    if (carryOverCap != null && carry > carryOverCap!) {
      carry = carryOverCap!;
    }

    return BudgetRollover(
      baseBudget: baseBudget,
      carryOver: carry,
      enabled: enabled,
      cap: carryOverCap,
    );
  }
}
