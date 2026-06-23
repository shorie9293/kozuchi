import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/screens/main_screen.dart';
import 'package:kozuchi/core/theme/app_theme.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/level_stage.dart';

/// テスト用にMainScreenをラップするヘルパー
Widget wrapMainScreen({PlayerModel? player}) {
  return MaterialApp(
    home: MainScreen(
      key: AppKeys.mainScreen,
      initialPlayer: player,
    ),
  );
}

void main() {
  group('MainScreen - 裏面モード', () {
    testWidgets('レベルMAX段階で裏面切り替えFABが表示される', (tester) async {
      // レベルMAX段階のプレイヤー（EXP 100）
      final player = PlayerModel(
        hp: 100000,
        exp: 100,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));

      // レベルMAX段階であることを確認
      expect(player.levelStage, LevelStage.kuu);

      // Ura mode FABが表示される
      expect(find.byKey(const Key('uraModeFab')), findsOneWidget);
    });

    testWidgets('レベルMAX段階未到達では裏面切り替えFABが表示されない', (tester) async {
      final player = PlayerModel(
        hp: 100000,
        exp: 50, // レベル2段階
      );
      await tester.pumpWidget(wrapMainScreen(player: player));

      // レベルMAX段階未到達
      expect(player.levelStage, isNot(LevelStage.kuu));

      // FABは表示されない
      expect(find.byKey(const Key('uraModeFab')), findsNothing);
    });

    testWidgets('裏面モードに切り替えると支出可視化ツリーとマスター領域ラベルが表示される', (tester) async {
      final player = PlayerModel(
        hp: 100000,
        exp: 100,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));

      // 裏面モードに切り替え
      await tester.tap(find.byKey(const Key('uraModeFab')));
      // pumpAndSettleはAnalysisChartWidgetの繰り返しアニメーションでタイムアウトするためpumpを使用
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // マスター領域ラベルが表示される
      expect(find.byKey(const Key('kuuWorldLabel')), findsOneWidget);

      // 支出可視化ツリーが表示される
      expect(find.byKey(const Key('analysisChart')), findsOneWidget);

      // 表に戻るFABが表示される
      expect(find.byKey(const Key('omoteModeFab')), findsOneWidget);
    });

    testWidgets('裏面モードから表モードに戻せる', (tester) async {
      final player = PlayerModel(
        hp: 100000,
        exp: 100,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));

      // 裏面に切り替え
      await tester.tap(find.byKey(const Key('uraModeFab')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 裏面モード確認
      expect(find.byKey(const Key('kuuWorldLabel')), findsOneWidget);

      // 表に戻るFABが見えるようにスクロール
      await tester.ensureVisible(find.byKey(const Key('omoteModeFab')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 表に戻る
      await tester.tap(find.byKey(const Key('omoteModeFab')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // マスター領域ラベルが消える
      expect(find.byKey(const Key('kuuWorldLabel')), findsNothing);

      // 裏面切り替えFABが再表示
      expect(find.byKey(const Key('uraModeFab')), findsOneWidget);
    });

    testWidgets('レベルMAX段階時、表モードではHPバーが通常表示される', (tester) async {
      final player = PlayerModel(
        hp: 100000,
        exp: 100,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));

      // 表モードではHPバー残高が表示される
      expect(find.text('¥100,000'), findsOneWidget);
    });
  });

  group('MainScreen - 表モード', () {
    testWidgets('表モードでHPバーとEXPゲージが初期表示される', (tester) async {
      // デフォルトプレイヤー（exp=0, hp=100000）
      final player = PlayerModel();
      await tester.pumpWidget(wrapMainScreen(player: player));

      // EXPゲージラベルが表示される
      expect(find.text('🧘 EXP（悟りゲージ）'), findsOneWidget);
      // HPバー残高が表示される
      expect(find.text('¥100,000'), findsOneWidget);
    });

    testWidgets('表モードでクエスト開始FABが表示される', (tester) async {
      // レベルMAX段階のプレイヤー（EXP 100）
      final player = PlayerModel(
        hp: 100000,
        exp: 100,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));

      // レベルMAX段階であることを確認
      expect(player.levelStage, LevelStage.kuu);

      // 表モードでは裏面切り替えFAB（クエスト開始FAB相当）が表示される
      final fab = find.byKey(const Key('uraModeFab'));
      expect(fab, findsOneWidget);
      // FABの中にnights_stayアイコンがある
      expect(
        find.descendant(
          of: fab,
          matching: find.byIcon(Icons.nights_stay),
        ),
        findsOneWidget,
      );
    });

    testWidgets('WidgetKeyが設定されている', (tester) async {
      await tester.pumpWidget(wrapMainScreen());
      // AppKeys.mainScreenがScaffoldに設定されている
      expect(find.byKey(AppKeys.mainScreen), findsOneWidget);
    });

    testWidgets('初期プレイヤーのEXP値が正しく表示される', (tester) async {
      final player = PlayerModel(
        hp: 50000,
        exp: 42,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));

      // EXP値42が表示される
      expect(find.text('42'), findsOneWidget);
      // HPバーに¥50,000が表示される
      expect(find.text('¥50,000'), findsOneWidget);
    });

    testWidgets('main screen renders without errors', (tester) async {
      // デフォルトプレイヤーでエラーなく描画されることを確認
      await tester.pumpWidget(wrapMainScreen(player: PlayerModel()));
      await tester.pump();

      // AppKeys.mainScreenがMainScreenに設定されている（Scaffoldにも同じKeyが設定されているためfindsWidgetsを使用）
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

      expect(find.byKey(const Key('themeToggleButton')), findsNothing);
    });

    testWidgets('onToggleTheme が設定されている場合トグルボタンが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MainScreen(
          onToggleTheme: () {},
          initialPlayer: PlayerModel(hp: 100000, exp: 0),
        ),
      ));

      expect(find.byKey(const Key('themeToggleButton')), findsOneWidget);
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

      expect(find.byIcon(Icons.brightness_auto), findsOneWidget);
    });

    testWidgets('トグルボタンタップでコールバックが呼ばれる', (tester) async {
      var called = false;
      await tester.pumpWidget(MaterialApp(
        home: MainScreen(
          onToggleTheme: () => called = true,
          initialPlayer: PlayerModel(hp: 100000, exp: 0),
        ),
      ));

      await tester.tap(find.byKey(const Key('themeToggleButton')));
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

      // ダークモードでもタイトルが表示されている
      expect(find.text('打ち出の小槌'), findsOneWidget);
      // dark_mode アイコンが表示されている
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });
  });
}
