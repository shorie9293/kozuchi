import 'package:flutter/widgets.dart';

/// 支出異常検知画面の試練用Key一元管理
///
/// 既存の [KozuchiAppKeys] には触れず、本画面専用のKeyをここに定義する。
class ExpenseAnomalyAppKeys {
  const ExpenseAnomalyAppKeys._();

  static const Key anomalyScreen = Key('expenseAnomalyScreen');
  static const Key summary = Key('expenseAnomaly_summary');
  static const Key empty = Key('expenseAnomaly_empty');
  static const Key list = Key('expenseAnomaly_list');
  static const Key openButton = Key('expenseAnomaly_openButton');

  static Key row(String id) => Key('expenseAnomaly_row_$id');
}
