/// ┌─────────────────────────────────────────────────────────────┐
/// │  支出分類器 インターフェース                                     │
/// │  Expense Classifier Interface — kozuchi                       │
/// │                                                               │
/// │  用途テキスト（purpose）からカテゴリを自動分類するための           │
/// │  抽象基底クラスと関連型。                                        │
/// │                                                               │
/// │  設計方針:                                                     │
/// │  - 消費者（TransactionController 等）は ExpenseClassifier に    │
/// │    のみ依存し、具象実装を知らない                                 │
/// │  - キーワード方式 → LLM 方式への移行をインターフェース変更なしで   │
/// │    行える                                                      │
/// │  - 信頼度（Confidence）を返すことで、フォールバック戦略を         │
/// │    消費者側で制御可能にする                                      │
/// └─────────────────────────────────────────────────────────────┘

// ============================================================
//  型定義
// ============================================================

/// 分類結果の信頼度
///
/// 消費者はこの値を見てフォールバックや確認プロンプトの
/// 出し分けを行うことができる。
enum Confidence {
  /// 高信頼 — キーワード完全一致 / LLM 高確度
  /// 自動適用して問題ない
  high,

  /// 中信頼 — 部分一致 / LLM 中確度
  /// 自動適用するがユーザー確認を推奨
  medium,

  /// 低信頼 — 弱いヒューリスティックマッチ
  /// ユーザー確認が望ましい
  low,

  /// 分類不能 — どのルールにもマッチしなかった
  none,
}

/// 分類結果
///
/// [ExpenseClassifier.classify()] の戻り値。
/// カテゴリ名・信頼度・デバッグ情報をひとまとめにする。
class ClassificationResult {
  /// 分類されたカテゴリ名（例: '食費', '交通', 'その他'）
  final String category;

  /// この分類の信頼度
  final Confidence confidence;

  /// 発火したルール / キーワード（デバッグ・監査用）
  ///
  /// 例: 'マクドナルド', 'keyword_rule:ファストフード'
  /// LLM の場合はプロンプトの要約やモデル名などを入れる。
  final String? matchedRule;

  /// 次点候補カテゴリ（confidence 順、最大 3 件）
  ///
  /// ユーザーに選択肢として提示する用途。
  final List<String> alternatives;

  const ClassificationResult({
    required this.category,
    required this.confidence,
    this.matchedRule,
    this.alternatives = const [],
  });

  /// 分類不能時のファクトリ
  ///
  /// [fallbackCategory] を category に設定し、
  /// confidence = [Confidence.none] で結果を生成する。
  factory ClassificationResult.unmatched({
    String fallbackCategory = 'その他',
    String? reason,
  }) {
    return ClassificationResult(
      category: fallbackCategory,
      confidence: Confidence.none,
      matchedRule: reason ?? 'no rule matched',
    );
  }

  /// 分類成功時の簡易ファクトリ
  factory ClassificationResult.matched({
    required String category,
    Confidence confidence = Confidence.high,
    String? matchedRule,
    List<String> alternatives = const [],
  }) {
    return ClassificationResult(
      category: category,
      confidence: confidence,
      matchedRule: matchedRule,
      alternatives: alternatives,
    );
  }

  // ── ユーティリティ ──────────────────────────────

  /// 十分な信頼度で分類できたか
  bool get isClassified => confidence != Confidence.none;

  /// 高信頼で分類できたか（自動適用可能）
  bool get isHighlyConfident => confidence == Confidence.high;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassificationResult &&
          category == other.category &&
          confidence == other.confidence;

  @override
  int get hashCode => Object.hash(category, confidence);

  @override
  String toString() =>
      'ClassificationResult(category: $category, confidence: $confidence, '
      'matchedRule: $matchedRule, alternatives: $alternatives)';
}

// ============================================================
//  抽象インターフェース
// ============================================================

/// 支出分類器の抽象基底クラス
///
/// すべての分類器実装（キーワード方式・LLM 方式・その他）は
/// このクラスを継承し、[classify] と [supportedCategories] を
/// 実装すること。
///
/// ## 消費者側の使用例
/// ```dart
/// final ExpenseClassifier classifier = getIt<ExpenseClassifier>();
/// final result = classifier.classifyWithFallback('マクドナルド ハンバーガー');
/// transaction.category = result.category; // '食費'
/// ```
///
/// ## 新たな分類器の追加方法
/// 1. [ExpenseClassifier] を継承したクラスを作成
/// 2. [classify] と [supportedCategories] を実装
/// 3. DI コンテナに登録（または手動で注入）
///
/// 消費者側のコード変更は一切不要。
abstract class ExpenseClassifier {
  // ── 具象クラスが実装すべきメソッド ──────────────

  /// 用途テキストからカテゴリを分類する
  ///
  /// [description] には取引の用途テキスト（purpose）を渡す。
  /// 空文字列が渡された場合は [ClassificationResult.unmatched] 相当を返すこと。
  ///
  /// 実装上の注意:
  /// - このメソッドは同期的であるべき。LLM 実装の場合は内部で
  ///   同期 API を使うか、別途 [classifyAsync] をオーバーライドする。
  /// - 例外は投げず、分類不能時は [ClassificationResult.unmatched] を返す。
  ClassificationResult classify(String description);

