import 'package:flutter/widgets.dart';

/// 取引検索機能の試練用 Key（アプリ全体で一元管理する）。
///
/// 既存の [KozuchiAppKeys]（core 配下）とは別ファイルで管理する。
/// 同一 Key の重複登録を避けるため、本機能専用のプレフィックス `txq_` を使う。
class TransactionQueryAppKeys {
  const TransactionQueryAppKeys._();

  /// キーワード入力 TextField
  static const Key keywordField = Key('txq_keyword_field');

  /// キーワードクリアボタン
  static const Key keywordClear = Key('txq_keyword_clear');

  /// 絞込結果サマリーバー
  static const Key summaryBar = Key('txq_summary_bar');

  /// 絞込結果の件数表示
  static const Key resultCount = Key('txq_result_count');

  /// フィルタリセットボタン
  static const Key resetButton = Key('txq_reset_button');

  /// カテゴリ ChoiceChip の Key（カテゴリ名ごとに一意）
  static Key categoryChip(String name) => Key('txq_category_chip_$name');

  /// タグ ChoiceChip の Key（タグIDごとに一意）
  static Key tagChip(String id) => Key('txq_tag_chip_$id');
}