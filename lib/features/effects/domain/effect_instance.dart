import 'package:flutter/material.dart';
import 'effect_definition.dart';

/// 実行中のエフェクトインスタンス
///
/// [EffectManager] が管理する、現在再生中のエフェクト1つを表す。
/// [startTime] からの経過時間が [definition.duration] を超えると [isExpired] になる。
class EffectInstance {
  /// ユニークインスタンスID
  final String id;

  /// エフェクト定義
  final EffectDefinition definition;

  /// エフェクトの表示位置（画面座標、isFullScreen時は無視）
  final Offset position;

  /// エフェクト開始時刻
  final DateTime startTime;

  EffectInstance({
    required this.id,
    required this.definition,
    required this.position,
    DateTime? startTime,
  }) : startTime = startTime ?? DateTime.now();

  /// 期間を過ぎて期限切れかどうか
  bool get isExpired =>
      DateTime.now().difference(startTime) >= definition.duration;

  /// 経過時間
  Duration get elapsed => DateTime.now().difference(startTime);

  /// 残り時間（期限切れの場合はDuration.zero）
  Duration get remaining {
    final diff = definition.duration - elapsed;
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  String toString() =>
      'EffectInstance(id: $id, name: ${definition.name}, pos: $position, expired: $isExpired)';
}
