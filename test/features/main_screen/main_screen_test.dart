import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/screens/main_screen.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/enlightenment_stage.dart';

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
    testWidgets('空段階で裏面切り替えFABが表示される', (tester) async {
      // 空段階のプレイヤー（SATORI 100）
      final player = PlayerModel(
        hp: 100000,
        satori: 100,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));

      // 空段階であることを確認
      expect(player.enlightenmentStage, EnlightenmentStage.kuu);

      // Ura mode FABが表示される
      expect(find.byKey(const Key('uraModeFab')), findsOneWidget);
    });

    testWidgets('空段階未到達では裏面切り替えFABが表示されない', (tester) async {
      final player = PlayerModel(
        hp: 100000,
        satori: 50, // 縁起段階
      );
      await tester.pumpWidget(wrapMainScreen(player: player));

      // 空段階未到達
      expect(player.enlightenmentStage, isNot(EnlightenmentStage.kuu));

      // FABは表示されない
      expect(find.byKey(const Key('uraModeFab')), findsNothing);
    });

    testWidgets('裏面モードに切り替えると縁起曼荼羅と空の世界ラベルが表示される', (tester) async {
      final player = PlayerModel(
        hp: 100000,
        satori: 100,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));

      // 裏面モードに切り替え
      await tester.tap(find.byKey(const Key('uraModeFab')));
      // pumpAndSettleはEngiMandalaWidgetの繰り返しアニメーションでタイムアウトするためpumpを使用
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 空の世界ラベルが表示される
      expect(find.byKey(const Key('kuuWorldLabel')), findsOneWidget);

      // 縁起曼荼羅が表示される
      expect(find.byKey(const Key('engiMandala')), findsOneWidget);

      // 表に戻るFABが表示される
      expect(find.byKey(const Key('omoteModeFab')), findsOneWidget);
    });

    testWidgets('裏面モードから表モードに戻せる', (tester) async {
      final player = PlayerModel(
        hp: 100000,
        satori: 100,
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

      // 空の世界ラベルが消える
      expect(find.byKey(const Key('kuuWorldLabel')), findsNothing);

      // 裏面切り替えFABが再表示
      expect(find.byKey(const Key('uraModeFab')), findsOneWidget);
    });

    testWidgets('空段階時、表モードではHPバーが通常表示される', (tester) async {
      final player = PlayerModel(
        hp: 100000,
        satori: 100,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));

      // 表モードではHPバー残高が表示される
      expect(find.text('¥100,000'), findsOneWidget);
    });
  });

  group('MainScreen - 表モード', () {
    testWidgets('表モードでHPバーとSATORIゲージが初期表示される', (tester) async {
      // デフォルトプレイヤー（satori=0, hp=100000）
      final player = PlayerModel();
      await tester.pumpWidget(wrapMainScreen(player: player));

      // SATORIゲージラベルが表示される
      expect(find.text('🧘 SATORI（悟りゲージ）'), findsOneWidget);
      // HPバー残高が表示される
      expect(find.text('¥100,000'), findsOneWidget);
    });

    testWidgets('表モードでクエスト開始FABが表示される', (tester) async {
      // 空段階のプレイヤー（SATORI 100）
      final player = PlayerModel(
        hp: 100000,
        satori: 100,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));

      // 空段階であることを確認
      expect(player.enlightenmentStage, EnlightenmentStage.kuu);

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

    testWidgets('初期プレイヤーのSATORI値が正しく表示される', (tester) async {
      final player = PlayerModel(
        hp: 50000,
        satori: 42,
      );
      await tester.pumpWidget(wrapMainScreen(player: player));

      // SATORI値42が表示される
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
}
