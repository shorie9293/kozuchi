import 'package:flutter/widgets.dart';

/// カテゴリ台帳画面の試練用Key一元管理
///
/// 既存の [KozuchiAppKeys]・[CategoryBudgetAppKeys] には触れず、
/// 本機能専用のKeyをここに定義する。
class CategoryLedgerAppKeys {
  const CategoryLedgerAppKeys._();

  static const Key categoryLedgerScreen = Key('categoryLedgerScreen');
  static const Key categoryLedger_addButton = Key('categoryLedger_addButton');
  static const Key categoryLedger_resetButton =
      Key('categoryLedger_resetButton');
  static const Key categoryLedger_dialog = Key('categoryLedger_dialog');
  static const Key categoryLedger_nameField = Key('categoryLedger_nameField');
  static const Key categoryLedger_saveButton =
      Key('categoryLedger_saveButton');
  static const Key categoryLedger_errorText = Key('categoryLedger_errorText');
  static const Key categoryLedger_emptyText = Key('categoryLedger_emptyText');

  /// 予算設定画面からの導線ボタン
  static const Key openButton = Key('categoryLedger_openButton');

  static Key row(String category) => Key('categoryLedger_row_$category');
  static Key usage(String category) => Key('categoryLedger_usage_$category');
  static Key menuButton(String category) =>
      Key('categoryLedger_menu_$category');
  static Key deleteButton(String category) =>
      Key('categoryLedger_delete_$category');
}