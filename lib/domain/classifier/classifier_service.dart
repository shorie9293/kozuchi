import 'package:flutter/services.dart' show rootBundle;

import 'package:kozuchi/domain/classifier/classifier_interface.dart';
import 'package:kozuchi/domain/classifier/keyword_classifier.dart';

/// 支出分類サービス
///
/// アセットにバンドルされた keyword_category_map.json を読み込み、
/// [KeywordClassifier] を初期化する。
/// アプリ起動時に一度だけ [initialize] を呼び、以降は [classify] で
/// 用途テキストからカテゴリを自動分類できる。
///
/// ## 使用例
/// ```dart
/// // アプリ起動時
/// await ClassifierService.instance.initialize();
///
/// // 支出記録時
/// final result = ClassifierService.instance.classify('マクドナルドでランチ');
/// // → ClassificationResult(category: '食費', confidence: Confidence.medium)
/// ```
class ClassifierService {
  ClassifierService._();

  static final ClassifierService instance = ClassifierService._();

  KeywordClassifier? _classifier;
  bool _initialized = false;

  /// 分類器が初期化済みか
  bool get isInitialized => _initialized;

  /// サポートする全カテゴリ名
  List<String> get supportedCategories =>
      _classifier?.supportedCategories ?? [];

  /// 分類器を初期化する（アプリ起動時に1回呼ぶ）
  ///
  /// アセットから JSON を読み込み、[KeywordClassifier] を構築する。
  /// [jsonString] が指定された場合はアセットの代わりにそれを使用する
  /// （テスト用）。
  Future<void> initialize({String? jsonString}) async {
    if (_initialized) return;

    final json = jsonString ?? await rootBundle.loadString(
      'assets/keyword_category_map.json',
    );
    _classifier = KeywordClassifier.fromJsonString(json);
    _initialized = true;
  }

  /// 用途テキストからカテゴリを分類する
  ///
  /// [description] には取引の用途テキスト（例: 'コンビニでおにぎり'）を渡す。
  /// 未初期化の場合は [ClassificationResult.unmatched] を返す。
  ClassificationResult classify(String description) {
    if (!_initialized || _classifier == null) {
      return ClassificationResult.unmatched(
        reason: 'classifier not initialized',
      );
    }
    return _classifier!.classify(description);
  }

  /// フォールバック付き分類
  ///
  /// 分類不能時に [fallback] カテゴリを返す。
  ClassificationResult classifyWithFallback(
    String description, {
    String fallback = 'その他',
  }) {
    if (!_initialized || _classifier == null) {
      return ClassificationResult.unmatched(fallbackCategory: fallback);
    }
    return _classifier!.classifyWithFallback(description, fallback: fallback);
  }

  /// テスト用に分類器を直接設定する
  ///
  /// 本番コードでは使用しないこと。
  void setClassifierForTest(KeywordClassifier classifier) {
    _classifier = classifier;
    _initialized = true;
  }

  /// 状態をリセットする（テスト用）
  void reset() {
    _classifier = null;
    _initialized = false;
  }
}
