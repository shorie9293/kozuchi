import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/help/domain/help_catalog.dart';
import 'package:kozuchi/features/help/domain/help_topic.dart';
import 'package:kozuchi/features/tutorial/domain/kozuchi_tutorial_step.dart';

/// ヘルプ目次の試練。
///
/// 文言はチュートリアル（[KozuchiTutorialStep]）を正とし、
/// カタログはそれを写すだけであることを固定する。
void main() {
  group('HelpCatalog - 宣言順', () {
    test('チュートリアルの宣言順で全ステップを列挙する', () {
      final catalog = HelpCatalog();
      expect(
        catalog.allTopics.map((t) => t.id).toList(),
        KozuchiTutorialStep.values.map((s) => s.name).toList(),
      );
    });

    test('title/body はチュートリアルの label/description をそのまま使う', () {
      final catalog = HelpCatalog();
      for (final step in KozuchiTutorialStep.values) {
        final topic =
            catalog.allTopics.firstWhere((t) => t.id == step.name);
        expect(topic.title, step.label);
        expect(topic.body, step.description);
      }
    });

    test('id は一意で、title/body は空でない', () {
      final topics = HelpCatalog().allTopics;
      final ids = topics.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final topic in topics) {
        expect(topic.title.trim(), isNotEmpty);
        expect(topic.body.trim(), isNotEmpty);
      }
    });
  });

  group('HelpCatalog.search', () {
    test('部分一致で絞り込む', () {
      final hits = HelpCatalog().search('支出');
      expect(hits, hasLength(1));
      expect(hits.single.title, '支出の理');
    });

    test('空クエリは全件を宣言順で返す', () {
      final catalog = HelpCatalog();
      expect(catalog.search('').map((t) => t.id).toList(),
          catalog.allTopics.map((t) => t.id).toList());
    });

    test('空白のみのクエリも全件を返す', () {
      final catalog = HelpCatalog();
      expect(catalog.search('   ').length, catalog.allTopics.length);
    });

    test('該当なしなら空を返す', () {
      expect(HelpCatalog().search('存在しない語句xyz'), isEmpty);
    });

    test('大文字小文字を無視する', () {
      final catalog = HelpCatalog(
        topics: const [
          HelpTopic(id: 'hp', title: 'HPの理', body: 'Heart Point'),
          HelpTopic(id: 'exp', title: 'EXPの理', body: 'Experience'),
        ],
      );
      expect(catalog.search('hp').single.id, 'hp');
      expect(catalog.search('heart point').single.id, 'hp');
      expect(catalog.search('ExPeRiEnCe').single.id, 'exp');
    });

    test('複数該当時も宣言順を維持する', () {
      final catalog = HelpCatalog(
        topics: const [
          HelpTopic(id: 'a', title: '開眼', body: 'EXPが増える'),
          HelpTopic(id: 'b', title: '支出', body: 'とにかく支出'),
          HelpTopic(id: 'c', title: 'EXP', body: '悟り'),
        ],
      );
      expect(catalog.search('exp').map((t) => t.id).toList(), ['a', 'c']);
    });
  });
}
