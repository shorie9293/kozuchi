import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/pinch_zone/presentation/widgets/pinch_zone_overlay.dart';

void main() {
  group('PinchZoneOverlay', () {
    testWidgets('isPinchState=true でColorFilteredが適用される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinchZoneOverlay(
              isPinchState: true,
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

    testWidgets('isPinchState=false でColorFilteredが存在しない', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinchZoneOverlay(
              isPinchState: false,
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

    testWidgets('isPinchState=true でヴィネットStackが存在する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinchZoneOverlay(
              isPinchState: true,
              child: const Text('テスト子Widget'),
            ),
          ),
        ),
      );

      // 名前付きStack (ヴィネットラッパー) が存在する
      expect(find.byKey(const Key('pinch_zone_vignette_stack')), findsOneWidget);
      // 名前付きCustomPaint (ヴィネット) が存在する
      expect(find.byKey(const Key('pinch_zone_vignette')), findsOneWidget);
    });

    testWidgets('isPinchState=false でヴィネットStackが存在しない', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinchZoneOverlay(
              isPinchState: false,
              child: const Text('テスト子Widget'),
            ),
          ),
        ),
      );

      // 名前付きStack (ヴィネットラッパー) が存在しない
      expect(find.byKey(const Key('pinch_zone_vignette_stack')), findsNothing);
      // 名前付きCustomPaint (ヴィネット) が存在しない
      expect(find.byKey(const Key('pinch_zone_vignette')), findsNothing);
    });
  });
}
