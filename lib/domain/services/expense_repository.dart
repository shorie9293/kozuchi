import '../models/expense_entry.dart';

/// 支出データの永続化インターフェース
///
/// Kozuchiアプリの支出記録を保存・取得するリポジトリ。
/// 実装は SharedPreferences や Hive など、環境に応じて切り替え可能。
abstract class ExpenseRepository {
  /// 指定された期間の支出エントリを全て取得する
  ///
  /// [start] 以上 [end] 以下の日付のエントリを返す。
  /// 日付比較は日単位（時刻は無視）。
  Future<List<ExpenseEntry>> getEntries({
    required DateTime start,
    required DateTime end,
  });

  /// 支出エントリを保存する
  ///
  /// 同じIDのエントリが既存の場合は上書き、新規の場合は追加。
  Future<void> saveEntry(ExpenseEntry entry);

  /// 複数の支出エントリを一括保存する
  Future<void> saveEntries(List<ExpenseEntry> entries);

  /// 全エントリ数を返す（テスト/デバッグ用）
  Future<int> getEntryCount();

  /// 全データを削除する（リセット用）
  Future<void> clearAll();
}
