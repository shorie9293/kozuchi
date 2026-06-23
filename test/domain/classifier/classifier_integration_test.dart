import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/classifier/classifier_interface.dart';
import 'package:kozuchi/domain/classifier/classifier_service.dart';
import 'package:kozuchi/domain/classifier/keyword_classifier.dart';

/// キーワード分類器の統合試験
///
/// 50+件の実在しそうな用途テキストで分類精度を検証する。
/// 目標精度: 80%以上。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KeywordClassifier classifier;
  final misclassifications = <Map<String, String>>[];

  /// テストケース: [description, expectedCategory]
  /// 実際の家計簿でよくある用途テキストを使用。
  final testCases = <Map<String, String>>[
    // ── 食費（15件） ──
    {'desc': 'スーパーで夕食の買い物', 'expected': '食費'},
    {'desc': 'コンビニでおにぎりとお茶', 'expected': '食費'},
    {'desc': 'マクドナルドでランチ', 'expected': '食費'},
    {'desc': '居酒屋で同僚と食事', 'expected': '食費'},
    {'desc': 'ラーメン二郎で味噌ラーメン', 'expected': '食費'},
    {'desc': '業務スーパーで冷凍食品まとめ買い', 'expected': '食費'},
    {'desc': 'ウーバーイーツで寿司を注文', 'expected': '食費'},
    {'desc': 'ケーキ屋で誕生日ケーキ', 'expected': '食費'},
    {'desc': 'スタバでコーヒー', 'expected': '食費'},
    {'desc': 'おにぎりとサンドイッチ', 'expected': '食費'},
    {'desc': 'コストコで食材まとめ買い', 'expected': '食費'},
    {'desc': '焼肉食べ放題', 'expected': '食費'},
    {'desc': 'すし屋でランチ', 'expected': '食費'},
    {'desc': '生協の配達で牛乳と卵', 'expected': '食費'},
    {'desc': 'デパ地下で惣菜', 'expected': '食費'},

    // ── 娯楽（15件） ──
    {'desc': '映画館で映画', 'expected': '娯楽'},
    {'desc': '任天堂スイッチのゲームソフト', 'expected': '娯楽'},
    {'desc': 'カラオケで3時間', 'expected': '娯楽'},
    {'desc': 'ディズニーランドのチケット', 'expected': '娯楽'},
    {'desc': 'Netflixの月額サブスク', 'expected': '娯楽'},
    {'desc': '旅行で温泉旅館に宿泊', 'expected': '娯楽'},
    {'desc': 'コンサートのチケット', 'expected': '娯楽'},
    {'desc': 'フィギュアを買った', 'expected': '娯楽'},
    {'desc': '週刊誌とマンガ', 'expected': '娯楽'},
    {'desc': '美術館の入場料', 'expected': '娯楽'},
    {'desc': 'パチンコで遊んだ', 'expected': '娯楽'},
    {'desc': 'キャンプ用品を購入', 'expected': '娯楽'},
    {'desc': 'ゴルフのプレー代', 'expected': '娯楽'},
    {'desc': 'ゲームセンターで遊んだ', 'expected': '娯楽'},
    {'desc': 'テーマパークの入園料', 'expected': '娯楽'},

    // ── 交通（12件） ──
    {'desc': 'Suicaにチャージ', 'expected': '交通'},
    {'desc': '電車で通勤', 'expected': '交通'},
    {'desc': 'ガソリンスタンドで給油', 'expected': '交通'},
    {'desc': '高速バスで帰省', 'expected': '交通'},
    {'desc': 'タクシーで帰宅', 'expected': '交通'},
    {'desc': '新幹線で出張', 'expected': '交通'},
    {'desc': '飛行機の航空券', 'expected': '交通'},
    {'desc': 'コインパーキングに駐車', 'expected': '交通'},
    {'desc': '定期券の更新', 'expected': '交通'},
    {'desc': 'レンタカーを借りた', 'expected': '交通'},
    {'desc': 'ETCの高速料金', 'expected': '交通'},
    {'desc': 'カーシェアの利用料', 'expected': '交通'},

    // ── 光熱費（10件） ──
    {'desc': '電気代の支払い', 'expected': '光熱費'},
    {'desc': 'ガス代の口座振替', 'expected': '光熱費'},
    {'desc': '水道料金の支払い', 'expected': '光熱費'},
    {'desc': '灯油を購入', 'expected': '光熱費'},
    {'desc': 'クーラーの電気代', 'expected': '光熱費'},
    {'desc': '東京ガスの請求', 'expected': '光熱費'},
    {'desc': 'プロパンガスの料金', 'expected': '光熱費'},
    {'desc': '暖房用の灯油', 'expected': '光熱費'},
    {'desc': '電力会社に支払い', 'expected': '光熱費'},
    {'desc': '水道代の引落', 'expected': '光熱費'},

    // ── 交際費（10件） ──
    {'desc': '友人の結婚祝い', 'expected': '交際費'},
    {'desc': 'お歳暮のギフト', 'expected': '交際費'},
    {'desc': '飲み会の割り勘', 'expected': '交際費'},
    {'desc': '母の日のプレゼント', 'expected': '交際費'},
    {'desc': '香典', 'expected': '交際費'},
    {'desc': '忘年会の会費', 'expected': '交際費'},
    {'desc': 'お土産を買った', 'expected': '交際費'},
    {'desc': '同僚の送別会', 'expected': '交際費'},
    {'desc': '寄付金', 'expected': '交際費'},
    {'desc': '取引先との会食', 'expected': '交際費'},

    // ── 分類不能（カバーされていないカテゴリ / 曖昧 / 不明） ──
    {'desc': '家賃の支払い', 'expected': 'その他'},
    {'desc': '携帯電話料金', 'expected': 'その他'},
    {'desc': '病院の診察代', 'expected': 'その他'},
    {'desc': '塾の月謝', 'expected': 'その他'},
    {'desc': 'トイレットペーパーと洗剤', 'expected': 'その他'},
    {'desc': 'スーツを購入', 'expected': 'その他'},
    {'desc': '生命保険の保険料', 'expected': 'その他'},
    {'desc': '住民税の支払い', 'expected': 'その他'},
    {'desc': '散髪代', 'expected': 'その他'},
    {'desc': '何も書かず', 'expected': 'その他'},  // 空文字→分類不能
  ];

  setUp(() async {
    // 本番JSONから分類器を構築
    final jsonString =
        await rootBundle.loadString('assets/keyword_category_map.json');
    classifier = KeywordClassifier.fromJsonString(jsonString);
  });

  group('統合精度試験（50+件）', () {
    test('全テストケースの分類結果を集計', () {
      var correct = 0;
      var total = 0;
      final results = <String>[];

      for (final tc in testCases) {
        final desc = tc['desc']!;
        final expected = tc['expected']!;

        final result = classifier.classify(desc);
        final actual = result.isClassified ? result.category : 'その他';

        if (actual == expected) {
          correct++;
          results.add('✅ $desc → $actual (${result.confidence.name})');
        } else {
          misclassifications.add({
            'description': desc,
            'expected': expected,
            'actual': actual,
            'confidence': result.confidence.name,
            'matchedRule': result.matchedRule ?? 'none',
          });
          results.add('❌ $desc → $actual (expected: $expected, '
              'confidence: ${result.confidence.name}, '
              'matched: ${result.matchedRule})');
        }
        total++;
      }

      final accuracy = (correct / total * 100).toStringAsFixed(1);

      // 結果表示
      print('=== 分類精度レポート ===');
      print('総件数: $total');
      print('正解数: $correct');
      print('精度: $accuracy%');
      print('');
      for (final r in results) {
        print(r);
      }

      if (misclassifications.isNotEmpty) {
        print('');
        print('=== 誤分類一覧 ===');
        for (final m in misclassifications) {
          print('説明: "${m['description']}"');
          print('  期待: ${m['expected']} → 実際: ${m['actual']}');
          print('  信頼度: ${m['confidence']}');
          print('  マッチ: ${m['matchedRule']}');
          print('');
        }
      }

      // 精度が80%以上であることを検証
      expect(correct / total, greaterThanOrEqualTo(0.80),
          reason: '分類精度が80%未満です（${accuracy}%）');
    });

    test('各カテゴリの分類精度を報告', () {
      final categoryStats = <String, Map<String, int>>{};

      for (final tc in testCases) {
        final desc = tc['desc']!;
        final expected = tc['expected']!;
        if (desc.isEmpty) continue;

        final result = classifier.classify(desc);
        final actual = result.isClassified ? result.category : 'その他';

        categoryStats.putIfAbsent(expected, () => {'correct': 0, 'total': 0});
        categoryStats[expected]!['total'] = categoryStats[expected]!['total']! + 1;
        if (actual == expected) {
          categoryStats[expected]!['correct'] =
              categoryStats[expected]!['correct']! + 1;
        }
      }

      print('=== カテゴリ別精度 ===');
      for (final entry in categoryStats.entries) {
        final cat = entry.key;
        final stats = entry.value;
        final acc = stats['correct']! / stats['total']! * 100;
        print('$cat: ${stats['correct']}/${stats['total']} '
            '(${acc.toStringAsFixed(1)}%)');
      }
    });
  });
}
