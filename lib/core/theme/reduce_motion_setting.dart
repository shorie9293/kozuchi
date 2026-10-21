import 'package:flutter/material.dart';

/// 動きを減らす（Reduce Motion）設定の3択。
///
/// 端末のアクセシビリティ設定（`MediaQuery.disableAnimations`）に対する
/// アプリ内の上書き方針を表す。
/// - [system]: 端末設定に従う（上書きしない）
/// - [off]: 利用者が明示的に動きを有効化する（端末設定より優先）
/// - [on]: 利用者が明示的に動きを減らす（端末設定より優先）
///
/// WCAG 2.3.3（インタラクションによるアニメーション）への配慮として、
/// アプリ全体の [MediaQueryData.disableAnimations] を切り替える。
enum ReduceMotionSetting {
  system('system', 'システムに従う', Icons.brightness_auto_outlined),
  off('off', '動きを有効', Icons.animation),
  on('on', '動きを減らす', Icons.motion_photos_off_outlined);

  const ReduceMotionSetting(this.storageKey, this.label, this.icon);

  /// SharedPreferences に保存する識別子
  final String storageKey;

  /// 画面表示用ラベル
  final String label;

  /// 画面表示用アイコン
  final IconData icon;

  /// 保存キー文字列から設定を復元する。未知キー・null は [system]。
  static ReduceMotionSetting fromStorageKey(String? key) {
    for (final value in values) {
      if (value.storageKey == key) return value;
    }
    return system;
  }

  /// 次の設定（system → off → on → system）
  ReduceMotionSetting get next => switch (this) {
        ReduceMotionSetting.system => ReduceMotionSetting.off,
        ReduceMotionSetting.off => ReduceMotionSetting.on,
        ReduceMotionSetting.on => ReduceMotionSetting.system,
      };

  /// 強制する `disableAnimations` 値。
  ///
  /// [on] は true、[off] は false（利用者が明示的に動きを有効化＝端末設定より優先）、
  /// [system] は null（端末設定を尊重し上書きしない）。
  bool? get forceDisableAnimations => switch (this) {
        ReduceMotionSetting.system => null,
        ReduceMotionSetting.off => false,
        ReduceMotionSetting.on => true,
      };
}

/// [MediaQueryData] に Reduce Motion 設定を適用する。
///
/// [ReduceMotionSetting.forceDisableAnimations] が null（= system）の場合は
/// [data] をそのまま返し、端末設定を一切変更しない。
MediaQueryData applyReduceMotion(
  MediaQueryData data,
  ReduceMotionSetting setting,
) {
  final forced = setting.forceDisableAnimations;
  if (forced == null) return data;
  return data.copyWith(disableAnimations: forced);
}
