import 'package:flutter/widgets.dart';

/// 週次クエストUIの試練用Key一元管理。
///
/// 既存の [KozuchiAppKeys] には触れず、本機能専用のKeyをここに定義する。
class WeeklyQuestAppKeys {
  const WeeklyQuestAppKeys._();

  /// ホーム画面の週次クエストセクション全体。
  static const Key section = Key('weeklyQuestSection');

  /// セクション見出し。
  static const Key title = Key('weeklyQuestSection_title');

  /// 「今週のクエストを選ぶ」ボタン。
  static const Key selectButton = Key('weeklyQuestSection_selectButton');

  /// 候補も active も無い空状態。
  static const Key empty = Key('weeklyQuestSection_empty');

  /// 選択中クエストのカード。
  static const Key activeCard = Key('weeklyQuestSection_activeCard');

  /// 読み込み中インジケータ。
  static const Key loading = Key('weeklyQuestSection_loading');

  /// エラー時の再試行ボタン。
  static const Key retryButton = Key('weeklyQuestSection_retryButton');

  /// クエスト候補カード（[questId] ごと）。
  static Key card(String questId) => Key('weeklyQuestCard_$questId');

  /// クエストの状態チップ（[questId] ごと）。
  static Key statusChip(String questId) => Key('weeklyQuestStatus_$questId');
}
