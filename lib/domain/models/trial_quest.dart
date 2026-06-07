import 'package:kozuchi/domain/models/guardian_deity.dart';

/// 試練クエスト（週間試練）
///
/// 守護神から発行される週間試練。
/// 受注 → 喜捨実行 → 振り返り → 守護神講評 のサイクルで進行する。
class TrialQuest {
  /// 試練のタイトル
  final String title;

  /// 試練の説明
  final String description;

  /// 喜捨金額の目安（円）
  final int suggestedOffering;

  /// 発行した守護神
  final GuardianDeity guardianDeity;

  /// 実際の喜捨金額（記録後）
  final int? offeringAmount;

  /// 喜捨の用途
  final String? offeringPurpose;

  /// 喜捨の一言メモ
  final String? offeringNote;

  /// 振り返り文
  final String? reflection;

  /// 守護神の講評（モック）
  final String? review;

  /// レシート画像のパス（拡張2: レシート撮影）
  final String? receiptImagePath;

  TrialQuest({
    required this.title,
    required this.description,
    required this.suggestedOffering,
    required this.guardianDeity,
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
      guardianDeity: GuardianDeity.values.firstWhere(
        (d) => d.name == json['guardianDeity'],
        orElse: () => GuardianDeity.daikokuten,
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
      'guardianDeity': guardianDeity.name,
      'offeringAmount': offeringAmount,
      'offeringPurpose': offeringPurpose,
      'offeringNote': offeringNote,
      'reflection': reflection,
      'review': review,
      'receiptImagePath': receiptImagePath,
    };
  }

  /// 喜捨が記録済みか
  bool get isOfferingRecorded => offeringAmount != null;

  /// 振り返りが記録済みか
  bool get isReflectionRecorded => reflection != null && reflection!.isNotEmpty;

  /// クエスト完了状態（喜捨と振り返りの両方が完了）
  bool get isCompleted => isOfferingRecorded && isReflectionRecorded;

  /// 喜捨を記録する
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
      guardianDeity: guardianDeity,
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
      guardianDeity: guardianDeity,
      offeringAmount: offeringAmount,
      offeringPurpose: offeringPurpose,
      offeringNote: offeringNote,
      reflection: text,
      review: review,
      receiptImagePath: receiptImagePath,
    );
  }

  /// 守護神の講評を設定する（モック）
  TrialQuest withReview(String mockReview) {
    return TrialQuest(
      title: title,
      description: description,
      suggestedOffering: suggestedOffering,
      guardianDeity: guardianDeity,
      offeringAmount: offeringAmount,
      offeringPurpose: offeringPurpose,
      offeringNote: offeringNote,
      reflection: reflection,
      review: mockReview,
      receiptImagePath: receiptImagePath,
    );
  }
}
