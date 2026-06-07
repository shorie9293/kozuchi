import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/gaki_zone/presentation/widgets/gaki_zone_warning_banner.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/guardian_deity.dart';

void main() {
  group('GakiZoneWarningBanner', () {
    testWidgets('守護神の絵文字と名前が表示される', (tester) async {
      final player = PlayerModel(
        hp: 25000,
        guardianDeity: GuardianDeity.daikokuten,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GakiZoneWarningBanner(player: player),
          ),
        ),
      );

      // 絵文字と名前が含まれている
      expect(find.textContaining('🪘'), findsOneWidget);
      expect(find.textContaining('大黒天'), findsOneWidget);
      // 警告メッセージが含まれている
      expect(find.textContaining('餓鬼ゾーン'), findsOneWidget);
    });

    testWidgets('異なる守護神でも正しく表示される', (tester) async {
      final player = PlayerModel(
        hp: 15000,
        guardianDeity: GuardianDeity.benzaiten,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GakiZoneWarningBanner(player: player),
          ),
        ),
      );

      expect(find.textContaining('🎵'), findsOneWidget);
      expect(find.textContaining('弁財天'), findsOneWidget);
      expect(find.textContaining('餓鬼ゾーン'), findsOneWidget);
    });

    testWidgets('毘沙門天でも正しく表示される', (tester) async {
      final player = PlayerModel(
        hp: 5000,
        guardianDeity: GuardianDeity.bishamonten,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GakiZoneWarningBanner(player: player),
          ),
        ),
      );

      expect(find.textContaining('⚔️'), findsOneWidget);
      expect(find.textContaining('毘沙門天'), findsOneWidget);
      expect(find.textContaining('餓鬼ゾーン'), findsOneWidget);
    });

    testWidgets('吉祥天でも正しく表示される', (tester) async {
      final player = PlayerModel(
        hp: 10000,
        guardianDeity: GuardianDeity.kisshoten,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GakiZoneWarningBanner(player: player),
          ),
        ),
      );

      expect(find.textContaining('🌸'), findsOneWidget);
      expect(find.textContaining('吉祥天'), findsOneWidget);
      expect(find.textContaining('餓鬼ゾーン'), findsOneWidget);
    });

    testWidgets('守護神未契約でもエラーにならない', (tester) async {
      final player = PlayerModel(
        hp: 20000,
        guardianDeity: null,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GakiZoneWarningBanner(player: player),
          ),
        ),
      );

      // 未契約時はフォールバック表示
      expect(find.textContaining('餓鬼ゾーン'), findsOneWidget);
    });
  });
}
