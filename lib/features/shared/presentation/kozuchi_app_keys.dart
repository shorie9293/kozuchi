import 'package:flutter/widgets.dart';

/// CSVインポート・定期取引機能の試練用Key。
///
/// takamagahara_ui の AppKeys とは別に、kozuchi 単体で完結させるために
/// ローカルに定義する。takamagahara_ui は別リポジトリ（CIでクローン）のため、
/// ここに追加した Key は takamagahara_ui 側に依存しない。
class KozuchiAppKeys {
  const KozuchiAppKeys._();

  // ── CSVインポート ──
  static const Key csvImportScreen = Key('csvImportScreen');
  static const Key csvImport_pickButton = Key('csvImport_pickButton');
  static const Key csvImport_resultCard = Key('csvImport_resultCard');
  static const Key csvImportErrorText = Key('csvImport_errorText');
  static const Key csvImport_importedList = Key('csvImport_importedList');

  // ── 定期取引 ──
  static const Key recurringTxScreen = Key('recurringTxScreen');
  static const Key recurringTx_addButton = Key('recurringTx_addButton');
  static const Key recurringTx_purposeField = Key('recurringTx_purposeField');
  static const Key recurringTx_amountField = Key('recurringTx_amountField');
  static const Key recurringTx_frequencyDropdown =
      Key('recurringTx_frequencyDropdown');
  static const Key recurringTx_dayOfWeekDropdown =
      Key('recurringTx_dayOfWeekDropdown');
  static const Key recurringTx_dayOfMonthField =
      Key('recurringTx_dayOfMonthField');
  static const Key recurringTx_saveButton = Key('recurringTx_saveButton');

  static Key recurringTxDeleteButton(String id) =>
      Key('recurringTx_deleteButton_$id');
}
