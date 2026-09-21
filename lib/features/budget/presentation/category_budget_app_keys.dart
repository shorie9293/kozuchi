import 'package:flutter/widgets.dart';

/// カテゴリ別予算画面の試練用Key一元管理
///
/// 既存の [KozuchiAppKeys] には触れず、本画面専用のKeyをここに定義する。
class CategoryBudgetAppKeys {
  const CategoryBudgetAppKeys._();

  static const Key categoryBudgetScreen = Key('categoryBudgetScreen');
  static const Key categoryBudget_summary = Key('categoryBudget_summary');
  static const Key categoryBudget_editDialog = Key('categoryBudget_editDialog');
  static const Key categoryBudget_amountField = Key('categoryBudget_amountField');
  static const Key categoryBudget_saveButton = Key('categoryBudget_saveButton');
  static const Key categoryBudget_removeButton = Key('categoryBudget_removeButton');
  static const Key openButton = Key('categoryBudget_openButton');

  static Key row(String category) => Key('categoryBudget_row_$category');
  static Key state(String category) => Key('categoryBudget_state_$category');
}