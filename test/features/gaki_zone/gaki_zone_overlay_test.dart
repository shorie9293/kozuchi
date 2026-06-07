import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/gaki_zone/presentation/widgets/gaki_zone_overlay.dart';

void main() {
  group('GakiZoneOverlay', () {
    testWidgets('isGakiState=true でColorFilteredが適用される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GakiZoneOverlay(
              isGakiState: true,
              child: const Text('テスト子Widget'),
            ),
          ),
        ),
      );

      // ColorFiltered widget が存在する
      expect(find.byType(ColorFiltered), findsOneWidget);
      // 子Widgetも表示される
      expect(find.text('テスト子Widget'), findsOneWidget);
    });

    testWidgets('isGakiState=false でColorFilteredが存在しない', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GakiZoneOverlay(
              isGakiState: false,
              child: const Text('テスト子Widget'),
            ),
          ),
        ),
      );

      // ColorFiltered widget が存在しない
      expect(find.byType(ColorFiltered), findsNothing);
      // 子Widgetは表示される
      expect(find.text('テスト子Widget'), findsOneWidget);
    });

    testWidgets('isGakiState=true でヴィネットStackが存在する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GakiZoneOverlay(
              isGakiState: true,
              child: const Text('テスト子Widget'),
            ),
          ),
        ),
      );

      // 名前付きStack (ヴィネットラッパー) が存在する
      expect(find.byKey(const Key('gaki_zone_vignette_stack')), findsOneWidget);
      // 名前付きCustomPaint (ヴィネット) が存在する
      expect(find.byKey(const Key('gaki_zone_vignette')), findsOneWidget);
    });

    testWidgets('isGakiState=false でヴィネットStackが存在しない', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GakiZoneOverlay(
              isGakiState: false,
              child: const Text('テスト子Widget'),
            ),
          ),
        ),
      );

      // 名前付きStack (ヴィネットラッパー) が存在しない
      expect(find.byKey(const Key('gaki_zone_vignette_stack')), findsNothing);
      // 名前付きCustomPaint (ヴィネット) が存在しない
      expect(find.byKey(const Key('gaki_zone_vignette')), findsNothing);
    });
  });
}
