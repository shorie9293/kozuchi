import 'package:flutter/widgets.dart';

/// 取引編集機能のウィジェットキー。
///
/// 取引ごとのメニューは日時＋金額で一意化する（同額の取引が
/// 同時刻に複数あっても区別できるようにする）。
class TransactionEditAppKeys {
  const TransactionEditAppKeys._();

  /// 取引行の訂正メニュー（⋮）ボタン。
  static Key menuFor(String datetime, int amount) =>
      Key('transaction_edit_menu_${datetime}_$amount');

  /// 編集ダイアログの保存ボタン。
  static const Key saveButton = Key('transaction_edit_save_button');

  /// 編集ダイアログのキャンセルボタン。
  static const Key cancelButton = Key('transaction_edit_cancel_button');

  /// 編集ダイアログの金額欄。
  static const Key amountField = Key('transaction_edit_amount_field');

  /// 編集ダイアログのカテゴリ欄。
  static const Key categoryField = Key('transaction_edit_category_field');

  /// 編集ダイアログのメモ欄。
  static const Key noteField = Key('transaction_edit_note_field');

  /// 編集ダイアログの日付選択ボタン。
  static const Key dateButton = Key('transaction_edit_date_button');

  /// 削除確認ダイアログの確定ボタン。
  static const Key deleteConfirmButton =
      Key('transaction_edit_delete_confirm_button');

  /// 削除確認ダイアログの取消ボタン。
  static const Key deleteCancelButton =
      Key('transaction_edit_delete_cancel_button');
}
