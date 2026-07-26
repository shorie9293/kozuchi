import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 打ち出の小槌（kozuchi）のテーマ定義
///
/// 高天原共通テーマ（和モダン×金×深紫）を基盤に、
/// kozuchi独自の金銭哲学ゲームらしさを加味。
///
/// ライトテーマ：和紙白(#F5F0E8)基調 × 金アクセント
/// ダークテーマ：墨色(#1A1A2E)基調 × 薄金アクセント（創造主様指定）
///
/// 視認性（アクセシビリティ）ポリシー — WCAG 2.1 AA 準拠
/// 創造主様「白い背景に薄い字で見えない」の神託に基づき、本文相当の
/// テキストは全てコントラスト比 4.5:1 以上（本文）を担保する。
/// 監査結果（背景との比 / 評価）:
///   ライト本文 deepPurple    15.5:1 AAA
///   ライト補足 deepPurple@0.65  5.4:1 AA
///   ダーク本文 goldLight    10.7:1 AAA
///   ダーク補足 goldLight@0.75  6.5:1 AA  (※@0.60 は 4.6:1 でギリギリのため 0.75 に引上げ)
///   非推奨: textTertiaryLight@0.35(2.2:1) / textTertiaryDark@0.35(2.4:1) は AA 不適合。
class AppTheme {
  /// ライトテーマ — 創造主様「白い背景に薄い字で見えない」の神託を反映
  static ThemeData get light {
    final base = TakamagaharaTheme.light;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        // サブテキストの視認性を深紫65%に確保（5.4:1 / AA）
        onSurfaceVariant: TakamagaharaColors.textSecondaryLight,
        // アウトライン: 深紫45%
        outline: TakamagaharaColors.deepPurple.withValues(alpha: 0.45),
      ),
      textTheme: base.textTheme.copyWith(
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: TakamagaharaColors.deepPurple.withValues(alpha: 0.85),
        ),
        // キャプション等の細字も深紫80%で AA（約9:1）を担保
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: TakamagaharaColors.deepPurple.withValues(alpha: 0.80),
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
        // 補足テキスト: 薄金75%（6.5:1 / AA）。共有トークンの
        // textSecondaryDark(0.60 / 4.6:1) はギリギリのため kozuchi では
        // 0.75 に引き上げ、視認性を確実にする。
        onSurfaceVariant: TakamagaharaColors.goldLight.withValues(alpha: 0.75),
        // アウトライン: 薄金40%
        outline: TakamagaharaColors.goldLight.withValues(alpha: 0.40),
      ),
      textTheme: base.textTheme.copyWith(
        // キャプション等の細字も薄金75%で AA（6.5:1）を担保
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: TakamagaharaColors.goldLight.withValues(alpha: 0.75),
        ),
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
