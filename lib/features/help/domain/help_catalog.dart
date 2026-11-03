import 'package:kozuchi/features/help/domain/help_topic.dart';
import 'package:kozuchi/features/tutorial/domain/kozuchi_tutorial_step.dart';

/// ヘルプ目次。データはチュートリアルの文言から生成する（二重管理しない）。
class HelpCatalog {
  /// [topics] を省略すると [KozuchiTutorialStep] から既定目次を組み立てる。
  HelpCatalog({List<HelpTopic>? topics})
      : _topics = List<HelpTopic>.unmodifiable(
          topics ?? _topicsFromTutorial(),
        );

  final List<HelpTopic> _topics;

  /// 宣言順の全章。
  List<HelpTopic> get allTopics => _topics;

  /// 部分一致・大文字小文字無視の検索。空クエリ（空白のみ含む）は全件。
  List<HelpTopic> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return allTopics;
    return List<HelpTopic>.unmodifiable(
      _topics.where(
        (topic) =>
            topic.title.toLowerCase().contains(needle) ||
            topic.body.toLowerCase().contains(needle),
      ),
    );
  }

  /// チュートリアルの label / description を 1 章ずつ写す。
  static List<HelpTopic> _topicsFromTutorial() {
    return [
      for (final step in KozuchiTutorialStep.values)
        HelpTopic(
          id: step.name,
          title: step.label,
          body: step.description,
        ),
    ];
  }
}
