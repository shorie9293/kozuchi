import 'package:flutter/widgets.dart';

/// 分割払い・サブスク管理機能の試練用Key。
///
/// [KozuchiAppKeys] とは分離し、本機能の Key はここで一元管理する。
class InstallmentAppKeys {
  const InstallmentAppKeys._();

  // ── 分割払い画面 ──
  static const Key installmentScreen = Key('installment_screen');
  static const Key installmentAddButton = Key('installment_addButton');
  static const Key installmentEmpty = Key('installment_empty');
  static const Key installmentRemainingTotal = Key('installment_remainingTotal');

  static Key installmentTile(String id) => Key('installment_tile_$id');

  static Key installmentPayButton(String id) => Key('installment_payButton_$id');

  static Key installmentDeleteButton(String id) =>
      Key('installment_deleteButton_$id');

  // ── サブスク画面 ──
  static const Key subscriptionScreen = Key('subscription_screen');
  static const Key subscriptionAddButton = Key('subscription_addButton');
  static const Key subscriptionEmpty = Key('subscription_empty');
  static const Key subscriptionMonthlyTotal = Key('subscription_monthlyTotal');

  static Key subscriptionTile(String id) => Key('subscription_tile_$id');

  static Key subscriptionToggle(String id) => Key('subscription_toggle_$id');

  static Key subscriptionDeleteButton(String id) =>
      Key('subscription_deleteButton_$id');

  // ── 追加ダイアログ共通 ──
  static const Key purposeField = Key('installment_purposeField');
  static const Key amountField = Key('installment_amountField');
  static const Key countField = Key('installment_countField');
  static const Key dialogSaveButton = Key('installment_dialogSaveButton');
}
