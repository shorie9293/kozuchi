import 'package:flutter/widgets.dart';

/// 収入分析画面専用のテストキー。
///
/// KozuchiAppKeys に混ぜない（既知の不可視禍津の回避・
/// CategoryBudgetAppKeys と同じ別ファイル分離の方針）。
class IncomeAnalysisAppKeys {
  const IncomeAnalysisAppKeys._();

  static const Key screen = Key('income_analysis_screen');

  /// 検索フィールド
  static const Key searchField = Key('income_analysis_search_field');

  /// 検索クリアボタン
  static const Key searchClearButton = Key('income_analysis_search_clear');

  /// 合計カード
  static const Key totalCard = Key('income_analysis_total_card');

  /// 件数ラベル
  static const Key countLabel = Key('income_analysis_count_label');

  /// 収入源行（sourceキーを後置）
  static Key sourceRow(String normalizedSource) =>
      Key('income_analysis_source_row_$normalizedSource');

  /// 収入源の金額ラベル
  static Key sourceAmount(String normalizedSource) =>
      Key('income_analysis_source_amount_$normalizedSource');

  /// 空状態
  static const Key emptyState = Key('income_analysis_empty_state');
}
