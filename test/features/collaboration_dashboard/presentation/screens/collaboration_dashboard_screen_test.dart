import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/gold_luck_buff.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/features/collaboration_dashboard/data/collaboration_stats_service.dart';
import 'package:kozuchi/features/collaboration_dashboard/presentation/screens/collaboration_dashboard_screen.dart';

/// テスト用の固定データを返す CollaborationStatsService
class _MockStatsService extends CollaborationStatsService {
  final CollaborationStats _stats;

  _MockStatsService(this._stats) : super();

  @override
  Future<CollaborationStats> loadStats(PlayerModel player) async => _stats;
}

Widget _wrapScreen({
  required PlayerModel player,
  required CollaborationStatsService statsService,
}) {
  return MaterialApp(
    home: CollaborationDashboardScreen(
      player: player,
      statsService: statsService,
    ),
  );
}

void main() {
  group('CollaborationDashboardScreen', () {
    testWidgets('displays synergy summary stats', (tester) async {
      final stats = CollaborationStats(
        recentBonusEvents: [],
        totalBonusExpAwarded: 0,
        remainingDailyBonuses: 3,
        maxDailyBonuses: 3,
        totalSynergyEvents: 0,
        hasActiveGoldBuff: false,
      );
      final player = PlayerModel(hp: 100000, exp: 50);

      await tester.pumpWidget(
        _wrapScreen(
          player: player,
          statsService: _MockStatsService(stats),
        ),
      );
      await tester.pumpAndSettle();

      // 総合シナジー統計セクションが表示されている
      expect(find.text('総合シナジー統計'), findsOneWidget);
      expect(find.text('累計ボーナスEXP'), findsOneWidget);
      expect(find.text('連携イベント数'), findsOneWidget);
      expect(find.text('本日の討伐ボーナス'), findsOneWidget);
    });

    testWidgets('displays no active buff message when no buff', (tester) async {
      final stats = CollaborationStats(
        recentBonusEvents: [],
        totalBonusExpAwarded: 0,
        remainingDailyBonuses: 3,
        maxDailyBonuses: 3,
        totalSynergyEvents: 0,
        hasActiveGoldBuff: false,
      );
      final player = PlayerModel(hp: 100000, exp: 50);

      await tester.pumpWidget(
        _wrapScreen(
          player: player,
          statsService: _MockStatsService(stats),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('金運上昇バフ（tsundoku読了）'), findsOneWidget);
      expect(find.text('現在アクティブな金運バフはありません'), findsOneWidget);
    });

    testWidgets('displays active gold buff with details', (tester) async {
      final buff = GoldLuckBuff.forBookCompleted(
        bookTitle: '走れメロス',
        multiplier: 2.0,
        duration: const Duration(minutes: 60),
      );
      final player = PlayerModel(
        hp: 100000,
        exp: 50,
        goldLuckBuff: buff,
      );
      final stats = CollaborationStats(
        recentBonusEvents: [],
        totalBonusExpAwarded: 0,
        remainingDailyBonuses: 3,
        maxDailyBonuses: 3,
        totalSynergyEvents: 1,
        hasActiveGoldBuff: true,
        activeGoldBuff: buff,
      );

      await tester.pumpWidget(
        _wrapScreen(
          player: player,
          statsService: _MockStatsService(stats),
        ),
      );
      await tester.pumpAndSettle();

      // アクティブバフの詳細が表示されている
      expect(find.textContaining('収入'), findsWidgets);
      expect(find.textContaining('倍'), findsWidgets);
      expect(find.textContaining('走れメロス'), findsOneWidget);
    });

    testWidgets('displays bonus history section', (tester) async {
      final stats = CollaborationStats(
        recentBonusEvents: [],
        totalBonusExpAwarded: 0,
        remainingDailyBonuses: 3,
        maxDailyBonuses: 3,
        totalSynergyEvents: 0,
        hasActiveGoldBuff: false,
      );
      final player = PlayerModel(hp: 100000, exp: 50);

      await tester.pumpWidget(
        _wrapScreen(
          player: player,
          statsService: _MockStatsService(stats),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('rpg-task 討伐ボーナス履歴'), findsOneWidget);
      expect(find.text('まだ討伐ボーナスの履歴はありません'), findsOneWidget);
    });

    testWidgets('displays bonus event tiles when history exists', (tester) async {
      final stats = CollaborationStats(
        recentBonusEvents: [
          {
            'taskTitle': '魔王討伐',
            'questRank': 'S',
            'bonusExp': 50,
            'baseExp': 200,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
          },
          {
            'taskTitle': '鬼退治',
            'questRank': 'A',
            'bonusExp': 30,
            'baseExp': 150,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
          },
        ],
        totalBonusExpAwarded: 80,
        remainingDailyBonuses: 1,
        maxDailyBonuses: 3,
        totalSynergyEvents: 2,
        hasActiveGoldBuff: false,
      );
      final player = PlayerModel(hp: 100000, exp: 50);

      await tester.pumpWidget(
        _wrapScreen(
          player: player,
          statsService: _MockStatsService(stats),
        ),
      );
      await tester.pumpAndSettle();

      // イベントタイルが表示されている
      expect(find.text('魔王討伐'), findsOneWidget);
      expect(find.text('鬼退治'), findsOneWidget);
      expect(find.text('EXP +50'), findsOneWidget);
      expect(find.text('EXP +30'), findsOneWidget);

      // 残りボーナス回数が表示されている
      expect(find.textContaining('残り1回'), findsOneWidget);
    });

    testWidgets('shows progress bar for bonus usage', (tester) async {
      final stats = CollaborationStats(
        recentBonusEvents: [],
        totalBonusExpAwarded: 100,
        remainingDailyBonuses: 1,
        maxDailyBonuses: 3,
        totalSynergyEvents: 0,
        hasActiveGoldBuff: false,
      );
      final player = PlayerModel(hp: 100000, exp: 50);

      await tester.pumpWidget(
        _wrapScreen(
          player: player,
          statsService: _MockStatsService(stats),
        ),
      );
      await tester.pumpAndSettle();

      // プログレスバーが表示される（LinearProgressIndicator）
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('displays total synergy stats correctly', (tester) async {
      final stats = CollaborationStats(
        recentBonusEvents: List.generate(5, (i) => {
          'taskTitle': 'Quest $i',
          'questRank': 'A',
          'bonusExp': 30,
          'baseExp': 100,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        totalBonusExpAwarded: 150,
        remainingDailyBonuses: 0,
        maxDailyBonuses: 3,
        totalSynergyEvents: 5,
        hasActiveGoldBuff: false,
      );
      final player = PlayerModel(hp: 100000, exp: 50);

      await tester.pumpWidget(
        _wrapScreen(
          player: player,
          statsService: _MockStatsService(stats),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('150'), findsOneWidget); // totalBonusExpAwarded
      expect(find.text('5'), findsOneWidget); // totalSynergyEvents
      expect(find.textContaining('残り0回'), findsOneWidget);
    });
  });
}
