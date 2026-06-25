import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/achievement_api_model.dart';
import 'package:kozuchi/features/achievements/presentation/widgets/achievement_unlock_overlay.dart';

void main() {
  const testAchievement = AchievementApiModel(
    id: 1,
    key: 'first_offering',
    title: '初めての喜捨',
    description: '初めて喜捨を行った',
    criteriaType: 'offering_count',
    criteriaValue: 1,
    icon: '🙏',
    sortOrder: 10,
    unlocked: true,
    unlockedAt: '2026-06-25T10:00:00Z',
  );

  group('AchievementUnlockOverlay', () {
    testWidgets('shows achievement icon and title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAchievementUnlockPopup(context, [testAchievement]);
                  },
                  child: const Text('Show'),
                );
              },
            ),
          ),
        ),
      );

      // ボタンをタップしてポップアップ表示
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // アイコンが表示されている
      expect(find.text('🙏'), findsOneWidget);
      // タイトルが表示されている
      expect(find.text('初めての喜捨'), findsOneWidget);
      // 実績解除ラベル
      expect(find.text('🏆 実績解除！'), findsOneWidget);
      // 閉じる案内
      expect(find.text('タップで閉じる'), findsOneWidget);

      // 残存タイマー消化
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('dismisses on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAchievementUnlockPopup(context, [testAchievement]);
                  },
                  child: const Text('Show'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('初めての喜捨'), findsOneWidget);

      // タップで閉じる
      await tester.tap(find.text('タップで閉じる'));
      await tester.pumpAndSettle();

      // ポップアップが消えている
      expect(find.text('初めての喜捨'), findsNothing);

      // 残存タイマー消化（dialogが閉じられてタイマーはキャンセルされるはず
      // だが、安全のためpumpしておく）
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('shows "next" label when multiple achievements', (tester) async {
      const achievement2 = AchievementApiModel(
        id: 2,
        key: 'total_10000',
        title: '壱万円突破',
        description: '累計1万円達成',
        criteriaType: 'total_donation',
        criteriaValue: 10000,
        icon: '💰',
        sortOrder: 20,
        unlocked: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAchievementUnlockPopup(
                      context,
                      [testAchievement, achievement2],
                    );
                  },
                  child: const Text('Show'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // 残り1件のラベル
      expect(find.text('タップで次へ (あと1件)'), findsOneWidget);

      // タップで次へ
      await tester.tap(find.text('タップで次へ (あと1件)'));
      await tester.pumpAndSettle();

      // 2件目の実績が表示される
      expect(find.text('壱万円突破'), findsOneWidget);
      expect(find.text('タップで閉じる'), findsOneWidget);

      // 残存タイマーを消化（5秒のauto-dismissが開始されているため）
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('empty list returns nothing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAchievementUnlockPopup(context, []);
                  },
                  child: const Text('Show'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // 空リストなのでポップアップは表示されない
      expect(find.text('🏆 実績解除！'), findsNothing);
    });
  });
}
