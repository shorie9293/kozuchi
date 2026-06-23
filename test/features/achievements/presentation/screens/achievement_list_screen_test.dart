import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:kozuchi/features/achievements/data/achievement_service.dart';
import 'package:kozuchi/features/achievements/presentation/screens/achievement_list_screen.dart';
import 'package:kozuchi/domain/models/achievement_api_model.dart';

/// モック実績データを生成する
List<AchievementApiModel> _mockAchievements() {
  return [
    AchievementApiModel(
      id: 1, key: 'first_offering', title: '初めての喜捨',
      description: '初めて喜捨を行った。', criteriaType: 'offering_count',
      criteriaValue: 1, icon: '🙏', sortOrder: 10,
      unlocked: true, unlockedAt: '2026-06-23T12:00:00',
    ),
    AchievementApiModel(
      id: 2, key: 'offering_10', title: '喜捨の修行者',
      description: '喜捨を10回行った。', criteriaType: 'offering_count',
      criteriaValue: 10, icon: '📿', sortOrder: 11,
      unlocked: false, unlockedAt: null,
      progress: const AchievementProgress(current: 3, target: 10, pct: 30.0),
    ),
    AchievementApiModel(
      id: 5, key: 'total_10000', title: '壱万円突破',
      description: '累計喜捨額が1万円を超えた。', criteriaType: 'total_donation',
      criteriaValue: 10000, icon: '💰', sortOrder: 20,
      unlocked: false, unlockedAt: null,
      progress: const AchievementProgress(current: 50000, target: 100000, pct: 50.0),
    ),
    AchievementApiModel(
      id: 7, key: 'streak_7', title: '七日修行',
      description: '7日連続で喜捨を記録。', criteriaType: 'streak_days',
      criteriaValue: 7, icon: '🌅', sortOrder: 31,
      unlocked: false, unlockedAt: null,
      progress: const AchievementProgress(current: 5, target: 7, pct: 71.4),
    ),
    AchievementApiModel(
      id: 10, key: 'satori_25', title: '悟りの初段',
      description: 'SATORI値が25%に達した。', criteriaType: 'satori_level',
      criteriaValue: 25, icon: '💡', sortOrder: 50,
      unlocked: false, unlockedAt: null, progress: null,
    ),
  ];
}

/// fetchOverride でモックデータを返すサービスを作成
AchievementService _mockService({List<AchievementApiModel>? data, bool throwError = false}) {
  return AchievementService(
    fetchOverride: ({String? userId}) async {
      if (throwError) {
        throw Exception('Mock API error: 500 Internal Server Error');
      }
      return data ?? _mockAchievements();
    },
  );
}

