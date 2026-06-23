import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 打ち出の小槌（kozuchi）のテーマ定義
///
/// 高天原共通テーマ（和モダン×金×深紫）を基盤に、
/// kozuchi独自の金銭哲学ゲームらしさを加味。
///
/// ライトテーマ：和紙白(#F5F0E8)基調 × 金アクセント
/// ダークテーマ：墨色(#1A1A2E)基調 × 薄金アクセント（創造主様指定）
class AppTheme {
  /// ライトテーマ — 創造主様「白い背景に薄い字で見えない」の神託を反映
  static ThemeData get light {
    final base = TakamagaharaTheme.light;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        // サブテキストの視認性を深紫65%に確保
        onSurfaceVariant: TakamagaharaColors.textSecondaryLight,
        // アウトライン: 深紫30% → さらに強い45%に
        outline: TakamagaharaColors.deepPurple.withValues(alpha: 0.45),
      ),
      textTheme: base.textTheme.copyWith(
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: TakamagaharaColors.deepPurple.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  /// ダークテーマ — 墨色基調 × 金アクセント
  ///
  /// 墨色(#1A1A2E) × 金箔アクセントの夜桜・星空を想起する配色。
  /// 全コンポーネントが ColorScheme 経由でトークンを参照する。
  static ThemeData get dark {
    final base = TakamagaharaTheme.dark;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        // 補足テキスト: 薄金60%
        onSurfaceVariant: TakamagaharaColors.textSecondaryDark,
        // アウトライン: 薄金40%
        outline: TakamagaharaColors.goldLight.withValues(alpha: 0.40),
      ),
      // カードのデフォルト色を墨色+ に
      cardTheme: CardThemeData(
        color: TakamagaharaColors.surfaceCardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: TakamagaharaColors.goldLight.withValues(alpha: 0.12),
          ),
        ),
      ),
      // AppBar のデフォルト色を墨色に
      appBarTheme: const AppBarTheme(
        backgroundColor: TakamagaharaColors.sumiDark,
        foregroundColor: TakamagaharaColors.goldLight,
        elevation: 0,
      ),
      // 入力フィールド
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TakamagaharaColors.surfaceInputDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: TakamagaharaColors.goldLight.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}
