import 'package:flutter/widgets.dart';

/// 「家計の締め日」セクションの試練用Key一元管理。
///
/// 既存の `KozuchiAppKeys` には触れず、本セクション専用のKeyをここに定義する
/// （既存Keyの重複・不可視化を避けるため）。
class BudgetPeriodAppKeys {
  const BudgetPeriodAppKeys._();

  /// セクション全体のコンテナ。
  static const Key section = Key('budgetPeriod_section');

  /// 締め日変更ダイアログを開くボタン。
  static const Key editButton = Key('budgetPeriod_editButton');

  /// ダイアログ内の締め日選択（DropdownButton）。
  static const Key dropdown = Key('budgetPeriod_dropdown');

  /// ダイアログ内の保存ボタン。
  static const Key saveButton = Key('budgetPeriod_saveButton');

  /// 現在値ラベル（例: 毎月25日締め）。
  static const Key currentLabel = Key('budgetPeriod_currentLabel');

  /// 期間の説明（例: 前月26日〜当月25日）。
  static const Key transitionLabel = Key('budgetPeriod_transitionLabel');

  /// 現在期間プレビューの期間ラベル（例: 2026/10/26 〜 2026/11/25）。
  static const Key previewLabel = Key('budgetPeriod_previewLabel');

  /// 現在期間プレビューの日数（例: 31日）。
  static const Key previewDays = Key('budgetPeriod_previewDays');
}
