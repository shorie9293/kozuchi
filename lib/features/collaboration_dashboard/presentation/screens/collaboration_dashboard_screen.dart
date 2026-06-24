import 'package:flutter/material.dart';
import 'package:kozuchi/core/widgets/washi_background.dart';
import 'package:kozuchi/domain/models/gold_luck_buff.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/features/collaboration_dashboard/data/collaboration_stats_service.dart';

/// 連携ダッシュボード画面
///
/// rpg-task と tsundoku-quest の連携イベント履歴と統計を表示する。
/// - rpg-task 敵討伐ボーナスEXP イベント履歴
/// - tsundoku 読了による金運上昇バフの状態
/// - 総合シナジー統計（累計EXP、イベント数、本日の残り回数）
class CollaborationDashboardScreen extends StatefulWidget {
  final PlayerModel player;

  /// テスト用に注入可能なサービス
  final CollaborationStatsService statsService;

  const CollaborationDashboardScreen({
    super.key,
    required this.player,
    this.statsService = const CollaborationStatsService(),
  });

  @override
  State<CollaborationDashboardScreen> createState() =>
      _CollaborationDashboardScreenState();
}

class _CollaborationDashboardScreenState
    extends State<CollaborationDashboardScreen> {
  late Future<CollaborationStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = widget.statsService.loadStats(widget.player);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: const Key('collaborationDashboardScreen'),
      appBar: AppBar(
        title: const Text('連携ダッシュボード'),
        centerTitle: true,
      ),
      body: WashiBackground(
        child: FutureBuilder<CollaborationStats>(
          future: _statsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'データの読み込みに失敗しました',
                  style: TextStyle(color: colorScheme.error),
                ),
              );
            }

            final stats = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // セクション1: 総合シナジー統計
                  _buildSynergySummary(colorScheme, stats),
                  const SizedBox(height: 16),
                  // セクション2: 金運上昇バフ
                  _buildGoldBuffSection(colorScheme, stats),
                  const SizedBox(height: 16),
                  // セクション3: rpg-task 討伐ボーナス履歴
                  _buildBonusHistorySection(colorScheme, stats),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 総合シナジー統計カード
  Widget _buildSynergySummary(
      ColorScheme colorScheme, CollaborationStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('⚡',
                    style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  '総合シナジー統計',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    icon: '⭐',
                    label: '累計ボーナスEXP',
                    value: '${stats.totalBonusExpAwarded}',
                    colorScheme: colorScheme,
                  ),
                ),
                Expanded(
                  child: _buildStatTile(
                    icon: '🔗',
                    label: '連携イベント数',
                    value: '${stats.totalSynergyEvents}',
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    icon: '🎯',
                    label: '本日の討伐ボーナス',
                    value: '残り${stats.remainingDailyBonuses}/${stats.maxDailyBonuses}回',
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
            // 本日の使用量プログレスバー
            if (stats.maxDailyBonuses > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: stats.dailyBonusUsage,
                backgroundColor:
                    colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  stats.remainingDailyBonuses > 0
                      ? Colors.amber
                      : colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 金運上昇バフ セクション
  Widget _buildGoldBuffSection(
      ColorScheme colorScheme, CollaborationStats stats) {
    final buff = stats.activeGoldBuff;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📖✨',
                    style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  '金運上昇バフ（tsundoku読了）',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (buff != null && buff.isActive) ...[
              _buildActiveBuffCard(colorScheme, buff),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text('💤', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      '現在アクティブな金運バフはありません',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'tsundoku-quest で本を読了すると、'
                '60分間の収入2倍バフが発動します。',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// アクティブなバフの詳細表示
  Widget _buildActiveBuffCard(
      ColorScheme colorScheme, GoldLuckBuff buff) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.2),
            Colors.orange.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '収入 ${buff.multiplier.toInt()}倍！',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade800,
                      ),
                    ),
                    if (buff.bookTitle != null)
                      Text(
                        '『${buff.bookTitle}』読了の祝福',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer, size: 14,
                  color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                buff.remainingDisplay,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '発動: ${_formatDateTime(buff.activatedAt)}',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  /// rpg-task 討伐ボーナス履歴セクション
  Widget _buildBonusHistorySection(
      ColorScheme colorScheme, CollaborationStats stats) {
    final events = stats.recentBonusEvents;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('👹',
                    style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  'rpg-task 討伐ボーナス履歴',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (events.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text('📭',
                        style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      'まだ討伐ボーナスの履歴はありません',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'rpg-task で敵を討伐すると、'
                'ボーナスEXPが kozuchi に付与されます（1日3回まで）。',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.outline,
                ),
              ),
            ] else ...[
              ...events.map((event) =>
                  _buildBonusEventTile(colorScheme, event)),
            ],
          ],
        ),
      ),
    );
  }

  /// 個別の討伐ボーナスイベントタイル
  Widget _buildBonusEventTile(
      ColorScheme colorScheme, Map<String, dynamic> event) {
    final taskTitle =
        event['taskTitle'] as String? ?? '不明なクエスト';
    final questRank =
        event['questRank'] as String? ?? '?';
    final bonusExp =
        (event['bonusExp'] as num?)?.toInt() ?? 0;
    final timestamp =
        event['timestamp'] as String?;
    final rankEmoji = switch (questRank) {
      'S' => '👹',
      'A' => '👺',
      _ => '👾',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(rankEmoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  taskTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (timestamp != null)
                  Text(
                    _formatDateTime(
                        DateTime.tryParse(timestamp) ??
                            DateTime.now()),
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'EXP +$bonusExp',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 統計タイル
  Widget _buildStatTile({
    required String icon,
    required String label,
    required String value,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 日時を日本語表記でフォーマット
  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}/${_pad(local.month)}/${_pad(local.day)} '
        '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
