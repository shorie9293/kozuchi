import 'package:flutter/widgets.dart';

/// タグ機能（支出タグ付け・タグ別集計）の試練用Key。
///
/// [KozuchiAppKeys] とは分離し、タグ機能の Key はここで一元管理する。
class TagAppKeys {
  const TagAppKeys._();

  // ── タグ管理画面 ──
  static const Key managementScreen = Key('tag_managementScreen');
  static const Key addButton = Key('tag_addButton');
  static const Key nameField = Key('tag_nameField');
  static const Key saveButton = Key('tag_saveButton');

  static Key listTile(String id) => Key('tag_listTile_$id');

  static Key deleteButton(String id) => Key('tag_deleteButton_$id');

  // ── タグ別集計画面 ──
  static const Key summaryScreen = Key('tag_summaryScreen');
  static const Key summaryUntaggedRow = Key('tag_summary_untaggedRow');

  static Key summaryRow(String id) => Key('tag_summaryRow_$id');

  // ── タグ割当ダイアログ ──
  static const Key assignmentDialog = Key('tagAssignmentDialog');
  static const Key assignmentSaveButton = Key('tagAssignmentSaveButton');

  // ── 取引履歴からの導線 ──
  static const Key historyTagSummaryButton = Key('transactionHistory_tagButton');
  static const Key historyTagManageButton = Key('transactionHistory_tagManageButton');
}
