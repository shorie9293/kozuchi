import 'package:flutter/widgets.dart';

/// クイックテンプレート機能の試練用Key。
///
/// [KozuchiAppKeys] とは分離し、クイックテンプレート機能の Key は
/// ここで一元管理する。
class QuickTemplateAppKeys {
  const QuickTemplateAppKeys._();

  // ── クイックテンプレートバー ──
  static const Key bar = Key('quickTemplate_bar');
  static const Key manageButton = Key('quickTemplate_manageButton');

  static Key chip(String id) => Key('quickTemplate_chip_$id');

  // ── 管理画面 ──
  static const Key managementScreen = Key('quickTemplate_managementScreen');
  static const Key addButton = Key('quickTemplate_addButton');
  static const Key amountField = Key('quickTemplate_amountField');
  static const Key purposeField = Key('quickTemplate_purposeField');
  static const Key saveButton = Key('quickTemplate_saveButton');

  static Key listTile(String id) => Key('quickTemplate_listTile_$id');

  static Key deleteButton(String id) => Key('quickTemplate_deleteButton_$id');
}