void main() {
  group('AchievementListScreen', () {
    // ── 通常表示 ──────────────────────────────────────────────────

    testWidgets('実績データがグリッドで表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AchievementListScreen(service: _mockService())),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.achievementList_gridView), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(5));
      expect(find.text('初めての喜捨'), findsOneWidget);
      expect(find.text('悟りの初段'), findsOneWidget);
      expect(find.text('🙏'), findsOneWidget);
    });

    // ── 解除済み実績 ──────────────────────────────────────────────

    testWidgets('解除済み実績はチェックアイコンと解除日が表示される',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AchievementListScreen(service: _mockService())),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('2026/06/23'), findsOneWidget);
    });

    // ── 進捗表示 ──────────────────────────────────────────────────

    testWidgets('未解除実績は進捗インジケータが表示される',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AchievementListScreen(service: _mockService())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
      expect(find.text('3 / 10回'), findsOneWidget);
      expect(find.text('¥5万 / ¥10万'), findsOneWidget);
      expect(find.text('5 / 7日'), findsOneWidget);
    });

    testWidgets('進捗がない実績はロックアイコンが表示される',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AchievementListScreen(service: _mockService())),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    // ── エラー状態 ───────────────────────────────────────────────

    testWidgets('APIエラー時にエラーメッセージとリトライボタンが表示される',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AchievementListScreen(service: _mockService(throwError: true))),
      );
      await tester.pumpAndSettle();

      expect(
          find.byKey(AppKeys.achievementList_errorView), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
    });

    testWidgets('リトライボタンタップで再取得が行われる', (tester) async {
      int callCount = 0;
      final service = AchievementService(
        fetchOverride: ({String? userId}) async {
          callCount++;
          if (callCount == 1) {
            throw Exception('error');
          }
          return _mockAchievements();
        },
      );
      await tester.pumpWidget(
        MaterialApp(home: AchievementListScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(
          find.byKey(AppKeys.achievementList_errorView), findsOneWidget);
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();

      expect(
          find.byKey(AppKeys.achievementList_gridView), findsOneWidget);
      expect(callCount, 2);
    });

    // ── 空リスト ──────────────────────────────────────────────────

    testWidgets('実績が0件の場合、空メッセージが表示される',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AchievementListScreen(service: _mockService(data: []))),
      );
      await tester.pumpAndSettle();

      expect(
          find.byKey(AppKeys.achievementList_emptyView), findsOneWidget);
      expect(find.text('実績がありません'), findsOneWidget);
    });

    // ── AppBar ────────────────────────────────────────────────────

    testWidgets('AppBarにタイトルが表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AchievementListScreen(service: _mockService())),
      );
      await tester.pumpAndSettle();

      expect(find.text('🏆 実績一覧'), findsOneWidget);
    });

    // ── userIdあり ───────────────────────────────────────────────

    testWidgets('userId指定時はクエリパラメータ付きでAPIが呼ばれる',
        (tester) async {
      String? capturedUserId;
      final service = AchievementService(
        fetchOverride: ({String? userId}) async {
          capturedUserId = userId;
          return _mockAchievements();
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AchievementListScreen(
              service: service, userId: 'test_user_123'),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedUserId, 'test_user_123');
    });
  });

  group('AchievementApiModel', () {
    test('fromJson で正しくパースされる（未解除・進捗なし）', () {
      final jsonMap = <String, dynamic>{
        'id': 1, 'key': 'first_offering', 'title': '初めての喜捨',
        'description': '初めて喜捨を行った。', 'criteria_type': 'offering_count',
        'criteria_value': 1, 'icon': '🙏', 'sort_order': 10,
        'unlocked': false, 'unlocked_at': null, 'progress': null,
      };
      final model = AchievementApiModel.fromJson(jsonMap);
      expect(model.id, 1);
      expect(model.key, 'first_offering');
      expect(model.title, '初めての喜捨');
      expect(model.criteriaType, 'offering_count');
      expect(model.criteriaValue, 1);
      expect(model.icon, '🙏');
      expect(model.sortOrder, 10);
      expect(model.unlocked, false);
      expect(model.unlockedAt, null);
      expect(model.progress, null);
      expect(model.progressText, null);
      expect(model.progressFraction, null);
    });

    test('progressText: offering_count は "X / Y回" 形式', () {
      final model = AchievementApiModel(
        id: 1, key: 'test', title: 'テスト', description: 'テスト',
        criteriaType: 'offering_count', criteriaValue: 10,
        icon: '🏆', sortOrder: 1, unlocked: false,
        progress:
            const AchievementProgress(current: 3, target: 10, pct: 30.0),
      );
      expect(model.progressText, '3 / 10回');
    });

    test('progressText: total_donation は "¥X / ¥Y" 形式', () {
      final model = AchievementApiModel(
        id: 1, key: 'test', title: 'テスト', description: 'テスト',
        criteriaType: 'total_donation', criteriaValue: 100000,
        icon: '💰', sortOrder: 1, unlocked: false,
        progress: const AchievementProgress(
            current: 50000, target: 100000, pct: 50.0),
      );
      expect(model.progressText, '¥5万 / ¥10万');
    });

    test('progressFraction: 進捗率を正しく計算する', () {
      final model = AchievementApiModel(
        id: 1, key: 'test', title: 'テスト', description: 'テスト',
        criteriaType: 'offering_count', criteriaValue: 10,
        icon: '🏆', sortOrder: 1, unlocked: false,
        progress:
            const AchievementProgress(current: 5, target: 10, pct: 50.0),
      );
      expect(model.progressFraction, 0.5);
    });

    test('解除済み実績はprogressText/progressFractionがnull', () {
      final model = AchievementApiModel(
        id: 1, key: 'test', title: 'テスト', description: 'テスト',
        criteriaType: 'offering_count', criteriaValue: 10,
        icon: '🏆', sortOrder: 1, unlocked: true,
        unlockedAt: '2026-06-23T12:00:00',
        progress: const AchievementProgress(
            current: 10, target: 10, pct: 100.0),
      );
      expect(model.progressText, null);
      expect(model.progressFraction, null);
    });
  });
}
