import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/screens/main_screen.dart';
import 'package:kozuchi/core/theme/app_theme.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/level_stage.dart';
import 'package:kozuchi/features/goal_spending/presentation/widgets/goal_spending_gauge.dart';

/// テスト用にMainScreenをラップするヘルパー
Widget wrapMainScreen({PlayerModel? player, ThemeMode? themeMode, IconData? themeIcon, VoidCallback? onToggleTheme}) {
  return MaterialApp(
    home: MainScreen(
      key: AppKeys.mainScreen,
      initialPlayer: player,
      themeMode: themeMode ?? ThemeMode.system,
      themeIcon: themeIcon ?? Icons.brightness_auto,
      onToggleTheme: onToggleTheme,
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-key',
      );
    } catch (_) {}
  });

  group('MainScreen - 裏面モード', () {
    testWidgets('レベルMAX段階で裏面切り替えボタンが表示される', (tester) async {
      // レベルMAX段階のプレイヤー（EXP 100）
      final player = PlayerModel(
        hp: 100000,
        exp: 100,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));
      // 非同期ロードの完了を待つ
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // レベルMAX段階であることを確認
      expect(player.levelStage, LevelStage.kuu);

      // ListViewをスクロールしてボタンを可視化
      await tester.dragUntilVisible(
        find.text('🌌 マスター領域'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('🌌 マスター領域'), findsOneWidget);
    });

    testWidgets('レベルMAX段階未到達では裏面切り替えボタンが表示されない', (tester) async {
      final player = PlayerModel(
        hp: 100000,
        exp: 50,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(player.levelStage, isNot(LevelStage.kuu));
      expect(find.text('🌌 マスター領域'), findsNothing);
    });

    testWidgets('裏面モードに切り替えると支出可視化ツリーが表示される', (tester) async {
      final player = PlayerModel(
        hp: 100000,
        exp: 100,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // ListViewをスクロールしてボタンを可視化
      await tester.dragUntilVisible(
        find.text('🌌 マスター領域'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('🌌 マスター領域'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 支出可視化ツリーが表示される
      expect(find.byKey(const Key('analysisChart')), findsOneWidget);
      expect(find.text('表モードに戻る'), findsOneWidget);
    });

    testWidgets('裏面モードから表モードに戻せる', (tester) async {
      final player = PlayerModel(
        hp: 100000,
        exp: 100,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // ListViewをスクロールしてボタンを可視化
      await tester.dragUntilVisible(
        find.text('🌌 マスター領域'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('🌌 マスター領域'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 表に戻る
      await tester.ensureVisible(find.text('表モードに戻る'));
      await tester.pump();
      await tester.tap(find.text('表モードに戻る'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 裏面ツリーが消える
      expect(find.byKey(const Key('analysisChart')), findsNothing);
      expect(find.text('🌌 マスター領域'), findsOneWidget);
    });

    testWidgets('レベルMAX段階時、表モードではGoalSpendingGaugeが表示される', (tester) async {
      final player = PlayerModel(
        hp: 100000,
        exp: 100,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(GoalSpendingGauge), findsOneWidget);
    });
  });

  group('MainScreen - 表モード', () {
    testWidgets('表モードでGoalSpendingGaugeとEXPゲージが初期表示される', (tester) async {
      final player = PlayerModel();
      await tester.pumpWidget(wrapMainScreen(player: player));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // タブを目標タブに固定（デフォルト）
      expect(find.text('🧘 EXP（悟りゲージ）'), findsOneWidget);
      expect(find.byType(GoalSpendingGauge), findsOneWidget);
    });

    testWidgets('表モードで支出記録FABが表示される', (tester) async {
      final player = PlayerModel(
        hp: 100000,
        exp: 100,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(player.levelStage, LevelStage.kuu);

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      expect(
        find.descendant(
          of: fab,
          matching: find.byIcon(Icons.edit_note),
        ),
        findsOneWidget,
      );
    });

    testWidgets('WidgetKeyが設定されている', (tester) async {
      await tester.pumpWidget(wrapMainScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // AppKeys.mainScreenがScaffoldに設定されている（複数widgetに付与される可能性あり）
      expect(find.byKey(AppKeys.mainScreen), findsWidgets);
    });

    testWidgets('初期プレイヤーのEXP値が正しく表示される', (tester) async {
      final player = PlayerModel(
        hp: 50000,
        exp: 42,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // EXP値42が表示される
      expect(find.text('42'), findsOneWidget);
      expect(find.byType(GoalSpendingGauge), findsOneWidget);
    });

    testWidgets('main screen renders without errors', (tester) async {
      await tester.pumpWidget(wrapMainScreen(player: PlayerModel()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(AppKeys.mainScreen), findsWidgets);
      expect(find.text('打ち出の小槌'), findsOneWidget);
    });
  });

  group('MainScreen - テーマ切替', () {
    testWidgets('onToggleTheme が null の場合トグルボタンが表示されない', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MainScreen(
          onToggleTheme: null,
          initialPlayer: PlayerModel(hp: 100000, exp: 0),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // テーマアイコンは表示されない（全タブを検索）
      expect(find.byIcon(Icons.brightness_auto), findsNothing);
      expect(find.byIcon(Icons.light_mode), findsNothing);
      expect(find.byIcon(Icons.dark_mode), findsNothing);
    });

    testWidgets('onToggleTheme が設定されている場合トグルボタンが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MainScreen(
          onToggleTheme: () {},
          initialPlayer: PlayerModel(hp: 100000, exp: 0),
          themeIcon: Icons.light_mode,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 加護タブ（3番目）にテーマ切替があるのでタブ切替
      await tester.tap(find.text('🛡️ 加護'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.light_mode), findsOneWidget);
    });

    testWidgets('テーマが light の場合 light_mode アイコンが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MainScreen(
          onToggleTheme: () {},
          initialPlayer: PlayerModel(hp: 100000, exp: 0),
          themeMode: ThemeMode.light,
          themeIcon: Icons.light_mode,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('🛡️ 加護'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.light_mode), findsOneWidget);
    });

    testWidgets('テーマが dark の場合 dark_mode アイコンが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MainScreen(
          onToggleTheme: () {},
          initialPlayer: PlayerModel(hp: 100000, exp: 0),
          themeMode: ThemeMode.dark,
          themeIcon: Icons.dark_mode,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('🛡️ 加護'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets('テーマが system の場合 brightness_auto アイコンが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MainScreen(
          onToggleTheme: () {},
          initialPlayer: PlayerModel(hp: 100000, exp: 0),
          themeMode: ThemeMode.system,
          themeIcon: Icons.brightness_auto,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('🛡️ 加護'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.brightness_auto), findsOneWidget);
    });

    testWidgets('トグルボタンタップでコールバックが呼ばれる', (tester) async {
      var called = false;
      await tester.pumpWidget(MaterialApp(
        home: MainScreen(
          onToggleTheme: () => called = true,
          initialPlayer: PlayerModel(hp: 100000, exp: 0),
          themeIcon: Icons.light_mode,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('🛡️ 加護'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // アイコンを可視化してからタップ
      await tester.dragUntilVisible(
        find.byTooltip('テーマ切替'),
        find.byType(ListView).last,
        const Offset(0, -200),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byTooltip('テーマ切替'));
      await tester.pump();
      expect(called, isTrue);
    });

    testWidgets('dark テーマ適用時に描画エラーなく表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: MainScreen(
          onToggleTheme: () {},
          initialPlayer: PlayerModel(hp: 100000, exp: 0),
          themeMode: ThemeMode.dark,
          themeIcon: Icons.dark_mode,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打ち出の小槌'), findsOneWidget);

      // 加護タブに移動してアイコン確認
      await tester.tap(find.text('🛡️ 加護'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });
  });

  group('MainScreen - v2.0 収入記録（残高調整）', () {
    testWidgets('クイックリンクに「収入を記録」が表示される', (tester) async {
      await tester.pumpWidget(
        wrapMainScreen(player: PlayerModel(hp: 50000, exp: 0)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('💰 収入を記録'), findsOneWidget);
    });

    testWidgets('収入を記録するとホームの残高表示が更新される', (tester) async {
      await tester.pumpWidget(
        wrapMainScreen(player: PlayerModel(hp: 50000, exp: 0)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 収入入力画面を開く
      await tester.tap(find.text('💰 収入を記録'));
      await tester.pumpAndSettle();

      // 金額と収入源を入力
      await tester.enterText(
        find.widgetWithText(TextFormField, '収入金額（円）'),
        '30000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '収入源'),
        '給与',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, '収入を記録する'));
      // ホームへ戻る＋SnackBar表示。WashiBackgroundの無限アニメーションがあるため
      // pumpAndSettle はタイムアウトする。明示的な pump ループで状態反映を待つ。
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 残高が加算されてホームに反映されること。
      // HPバーはカンマ区切りで表示するため、「¥80,000」となる。
      expect(find.text('¥80,000'), findsOneWidget);
      // 記録前の残高（¥50,000）はもう表示されない
      expect(find.text('¥50,000'), findsNothing);
    });
  });
}
