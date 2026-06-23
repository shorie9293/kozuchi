import 'dart:convert';

import 'package:kozuchi/domain/classifier/classifier_interface.dart';

/// キーワードベースの支出分類器
///
/// JSON ルールファイルからキーワード→カテゴリのマッピングを読み込み、
/// 説明テキスト中のキーワードマッチでカテゴリを分類する。
///
/// [DescriptionNormalizer] ミックスインにより、分類前にテキストを
/// 正規化（トリム・全角スペース→半角）する。
///
/// ## 信頼度の判定
/// - [Confidence.high]: 説明文がキーワードと完全一致
/// - [Confidence.medium]: 説明文にキーワードが部分一致
/// - [Confidence.none]: マッチなし
///
/// ## 複数マッチ時の解決
/// 最長一致キーワードを優先。同長の場合はカテゴリ優先度順。
class KeywordClassifier extends ExpenseClassifier with DescriptionNormalizer {
  final List<CategoryRule> _rules;

  KeywordClassifier(this._rules);

  /// JSON 文字列から分類器を構築
  ///
  /// [jsonString] は以下の形式:
  /// ```json
  /// {
  ///   "categories": {
  ///     "カテゴリ名": {
  ///       "keywords": ["キーワード1", "キーワード2"]
  ///     }
  ///   }
  /// }
  /// ```
  factory KeywordClassifier.fromJsonString(String jsonString) {
    final map = json.decode(jsonString) as Map<String, dynamic>;
    final categories = map['categories'] as Map<String, dynamic>;
    final rules = <CategoryRule>[];
    categories.forEach((categoryName, config) {
      final configMap = config as Map<String, dynamic>;
      final keywords =
          (configMap['keywords'] as List<dynamic>).cast<String>();
      rules.add(CategoryRule(
        category: categoryName,
        keywords: keywords,
      ));
    });
    return KeywordClassifier(rules);
  }

  // ── ExpenseClassifier 実装 ────────────────────────

  @override
  ClassificationResult classify(String description) {
    final normalized = normalize(description);
    if (normalized.isEmpty) {
      return ClassificationResult.unmatched();
    }

    // 全カテゴリ・全キーワードを走査してマッチを収集
    final matches = <_KeywordMatch>[];
    for (final rule in _rules) {
      for (final keyword in rule.keywords) {
        if (normalized.contains(keyword)) {
          final confidence = normalized == keyword
              ? Confidence.high
              : Confidence.medium;
          matches.add(_KeywordMatch(
            category: rule.category,
            keyword: keyword,
            confidence: confidence,
            priority: rule.priority,
          ));
        }
      }
    }

    if (matches.isEmpty) {
      return ClassificationResult.unmatched();
    }

    // 最長一致キーワードを優先（同長なら優先度順）
    matches.sort((a, b) {
      final lenCmp = b.keyword.length.compareTo(a.keyword.length);
      if (lenCmp != 0) return lenCmp;
      return b.priority.compareTo(a.priority);
    });

    final best = matches.first;
    final alternatives = matches
        .skip(1)
        .where((m) => m.category != best.category)
        .take(3)
        .map((m) => m.category)
        .toList();

    return ClassificationResult.matched(
      category: best.category,
      confidence: best.confidence,
      matchedRule: best.keyword,
      alternatives: alternatives,
    );
  }

  @override
  List<String> get supportedCategories =>
      _rules.map((r) => r.category).toSet().toList()..sort();

  @override
  String get classifierName => 'KeywordClassifier';
}

// ── 内部ヘルパー ────────────────────────────────────

/// キーワードマッチの中間表現
class _KeywordMatch {
  final String category;
  final String keyword;
  final Confidence confidence;
  final int priority;

  const _KeywordMatch({
    required this.category,
    required this.keyword,
    required this.confidence,
    required this.priority,
  });
}
