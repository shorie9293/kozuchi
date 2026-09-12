import 'package:flutter/widgets.dart';

/// 財布（口座・支払い手段）機能の試練用Key。
///
/// [KozuchiAppKeys] とは分離し、財布機能の Key はここで一元管理する。
class WalletAppKeys {
  const WalletAppKeys._();

  // ── 財布管理画面 ──
  static const Key managementScreen = Key('wallet_managementScreen');
  static const Key addButton = Key('wallet_addButton');
  static const Key empty = Key('wallet_empty');
  static const Key totalCard = Key('wallet_totalCard');

  static Key listTile(String id) => Key('wallet_listTile_$id');

  static Key balanceText(String id) => Key('wallet_balance_$id');

  static Key movementsCount(String id) => Key('wallet_movementsCount_$id');

  static Key deleteButton(String id) => Key('wallet_deleteButton_$id');

  // ── 財布追加ダイアログ ──
  static const Key nameField = Key('wallet_nameField');
  static const Key initialField = Key('wallet_initialField');
  static const Key typeDropdown = Key('wallet_typeDropdown');
  static const Key dialogSaveButton = Key('wallet_dialogSaveButton');
  static const Key dialogError = Key('wallet_dialogError');

  // ── 入出金画面 ──
  static const Key movementsScreen = Key('wallet_movementsScreen');
  static const Key movementsEmpty = Key('wallet_movementsEmpty');
  static const Key movementsBalance = Key('wallet_movementsBalance');
  static const Key movementAddButton = Key('wallet_movementAddButton');

  static Key movementTile(String id) => Key('wallet_movementTile_$id');

  static Key movementDeleteButton(String id) =>
      Key('wallet_movementDeleteButton_$id');

  // ── 入出金ダイアログ ──
  static const Key amountField = Key('wallet_amountField');
  static const Key noteField = Key('wallet_noteField');
  static const Key incomeChoice = Key('wallet_incomeChoice');
  static const Key expenseChoice = Key('wallet_expenseChoice');
  static const Key movementSaveButton = Key('wallet_movementSaveButton');
  static const Key movementDialogError = Key('wallet_movementDialogError');
}

/// 金額・日付の表示整形（財布機能内で共用）
String formatYen(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}¥$buffer';
}

/// 符号を明示した金額表示（入金は +、出金は −）
String formatYenSigned(int amount) =>
    amount > 0 ? '+${formatYen(amount)}' : formatYen(amount);

/// 日付表示（YYYY/MM/DD）
String formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}/$month/$day';
}
