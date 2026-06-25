import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/features/effects/domain/effect_definition.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';
import 'package:kozuchi/features/effects/presentation/effects/guardian_switch_effect.dart';

void main() {
  group('GuardianSwitchEffect', () {
    final _definition = const EffectDefinition(
      name: 'guardian_switch',
      duration: Duration(seconds: 4),
      isFullScreen: true,
      parameters: {
        'oldAdvisor': 0, // lifePlanner
        'newAdvisor': 1, // careerCoach
      },
    );

    EffectInstance _makeInstance({Map<String, dynamic>? parameters}) {
      return EffectInstance(
        id: 'test-switch-1',
        definition: EffectDefinition(
          name: 'guardian_switch',
          duration: const Duration(seconds: 4),
          isFullScreen: true,
          parameters: parameters ?? _definition.parameters,
        ),
        position: Offset.zero,
      );
    }

    testWidgets('全画面を覆う暗幕を持つ', (tester) async {
      final instance = _makeInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const Scaffold(body: Center(child: Text('背景'))),
              GuardianSwitchEffect(instance: instance),
            ],
          ),
        ),
      );

      expect(find.byType(GuardianSwitchEffect), findsOneWidget);
      // 背景Widgetも存在する
      expect(find.text('背景'), findsOneWidget);
    });

    testWidgets('旧守護神の別れの言葉が表示される', (tester) async {
      final instance = _makeInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const Scaffold(body: Center(child: Text('背景'))),
              GuardianSwitchEffect(instance: instance),
            ],
          ),
        ),
      );

      // 1.0秒経過で別れのメッセージが完全表示される（progress 0.25）
      await tester.pump(const Duration(milliseconds: 1000));

      // ライフプランナーの別れの言葉が含まれている
      expect(
        find.textContaining('福と財の加護'),
        findsOneWidget,
      );
    });

    testWidgets('新守護神の契約メッセージが表示される', (tester) async {
      final instance = _makeInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const Scaffold(body: Center(child: Text('背景'))),
              GuardianSwitchEffect(instance: instance),
            ],
          ),
        ),
      );

      // 2.4秒経過で契約メッセージが表示される（progress 0.6）
      await tester.pump(const Duration(milliseconds: 2400));

      expect(
        find.textContaining('キャリアコーチ'),
        findsWidgets,
      );
    });

    testWidgets('スキップヒントが表示される', (tester) async {
      final instance = _makeInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const Scaffold(body: Center(child: Text('背景'))),
              GuardianSwitchEffect(instance: instance),
            ],
          ),
        ),
      );

      expect(find.text('タップでスキップ'), findsOneWidget);
    });

    testWidgets('タップでスキップできる', (tester) async {
      final instance = _makeInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const Scaffold(body: Center(child: Text('背景'))),
              GuardianSwitchEffect(instance: instance),
            ],
          ),
        ),
      );

      // タップでスキップ
      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();

      // スキップ後はスキップヒントが非表示になる
      expect(find.text('タップでスキップ'), findsNothing);
    });
  });
}
