import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/features/careerCoach/data/careerCoach_book_bonus_service.dart';
import 'package:kozuchi/features/trial_quest/domain/ai_review_service.dart';

/// キャリアコーチ（弁財天アドバイザー）講評の入力データ
///
/// 週次の家計・支出・蔵書ボーナス・守護神状態に基づいて講評を生成するための
/// 入力値を束ねる。
class CareerCoachReviewData {
  /// 今週の支出合計（円）
  final int weeklyExpenditure;

  /// 今週の収入合計（円）
  final int weeklyIncome;

  /// 今月の支出合計（円）
  final int monthlyExpenditure;

  /// 蔵書追加ボーナス（あれば）
  final CareerCoachBonusResult? bookBonus;

  /// 契約中の守護神（既定は弁財天）
  final Advisor guardian;

  const CareerCoachReviewData({
    required this.weeklyExpenditure,
    required this.weeklyIncome,
    required this.monthlyExpenditure,
    this.bookBonus,
    this.guardian = Advisor.benzaiten,
  });

  /// 今週の収支（+が黒字、-が赤字）
  int get balance => weeklyIncome - weeklyExpenditure;

  /// 黒字かどうか
  bool get isSaving => balance >= 0;

  /// 収入に対する黒字比率（0.0〜1.0）。赤字時は 0.0。
  double get savingRatio {
    if (weeklyIncome <= 0) return 0.0;
    return (balance / weeklyIncome).clamp(0.0, 1.0);
  }
}

/// キャリアコーチ講評の結果
class CareerCoachReview {
  /// アドバイザーによる講評文
  final String reviewText;

  /// EXP倍率（0.5〜2.0）
  final double expMultiplier;

  /// 今週の収支が黒字かどうか
  final bool isSaving;

  /// 今週の収支額（円）
  final int balance;

  /// 蔵書追加ボーナスの本のタイトル（あれば）
  final String? bookTitle;

  const CareerCoachReview({
    required this.reviewText,
    required this.expMultiplier,
    required this.isSaving,
    required this.balance,
    this.bookTitle,
  });
}

/// キャリアコーチ講評サービスの抽象インターフェース
///
/// Mock / DeepSeek などの切り替えを可能にする。
abstract class CareerCoachReviewService {
  /// [data] に基づいてキャリアコーチ講評を生成する
  Future<CareerCoachReview> generateReview(CareerCoachReviewData data);
}

/// 既存の AI 講評基盤（[AiReviewService]）を流用したキャリアコーチ講評サービス
///
/// [AiReviewService] を注入することで Mock / DeepSeek を切り替えられる。
/// AI 呼び出しが失敗した場合はローカルのフォールバック講評を返す。
class AiCareerCoachReviewService implements CareerCoachReviewService {
  final AiReviewService _aiReviewService;

  AiCareerCoachReviewService(this._aiReviewService);

  /// 講評生成のための振り返り文を構築する（パブリック：テスト用）
  String buildReflection(CareerCoachReviewData data) {
    final buf = StringBuffer();
    buf.writeln('今週の支出は ${data.weeklyExpenditure}円、収入は ${data.weeklyIncome}円である。');
    buf.writeln('収支は ${data.balance}円（${data.isSaving ? '黒字' : '赤字'}）である。');
    if (data.bookBonus != null) {
      buf.writeln('また「${data.bookBonus!.bookTitle}」という本を読み、蔵書を増やした。');
    }
    buf.write('契約中の守護神は${data.guardian.label}である。');
    return buf.toString();
  }

  @override
  Future<CareerCoachReview> generateReview(CareerCoachReviewData data) async {
    try {
      final aiResult = await _aiReviewService.generateReview(
        deity: data.guardian,
        reflection: buildReflection(data),
        offeringAmount: data.weeklyExpenditure,
        offeringPurpose: '週次キャリアコーチ相談',
      );
      return CareerCoachReview(
        reviewText: aiResult.reviewText,
        expMultiplier: aiResult.expMultiplier,
        isSaving: data.isSaving,
        balance: data.balance,
        bookTitle: data.bookBonus?.bookTitle,
      );
    } catch (_) {
      return fallbackReview(data);
    }
  }

  /// AI 呼び出し失敗時のフォールバック講評
  CareerCoachReview fallbackReview(CareerCoachReviewData data) {
    final advice =
        data.isSaving ? '実直に家計を守るを良しとす' : 'されど支出が収入を上回り、赤字である。来週は費えを見直せ';
    return CareerCoachReview(
      reviewText: '${data.guardian.label}「今週の家計、よく眺めたわ。$advice。」',
      expMultiplier: 1.0,
      isSaving: data.isSaving,
      balance: data.balance,
      bookTitle: data.bookBonus?.bookTitle,
    );
  }
}

/// AI を使わない決定論的な講評サービス（テスト・オフライン用）
class MockCareerCoachReviewService implements CareerCoachReviewService {
  @override
  Future<CareerCoachReview> generateReview(CareerCoachReviewData data) async {
    final advice = data.isSaving
        ? '支出が収入の範囲に収まり、よく家計を守った。来週も継続せよ。'
        : '支出が収入を上回っている。来週は費えの見直しを勧める。';
    return CareerCoachReview(
      reviewText: '${data.guardian.label}「$advice」',
      expMultiplier: data.isSaving ? 1.2 : 0.8,
      isSaving: data.isSaving,
      balance: data.balance,
      bookTitle: data.bookBonus?.bookTitle,
    );
  }
}
