import 'package:flutter/widgets.dart';

/// カテゴリ別予算推奨額画面の試練用Key一元管理
class CategoryBudgetSuggestionAppKeys {
  const CategoryBudgetSuggestionAppKeys._();

  static const Key suggestionScreen = Key('categoryBudgetSuggestionScreen');
  static const Key openButton = Key('categoryBudgetSuggestion_openButton');
  static const Key emptyState = Key('categoryBudgetSuggestion_emptyState');
  static const Key loading = Key('categoryBudgetSuggestion_loading');

  static Key row(String category) =>
      Key('categoryBudgetSuggestion_row_$category');

  static Key recommended(String category) =>
      Key('categoryBudgetSuggestion_recommended_$category');

  static Key applyButton(String category) =>
      Key('categoryBudgetSuggestion_apply_$category');

  static Key appliedMark(String category) =>
      Key('categoryBudgetSuggestion_applied_$category');
}