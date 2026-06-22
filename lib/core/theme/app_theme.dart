import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

class AppTheme {
  /// 高天原共通テーマ（和モダン×金×深紫）を基盤にしたライトテーマ。
  ///
  /// 創造主様より「白い背景に薄い字で見えない」との神託を受け、
  /// テキストの視認性を大幅に改善：
  /// - 本文色: 深紫 (#1A1040) — M3生成の低コントラスト色より格段に視認性向上
  /// - 背景色: 和紙白 (#F5F0E8) — 暖かみある生成り
  /// - サブテキスト色: 金(#D4A038)を基調とした視認性の高い色調
  static ThemeData get light {
    final base = TakamagaharaTheme.light;
    return base.copyWith(
      // kozuchi独自の金銭哲学ゲームらしさを加味
      colorScheme: base.colorScheme.copyWith(
        // サブテキストの視認性を上げる
        onSurfaceVariant: TakamagaharaColors.deepPurple.withValues(alpha: 0.65),
        outline: TakamagaharaColors.deepPurple.withValues(alpha: 0.45),
      ),
      textTheme: base.textTheme.copyWith(
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: TakamagaharaColors.deepPurple.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final base = TakamagaharaTheme.dark;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        onSurfaceVariant: TakamagaharaColors.goldLight.withValues(alpha: 0.7),
        outline: TakamagaharaColors.goldLight.withValues(alpha: 0.4),
      ),
    );
  }
}
