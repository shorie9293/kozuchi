import 'package:flutter/widgets.dart';

/// ヘルプ画面の試練用 Key を一元管理する（明示ID）。
class HelpAppKeys {
  HelpAppKeys._();

  static const Key screen = Key('help_screen');
  static const Key searchField = Key('help_search_field');
  static const Key list = Key('help_topic_list');
  static const Key emptyMessage = Key('help_empty_message');

  /// 章ごとの Key（[id] は HelpTopic.id）。
  static Key topicTile(String id) => Key('help_topic_$id');
}
