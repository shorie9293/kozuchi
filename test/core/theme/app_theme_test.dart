import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

import 'package:kozuchi/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    group('light theme', () {
      test('Material3 を使用していること', () {
        expect(AppTheme.light.useMaterial3, isTrue);
      });

      test('brightness が light であること', () {
        expect(AppTheme.light.brightness, equals(Brightness.light));
      });

      test('高天原共通テーマをベースにしていること', () {
        final theme = AppTheme.light;
        expect(theme.primaryColor, TakamagaharaColors.gold);
        expect(theme.scaffoldBackgroundColor, TakamagaharaColors.washi);
      });

      test('サブテキスト色が視認性の高い深紫系であること', () {
        final theme = AppTheme.light;
        // onSurfaceVariant は深紫を65%の透明度で使用 → 濃く視認性が高い（5.4:1 / AA）
        expect(theme.colorScheme.onSurfaceVariant,
            equals(TakamagaharaColors.deepPurple.withValues(alpha: 0.65)));
        // outline も深紫45%
        expect(theme.colorScheme.outline,
            equals(TakamagaharaColors.deepPurple.withValues(alpha: 0.45)));
        // bodySmall も深紫80%で AA（約9:1）を担保
        expect(theme.textTheme.bodySmall?.color,
            equals(TakamagaharaColors.deepPurple.withValues(alpha: 0.80)));
      });

      test('キャプション等の細字が AA 相当の視認性であること', () {
        final light = AppTheme.light;
        final dark = AppTheme.dark;
        // ライト: 深紫80% → 和紙白背景で約9:1
        expect(light.textTheme.bodySmall?.color,
            equals(TakamagaharaColors.deepPurple.withValues(alpha: 0.80)));
        // ダーク: 薄金75% → 墨色背景で約6.5:1（AA 本文相当）
        expect(dark.textTheme.bodySmall?.color,
            equals(TakamagaharaColors.goldLight.withValues(alpha: 0.75)));
      });
    });

    group('dark theme', () {
      test('brightness が dark であること', () {
        expect(AppTheme.dark.brightness, equals(Brightness.dark));
      });

      test('サブテキスト(onSurfaceVariant)が薄金75%で AA を担保していること', () {
        final theme = AppTheme.dark;
        // 共有トークン textSecondaryDark(0.60/4.6:1) はギリギリのため、
        // kozuchi では 0.75（6.5:1 / AA）に引き上げ。
        expect(theme.colorScheme.onSurfaceVariant,
            equals(TakamagaharaColors.goldLight.withValues(alpha: 0.75)));
        expect(theme.colorScheme.outline,
            equals(TakamagaharaColors.goldLight.withValues(alpha: 0.40)));
      });
    });

    group('共通設定', () {
      test('両テーマとも useMaterial3 が true であること', () {
        expect(AppTheme.light.useMaterial3, isTrue);
        expect(AppTheme.dark.useMaterial3, isTrue);
      });
    });
  });
}
