import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/features/achievements/data/cross_app_achievement_aggregator.dart';
import 'package:kozuchi/features/collaboration_dashboard/data/collaboration_stats_service.dart';
import 'package:kozuchi/features/collaboration_dashboard/presentation/screens/collaboration_dashboard_screen.dart';

/// テスト用の固定データを返す CollaborationStatsService
class _MockStatsService extends CollaborationStatsService {
  final CollaborationStats _stats;

  _MockStatsService(this._stats) : super();

  @override
  Future<CollaborationStats> loadStats(PlayerModel player) async => _stats;
}

/// 三現世制覇判定を固定値で返すスタブ Aggregator
///
/// データ層ロジックは cross_app_achievement_aggregator_test.dart で検証済み。
/// ここでは UI が集計結果を正しく描画するかを検証するため、
/// 実ファイルIOを伴わない差し替え実装を用いる。
class _StubAggregator extends CrossAppAchievementAggregator {
  final ThreeWorldsStatus status;

  _StubAggregator(this.status) : super();

  @override
  Future<ThreeWorldsStatus> checkThreeWorldsConquest({
    required int goldEarned,
  }) async {
    return status;
  }
}

CollaborationStats _emptyStats() => CollaborationStats(
      recentBonusEvents: [],
      totalBonusExpAwarded: 0,
      remainingDailyBonuses: 3,
      maxDailyBonuses: 3,
      totalSynergyEvents: 0,
      hasActiveGoldBuff: false,
    );

Widget _wrapScreen({
  required CrossAppAchievementAggregator aggregator,
  int goldEarned = 0,
}) {
  return MaterialApp(
    home: CollaborationDashboardScreen(
      player: PlayerModel(hp: 100000, exp: 50),
      statsService: _MockStatsService(_emptyStats()),
      aggregator: aggregator,
      goldEarned: goldEarned,
    ),
  );
}

void main() {
  group('CollaborationDashboardScreen 三現世制覇カード', () {
    testWidgets('未達成時は各条件の進捗と三現世制覇タイトルを表示する', (tester) async {
      final aggregator = _StubAggregator(ThreeWorldsStatus(
        conditions: const ThreeWorldsConditions(
          enemiesDefeated: 5,
          booksRead: 2,
          goldEarned: 500,
        ),
        allMet: false,
      ));

      await tester.pumpWidget(_wrapScreen(aggregator: aggregator, goldEarned: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('三現世制覇'), findsOneWidget);
      expect(find.text('5/10'), findsOneWidget); // 敵討伐
      expect(find.text('2/5'), findsOneWidget); // 読了
      expect(find.text('500/1000'), findsOneWidget); // 金獲得
      // 達成バナーは表示されない
      expect(find.text('三現世制覇達成！'), findsNothing);
    });

    testWidgets('全条件を満たすと達成バナーを表示する', (tester) async {
      final aggregator = _StubAggregator(ThreeWorldsStatus(
        conditions: const ThreeWorldsConditions(
          enemiesDefeated: 10,
          booksRead: 5,
          goldEarned: 1000,
        ),
        allMet: true,
      ));

      await tester.pumpWidget(_wrapScreen(aggregator: aggregator, goldEarned: 1000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('三現世制覇'), findsOneWidget);
      expect(find.text('三現世制覇達成！'), findsOneWidget);
      expect(find.text('10/10'), findsOneWidget);
      expect(find.text('5/5'), findsOneWidget);
      expect(find.text('1000/1000'), findsOneWidget);
    });

    testWidgets('共有ストレージにデータが無くてもエラーを出さず0進捗を表示する', (tester) async {
      final aggregator = _StubAggregator(ThreeWorldsStatus(
        conditions: const ThreeWorldsConditions(
          enemiesDefeated: 0,
          booksRead: 0,
          goldEarned: 0,
        ),
        allMet: false,
      ));

      await tester.pumpWidget(_wrapScreen(aggregator: aggregator));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('三現世制覇'), findsOneWidget);
      expect(find.text('0/10'), findsOneWidget);
      expect(find.text('0/5'), findsOneWidget);
      expect(find.text('0/1000'), findsOneWidget);
      expect(find.text('三現世制覇達成！'), findsNothing);
    });
  });
}
