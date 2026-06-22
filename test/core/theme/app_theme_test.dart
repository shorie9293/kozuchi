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
        // onSurfaceVariant は深紫を65%の透明度で使用 → 濃く視認性が高い
        expect(theme.colorScheme.onSurfaceVariant,
            equals(TakamagaharaColors.deepPurple.withValues(alpha: 0.65)));
        // outline も深紫45%
        expect(theme.colorScheme.outline,
            equals(TakamagaharaColors.deepPurple.withValues(alpha: 0.45)));
      });
    });

    group('dark theme', () {
      test('brightness が dark であること', () {
        expect(AppTheme.dark.brightness, equals(Brightness.dark));
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
