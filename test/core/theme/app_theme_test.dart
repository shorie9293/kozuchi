import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    });

    group('dark theme', () {
      test('brightness が dark であること', () {
        expect(AppTheme.dark.brightness, equals(Brightness.dark));
      });
    });

    group('共通設定', () {
      test('両テーマとも colorSchemeSeed が Colors.indigo であること', () {
        const seedColor = Colors.indigo;
        final expectedLightScheme =
            ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light);
        final expectedDarkScheme =
            ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark);

        expect(AppTheme.light.colorScheme, equals(expectedLightScheme));
        expect(AppTheme.dark.colorScheme, equals(expectedDarkScheme));
      });

      test('両テーマとも useMaterial3 が true であること', () {
        expect(AppTheme.light.useMaterial3, isTrue);
        expect(AppTheme.dark.useMaterial3, isTrue);
      });
    });
  });
}
