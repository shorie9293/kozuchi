import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:kozuchi/domain/models/achievement_api_model.dart';
import 'package:kozuchi/features/achievements/data/achievement_service.dart';

/// 実績一覧画面
///
/// 全実績をスクロール可能なグリッドで表示する。
/// 各実績カードにはアイコン・タイトル・説明・進捗インジケータを表示。
/// 解除済み実績はチェックバッジと解除日を表示。
class AchievementListScreen extends StatefulWidget {
  /// 実績サービス（テスト時にモック注入可能）
  final AchievementService service;

  /// ユーザーID（指定時はユーザー別解除状態を表示）
  final String? userId;

  AchievementListScreen({
    super.key,
    AchievementService? service,
    this.userId,
  }) : service = service ?? AchievementService();

  @override
  State<AchievementListScreen> createState() => _AchievementListScreenState();
}

class _AchievementListScreenState extends State<AchievementListScreen> {
  List<AchievementApiModel>? _achievements;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final achievements = await widget.service.fetchAchievements(
        userId: widget.userId,
      );
      if (mounted) {
        setState(() {
          _achievements = achievements;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.achievementListScreen,
      appBar: AppBar(
        title: const Text('🏆 実績一覧'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // ローディング状態
    if (_isLoading) {
      return const Center(
        key: AppKeys.achievementList_loadingIndicator,
        child: CircularProgressIndicator(),
      );
    }

    // エラー状態
    if (_errorMessage != null) {
      return Center(
        key: AppKeys.achievementList_errorView,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: AppKeys.errorRetryButton,
                onPressed: _loadAchievements,
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }

    // 空リスト
    if (_achievements == null || _achievements!.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        key: AppKeys.achievementList_emptyView,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: cs.onSurface.withValues(alpha: 0.4)),
            SizedBox(height: 16),
            Text(
              '実績がありません',
              style: TextStyle(fontSize: 16, color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }

    // 実績グリッド
    return GridView.builder(
      key: AppKeys.achievementList_gridView,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _achievements!.length,
      itemBuilder: (context, index) {
        return _AchievementCard(achievement: _achievements![index]);
      },
    );
  }
}

/// 実績カードウィジェット
///
/// 各実績をカード形式で表示する。
/// - 未解除: 進捗バー + 進捗テキスト
/// - 解除済み: ✅ バッジ + 解除日
class _AchievementCard extends StatelessWidget {
  final AchievementApiModel achievement;

  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUnlocked = achievement.unlocked;

    return Card(
      elevation: isUnlocked ? 4 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // アイコン + 解除バッジ
            Stack(
              children: [
                Text(
                  achievement.icon,
                  style:
                      TextStyle(fontSize: 36, color: colorScheme.onSurface),
                ),
                if (isUnlocked)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // タイトル
            Text(
              achievement.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // 説明
            Expanded(
              child: Text(
                achievement.description,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 進捗 or 解除日
            if (isUnlocked)
              _buildUnlockedDate(colorScheme)
            else
              _buildProgressIndicator(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(ColorScheme colorScheme) {
    final fraction = achievement.progressFraction;
    final text = achievement.progressText;

    // 進捗情報がない場合（criteria_typeが未実装など）
    if (fraction == null || text == null) {
      return SizedBox(
        height: 24,
        child: Center(
          child: Icon(Icons.lock_outline, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.4)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        // 進捗バー
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor:
                AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
        const SizedBox(height: 4),
        // 進捗テキスト
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildUnlockedDate(ColorScheme colorScheme) {
    final dateStr = achievement.unlockedAt;
    if (dateStr == null) return const SizedBox.shrink();

    // ISO 8601文字列をパースして表示用に整形
    String displayDate;
    try {
      final dt = DateTime.parse(dateStr);
      displayDate =
          '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      displayDate = dateStr;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 12, color: Colors.green.shade700),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              displayDate,
              style: TextStyle(
                fontSize: 10,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