  /// この分類器がサポートする全カテゴリ名のリスト
  ///
  /// 例: ['食費', '娯楽', '交通', '光熱費', '交際費', 'その他']
  List<String> get supportedCategories;

  // ── デフォルト実装（オーバーライド任意） ─────────

  /// 分類失敗時にフォールバックカテゴリを適用する
  ///
  /// [classify] の結果が [Confidence.none] だった場合に
  /// [fallback] で指定されたカテゴリを返す。
  /// デフォルトは 'その他'。
  ClassificationResult classifyWithFallback(
    String description, {
    String fallback = 'その他',
  }) {
    final result = classify(description);
    if (result.confidence == Confidence.none) {
      return ClassificationResult.unmatched(
        fallbackCategory: fallback,
        reason: result.matchedRule,
      );
    }
    return result;
  }

  /// LLM 実装用の非同期分類（オプション）
  ///
  /// キーワード方式ではオーバーライド不要。
  /// LLM 方式で非同期 API コールが必要な場合に実装する。
  Future<ClassificationResult> classifyAsync(String description) async {
    return classify(description);
  }

  /// 分類器の種類を表す人間可読な名前
  ///
  /// デバッグログや UI 表示に使用。
  String get classifierName => runtimeType.toString();

  /// 初期化処理（オプション）
  ///
  /// キーワード辞書の読込や LLM API キーの検証など。
  /// 分類器を使用する前に一度だけ呼ばれることを想定。
  Future<void> initialize() async {}
}

// ============================================================
//  拡張ポイント（Extension Points）
// ============================================================

/// 分類器の前処理を行うミックスイン
///
/// [classify] が呼ばれる前に description を正規化したい場合に
/// 具象クラスに mixin する。
///
/// ## 使用例
/// ```dart
/// class KeywordClassifier extends ExpenseClassifier with DescriptionNormalizer {
///   // normalize() が自動的に呼ばれる
/// }
/// ```
mixin DescriptionNormalizer on ExpenseClassifier {
  /// テキストの正規化（全角→半角、トリムなど）
  String normalize(String description) {
    return description
        .trim()
        .replaceAll(RegExp(r'[\s　]+'), ' ') // 全角スペース→半角
        .replaceAll('　', ' '); // 全角スペース
  }
}

/// 複数の分類器をチェーンするコンポジット分類器
///
/// 優先度順に分類を試行し、最初に [Confidence.high] 以上を
/// 返した結果を採用する。すべて失敗した場合は最後の結果を返す。
///
/// ## 使用例
/// ```dart
/// final classifier = CompositeClassifier([
///   KeywordClassifier(rules: myRules),   // 高速・高精度なものを先に
///   LLMClassifier(apiKey: key),          // フォールバック
/// ]);
/// ```
class CompositeClassifier extends ExpenseClassifier {
  final List<ExpenseClassifier> _classifiers;

  CompositeClassifier(this._classifiers)
      : assert(_classifiers.isNotEmpty, 'At least one classifier required');

  @override
  List<String> get supportedCategories {
    // 全分類器のカテゴリをマージ（重複除去）
    final all = <String>{};
    for (final c in _classifiers) {
      all.addAll(c.supportedCategories);
    }
    return all.toList()..sort();
  }

  @override
  ClassificationResult classify(String description) {
    ClassificationResult? lastResult;
    for (final classifier in _classifiers) {
      final result = classifier.classify(description);
      lastResult = result;
      if (result.isHighlyConfident) return result;
    }
    return lastResult ?? ClassificationResult.unmatched();
  }

  @override
  Future<ClassificationResult> classifyAsync(String description) async {
    ClassificationResult? lastResult;
    for (final classifier in _classifiers) {
      final result = await classifier.classifyAsync(description);
      lastResult = result;
      if (result.isHighlyConfident) return result;
    }
    return lastResult ?? ClassificationResult.unmatched();
  }

  @override
  String get classifierName =>
      'Composite(${_classifiers.map((c) => c.classifierName).join(' → ')})';
}

// ============================================================
//  キーワード分類器のルール定義用データ型（参考）
// ============================================================

/// キーワード→カテゴリのマッピングルール
///
/// キーワード分類器（KeywordClassifier）の設定ファイル
/// （JSON/YAML）をパースする際の内部表現として使用する。
///
/// ## JSON 設定ファイルの想定形式
/// ```json
/// {
///   "categories": {
///     "食費": {
///       "keywords": ["スーパー", "コンビニ", "レストラン", "マクドナルド"],
///       "priority": 10
///     },
///     "交通": {
///       "keywords": ["Suica", "電車", "バス", "ガソリン", "高速"],
///       "priority": 10
///     }
///   },
///   "fallback_category": "その他",
///   "case_sensitive": false
/// }
/// ```
class CategoryRule {
  /// カテゴリ名
  final String category;

  /// マッチさせるキーワード一覧
  final List<String> keywords;

  /// 優先度（高いほど優先。同名キーワードが複数カテゴリにある場合の解決用）
  final int priority;

  const CategoryRule({
    required this.category,
    required this.keywords,
    this.priority = 10,
  });

  factory CategoryRule.fromJson(Map<String, dynamic> json) {
    return CategoryRule(
      category: json['category'] as String,
      keywords: (json['keywords'] as List).cast<String>(),
      priority: json['priority'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'keywords': keywords,
        'priority': priority,
      };
}
