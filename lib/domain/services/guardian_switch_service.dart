import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/domain/models/player_model.dart';

/// 守護神切替のエラー種別
enum GuardianSwitchError {
  /// EXPが不足している
  insufficientExp,

  /// クールダウン中（7日経過していない）
  inCooldown,

  /// すでに同じ守護神と契約している
  alreadyContracted,

  /// 現在契約中の守護神がいない（切替不可）
  noActiveGuardian,
}

/// 守護神切替の結果
///
/// 成功時は [player] [newAdvisor] [remainingCooldown] を持つ。
/// 失敗時は [error] を持つ。
class GuardianSwitchResult {
  /// 切替後のプレイヤー（成功時のみ非null）
  final PlayerModel? player;

  /// 新しい守護神（成功時のみ非null）
  final Advisor? newAdvisor;

  /// クールダウン残り時間（成功時のみ非null、常に7日）
  final Duration? remainingCooldown;

  /// エラー（失敗時のみ非null）
  final GuardianSwitchError? error;

  const GuardianSwitchResult._success({
    required this.player,
    required this.newAdvisor,
    required this.remainingCooldown,
  }) : error = null;

  const GuardianSwitchResult._failure({
    required this.error,
  })  : player = null,
        newAdvisor = null,
        remainingCooldown = null;

  /// 成功したかどうか
  bool get isSuccess => error == null;

  /// 成功結果を生成
  factory GuardianSwitchResult.success({
    required PlayerModel player,
    required Advisor newAdvisor,
    required Duration remainingCooldown,
  }) {
    return GuardianSwitchResult._success(
      player: player,
      newAdvisor: newAdvisor,
      remainingCooldown: remainingCooldown,
    );
  }

  /// 失敗結果を生成
  factory GuardianSwitchResult.failure(GuardianSwitchError error) {
    return GuardianSwitchResult._failure(error: error);
  }
}

/// 守護神切替サービス
///
/// プレイヤーのEXP消費・クールダウン検証を行い、
/// 守護神（アドバイザー）の切り替えを実行する。
class GuardianSwitchService {
  /// 切替に必要なEXP消費量（設定可能）
  final int expCost;

  /// クールダウン期間（設定可能、デフォルト7日）
  final Duration cooldownDuration;

  const GuardianSwitchService({
    this.expCost = PlayerModel.switchExpCost,
    this.cooldownDuration = PlayerModel.switchCooldownDuration,
  });

  /// 守護神を切り替える
  ///
  /// [player] の現在の守護神から [newAdvisor] に切り替える。
  /// EXP消費・クールダウン検証を行い、成功時は新しいプレイヤー状態を返す。
  GuardianSwitchResult switchGuardian(
    PlayerModel player,
    Advisor newAdvisor,
  ) {
    // 1. 現在の守護神がいなければ切替不可
    if (player.advisor == null) {
      return GuardianSwitchResult.failure(
        GuardianSwitchError.noActiveGuardian,
      );
    }

    // 2. 同じ守護神なら切替不要（エラー）
    if (player.advisor == newAdvisor) {
      return GuardianSwitchResult.failure(
        GuardianSwitchError.alreadyContracted,
      );
    }

    // 3. クールダウン中なら切替不可
    if (player.isInCooldown) {
      return GuardianSwitchResult.failure(
        GuardianSwitchError.inCooldown,
      );
    }

    // 4. EXP不足なら切替不可
    if (player.exp < expCost) {
      return GuardianSwitchResult.failure(
        GuardianSwitchError.insufficientExp,
      );
    }

    // 5. 切替実行
    final updatedPlayer = player.switchAdvisor(newAdvisor, expCost: expCost);

    return GuardianSwitchResult.success(
      player: updatedPlayer,
      newAdvisor: newAdvisor,
      // 切替直後のクールダウン残り時間は常に cooldownDuration
      remainingCooldown: cooldownDuration,
    );
  }
}
