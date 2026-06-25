import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/pinch_zone/presentation/widgets/pinch_zone_warning_banner.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/advisor.dart';

void main() {
  group('PinchZoneWarningBanner', () {
    testWidgets('アドバイザーの絵文字と名前が表示される', (tester) async {
      final player = PlayerModel(
        hp: 25000,
        advisor: Advisor.daikokuten,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinchZoneWarningBanner(player: player),
          ),
        ),
      );

      // 絵文字と名前が含まれている
      expect(find.textContaining('🪘'), findsOneWidget);
      expect(find.textContaining('大黒天'), findsOneWidget);
      // 警告メッセージが含まれている
      expect(find.textContaining('ピンチゾーン'), findsOneWidget);
    });

    testWidgets('異なるアドバイザーでも正しく表示される', (tester) async {
      final player = PlayerModel(
        hp: 15000,
        advisor: Advisor.benzaiten,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinchZoneWarningBanner(player: player),
          ),
        ),
      );

      expect(find.textContaining('🎵'), findsOneWidget);
      expect(find.textContaining('弁財天'), findsOneWidget);
      expect(find.textContaining('ピンチゾーン'), findsOneWidget);
    });

    testWidgets('毘沙門天でも正しく表示される', (tester) async {
      final player = PlayerModel(
        hp: 5000,
        advisor: Advisor.bishamonten,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinchZoneWarningBanner(player: player),
          ),
        ),
      );

      expect(find.textContaining('⚔️'), findsOneWidget);
      expect(find.textContaining('毘沙門天'), findsOneWidget);
      expect(find.textContaining('ピンチゾーン'), findsOneWidget);
    });

    testWidgets('吉祥天でも正しく表示される', (tester) async {
      final player = PlayerModel(
        hp: 10000,
        advisor: Advisor.kichijoten,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinchZoneWarningBanner(player: player),
          ),
        ),
      );

      expect(find.textContaining('🌸'), findsOneWidget);
      expect(find.textContaining('吉祥天'), findsOneWidget);
      expect(find.textContaining('ピンチゾーン'), findsOneWidget);
    });

    testWidgets('アドバイザー未契約でもエラーにならない', (tester) async {
      final player = PlayerModel(
        hp: 20000,
        advisor: null,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinchZoneWarningBanner(player: player),
          ),
        ),
      );

      // 未契約時はフォールバック表示
      expect(find.textContaining('ピンチゾーン'), findsOneWidget);
    });
  });
}
