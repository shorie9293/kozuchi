import 'package:kozuchi/domain/models/advisor.dart';

/// 試練クエスト（週間試練）
///
/// アドバイザーから発行される週間試練。
/// 受注 → 支出実行 → 振り返り → アドバイザー講評 のサイクルで進行する。
class TrialQuest {
  /// 試練のタイトル
  final String title;

  /// 試練の説明
  final String description;

  /// 支出金額の目安（円）
  final int suggestedOffering;

  /// 発行したアドバイザー
  final Advisor advisor;

  /// 実際の支出金額（記録後）
  final int? offeringAmount;

  /// 支出の用途
  final String? offeringPurpose;

  /// 支出の一言メモ
  final String? offeringNote;

  /// 振り返り文
  final String? reflection;

  /// アドバイザーの講評（モック）
  final String? review;

  /// レシート画像のパス（拡張2: レシート撮影）
  final String? receiptImagePath;

  TrialQuest({
    required this.title,
    required this.description,
    required this.suggestedOffering,
    required this.advisor,
    this.offeringAmount,
    this.offeringPurpose,
    this.offeringNote,
    this.reflection,
    this.review,
    this.receiptImagePath,
  });

  /// JSONから復元
  factory TrialQuest.fromJson(Map<String, dynamic> json) {
    return TrialQuest(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      suggestedOffering: json['suggestedOffering'] as int? ?? 0,
      advisor: Advisor.values.firstWhere(
        (d) => d.name == json['advisor'],
        orElse: () => Advisor.lifePlanner,
      ),
      offeringAmount: json['offeringAmount'] as int?,
      offeringPurpose: json['offeringPurpose'] as String?,
      offeringNote: json['offeringNote'] as String?,
      reflection: json['reflection'] as String?,
      review: json['review'] as String?,
      receiptImagePath: json['receiptImagePath'] as String?,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'suggestedOffering': suggestedOffering,
      'advisor': advisor.name,
      'offeringAmount': offeringAmount,
      'offeringPurpose': offeringPurpose,
      'offeringNote': offeringNote,
      'reflection': reflection,
      'review': review,
      'receiptImagePath': receiptImagePath,
    };
  }

  /// 支出が記録済みか
  bool get isOfferingRecorded => offeringAmount != null;

  /// 振り返りが記録済みか
  bool get isReflectionRecorded => reflection != null && reflection!.isNotEmpty;

  /// クエスト完了状態（支出と振り返りの両方が完了）
  bool get isCompleted => isOfferingRecorded && isReflectionRecorded;

  /// 支出を記録する
  TrialQuest recordOffering({
    required int amount,
    required String purpose,
    String note = '',
    String? receiptImagePath,
  }) {
    return TrialQuest(
      title: title,
      description: description,
      suggestedOffering: suggestedOffering,
      advisor: advisor,
      offeringAmount: amount,
      offeringPurpose: purpose,
      offeringNote: note,
      reflection: reflection,
      review: review,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
    );
  }

  /// 振り返りを記録する
  TrialQuest recordReflection(String text) {
    return TrialQuest(
      title: title,
      description: description,
      suggestedOffering: suggestedOffering,
      advisor: advisor,
      offeringAmount: offeringAmount,
      offeringPurpose: offeringPurpose,
      offeringNote: offeringNote,
      reflection: text,
      review: review,
      receiptImagePath: receiptImagePath,
    );
  }

  /// アドバイザーの講評を設定する（モック）
  TrialQuest withReview(String mockReview) {
    return TrialQuest(
      title: title,
      description: description,
      suggestedOffering: suggestedOffering,
      advisor: advisor,
      offeringAmount: offeringAmount,
      offeringPurpose: offeringPurpose,
      offeringNote: offeringNote,
      reflection: reflection,
      review: mockReview,
      receiptImagePath: receiptImagePath,
    );
  }
}
