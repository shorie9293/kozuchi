import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

import 'package:kozuchi/core/widgets/washi_background.dart';
import 'package:kozuchi/core/theme/app_theme.dart';

void main() {
  group('WashiBackground', () {
    testWidgets('light テーマで描画され、子ウィジェットが表示されること', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const WashiBackground(
            child: Text('テスト'),
          ),
        ),
      );

      // 子ウィジェットが表示されている
      expect(find.text('テスト'), findsOneWidget);
    });

    testWidgets('dark テーマで描画され、子ウィジェットが表示されること', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const WashiBackground(
            child: Icon(Icons.star),
          ),
        ),
      );

      // 子ウィジェットが表示されている
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('light/dark テーマ切り替えで再描画され子が維持されること', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const WashiBackground(
            child: Text('切替テスト'),
          ),
        ),
      );

      expect(find.text('切替テスト'), findsOneWidget);

      // dark テーマに切り替え
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const WashiBackground(
            child: Text('切替テスト'),
          ),
        ),
      );
      await tester.pump();

      // 切り替え後も子が表示されている
      expect(find.text('切替テスト'), findsOneWidget);
    });

    testWidgets('dark テーマ切り替え時にエラーなく描画されること', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const WashiBackground(
            child: SizedBox(height: 100),
          ),
        ),
      );

      // light テーマで正常描画（例外なし）
      expect(tester.takeException(), isNull);

      // dark テーマに切り替え
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const WashiBackground(
            child: SizedBox(height: 100),
          ),
        ),
      );
      await tester.pump();

      // dark テーマでも正常描画（例外なし）
      expect(tester.takeException(), isNull);
    });

    testWidgets('ThemeMode.light 指定でTheme.of(context).brightness が light になること', (tester) async {
      Brightness? capturedBrightness;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          home: Builder(
            builder: (context) {
              capturedBrightness = Theme.of(context).brightness;
              return const WashiBackground(
                child: Text('明示的ライト'),
              );
            },
          ),
        ),
      );

      expect(find.text('明示的ライト'), findsOneWidget);
      expect(capturedBrightness, equals(Brightness.light));
    });

    testWidgets('dark テーマのscaffoldBackgroundColorが墨色系であること', (tester) async {
      Color? bgColor;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              bgColor = Theme.of(context).scaffoldBackgroundColor;
              return const Scaffold(
                body: WashiBackground(
                  child: Text('ダークテスト'),
                ),
              );
            },
          ),
        ),
      );

      // テーマのscaffoldBackgroundColorが墨色系（sumiDark）であることを確認
      expect(bgColor, TakamagaharaColors.sumiDark);
      expect(find.text('ダークテスト'), findsOneWidget);
    });

    testWidgets('light テーマのscaffoldBackgroundColorが和紙白であること', (tester) async {
      Color? bgColor;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              bgColor = Theme.of(context).scaffoldBackgroundColor;
              return const Scaffold(
                body: WashiBackground(
                  child: Text('ライトテスト'),
                ),
              );
            },
          ),
        ),
      );

      // テーマのscaffoldBackgroundColorが和紙白であることを確認
      expect(bgColor, TakamagaharaColors.washi);
      expect(find.text('ライトテスト'), findsOneWidget);
    });

    testWidgets('WashiBackground は const コンストラクタを持つこと', (tester) async {
      // const で構築できることの確認（コンパイル時点で保証されるが明示的に）
      const widget = WashiBackground(child: Text('const'));
      expect(widget.child, isA<Text>());
    });
  });
}
