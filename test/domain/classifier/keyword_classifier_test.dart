
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/classifier/classifier_interface.dart';
import 'package:kozuchi/domain/classifier/keyword_classifier.dart';

/// テスト用の最小限 JSON ルール
const _testRulesJson = '''
{
  "version": 1,
  "categories": {
    "食費": {
      "en": "food",
      "description": "食に関する支出",
      "keywords": ["スーパー", "マクドナルド", "コンビニ", "ラーメン", "弁当"]
    },
    "交通": {
      "en": "transportation",
      "description": "移動に関する支出",
      "keywords": ["Suica", "電車", "バス", "ガソリン", "タクシー"]
    },
    "娯楽": {
      "en": "entertainment",
      "description": "娯楽に関する支出",
      "keywords": ["ゲーム", "映画", "カラオケ", "Netflix"]
    }
  }
}
''';

void main() {
  late KeywordClassifier classifier;

  setUp(() {
    classifier = KeywordClassifier.fromJsonString(_testRulesJson);
  });

  group('KeywordClassifier', () {
    group('基本的な分類', () {
      test('完全一致キーワードは高信頼度で分類される', () {
        final result = classifier.classify('マクドナルド');
        expect(result.category, '食費');
        expect(result.confidence, Confidence.high);
        expect(result.matchedRule, contains('マクドナルド'));
      });

      test('説明文にキーワードが含まれていれば中信頼度で分類される', () {
        final result = classifier.classify('マクドナルドでハンバーガー購入');
        expect(result.category, '食費');
        expect(result.confidence, Confidence.medium);
      });

      test('複数カテゴリのキーワードがある場合、最長一致が選ばれる', () {
        // 'ガソリンスタンド' は '交通' に含まれている前提
        // このテスト用JSONでは 'ガソリン' が存在
        final result = classifier.classify('ガソリンスタンドで給油');
        expect(result.category, '交通');
      });

      test('マッチしない説明文は none 信頼度で「その他」が返る', () {
        final result = classifier.classify('家賃');
        expect(result.category, 'その他');
        expect(result.confidence, Confidence.none);
        expect(result.isClassified, false);
      });

      test('空文字列は分類不能', () {
        final result = classifier.classify('');
        expect(result.confidence, Confidence.none);
        expect(result.isClassified, false);
      });

      test('空白のみの文字列は正規化後分類不能', () {
        final result = classifier.classify('  　  ');
        expect(result.confidence, Confidence.none);
        expect(result.isClassified, false);
      });
    });

    group('supportedCategories', () {
      test('設定された全カテゴリを返す', () {
        final categories = classifier.supportedCategories;
        expect(categories, containsAll(['食費', '交通', '娯楽']));
      });
    });

    group('classifyWithFallback', () {
      test('フォールバックカテゴリが機能する', () {
        final result = classifier.classifyWithFallback(
          '家賃',
          fallback: '住居費',
        );
        expect(result.category, '住居費');
        expect(result.confidence, Confidence.none);
      });

      test('マッチした場合はフォールバックは無視される', () {
        final result = classifier.classifyWithFallback(
          'マクドナルド',
          fallback: 'その他',
        );
        expect(result.category, '食費');
        expect(result.confidence, Confidence.high);
      });
    });

    group('initialize', () {
      test('initialize は正常に完了する', () async {
        await classifier.initialize();
        // initialize後も正常に分類できる
        final result = classifier.classify('Suicaでチャージ');
        expect(result.category, '交通');
        expect(result.confidence, Confidence.medium);
      });
    });

    group('classifierName', () {
      test('分類器の名前が取得できる', () {
        expect(classifier.classifierName, isNotEmpty);
      });
    });

    group('正規化（DescriptionNormalizer）', () {
      test('全角スペースが半角に正規化される', () {
        // 全角スペースを含む説明文でもマッチする
        final result = classifier.classify('マクドナルド　ハンバーガー');
        expect(result.category, '食費');
        expect(result.confidence, Confidence.medium);
      });

      test('前後の空白がトリムされる', () {
        final result = classifier.classify('  マクドナルド  ');
        expect(result.category, '食費');
        expect(result.confidence, Confidence.high);
      });
    });
  });
}
