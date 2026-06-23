import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:kozuchi/core/widgets/money_background.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/domain/models/level_stage.dart';
import 'package:kozuchi/features/hp_bar/presentation/widgets/hp_bar_widget.dart';
import 'package:kozuchi/features/exp_gauge/presentation/widgets/exp_gauge_widget.dart';
import 'package:kozuchi/features/advisor_selection/presentation/advisor_selection_screen.dart';
import 'package:kozuchi/features/trial_quest/presentation/screens/trial_quest_screen.dart';
import 'package:kozuchi/features/income/presentation/screens/income_input_screen.dart';
import 'package:kozuchi/features/effects/presentation/effect_manager.dart';
import 'package:kozuchi/features/pinch_zone/presentation/widgets/pinch_zone_overlay.dart';
import 'package:kozuchi/features/pinch_zone/presentation/widgets/pinch_zone_warning_banner.dart';
import 'package:kozuchi/features/analysis_chart/presentation/widgets/analysis_chart_widget.dart';
import 'package:kozuchi/features/shared/data/kozuchi_quest_exporter.dart';
import 'package:kozuchi/features/shared/data/player_repository.dart';
import 'package:kozuchi/features/careerCoach/data/careerCoach_book_bonus_service.dart';
import 'package:kozuchi/features/rpg_task_bonus/data/rpg_task_bonus_service.dart';
import 'package:kozuchi/features/tsundoku/data/tsundoku_gold_luck_buff_service.dart';
import 'package:kozuchi/features/budget/presentation/screens/budget_settings_screen.dart';
import 'package:kozuchi/features/shared/data/budget_repository.dart';
import 'package:kozuchi/features/period_comparison/presentation/widgets/period_comparison_summary.dart';
import 'package:kozuchi/features/achievements/presentation/screens/achievement_list_screen.dart';

/// メイン画面
///
/// HPバー + EXPゲージ + 現在の試練を表示する
/// アプリの中心画面。
/// レベルMAX段階（kuu）到達後は裏面モードに切り替え可能。
class MainScreen extends StatefulWidget {
  /// テスト用の初期プレイヤー（nullの場合はデフォルト値）
  final PlayerModel? initialPlayer;

  /// テスト用に注入可能なKozuchiQuestExporter（デフォルトで実インスタンス）
  final KozuchiQuestExporter exporter;

  /// データ永続化リポジトリ（テスト時にモック注入可能）
  final PlayerRepository repository;

  /// 現在のテーマモード
  final ThemeMode themeMode;

  /// テーマモードに応じたアイコン
  final IconData themeIcon;

  /// テーマ切替コールバック
  final VoidCallback? onToggleTheme;

  const MainScreen({
    super.key,
    this.initialPlayer,
    this.exporter = const KozuchiQuestExporter(),
    this.repository = const PlayerRepository(),
    this.themeMode = ThemeMode.system,
    this.themeIcon = Icons.brightness_auto,
    this.onToggleTheme,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late PlayerModel _player;
  TrialQuest? _currentQuest;
  bool _isUraMode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _player = widget.initialPlayer ?? PlayerModel.defaultPlayer();
    _currentQuest = _createInitialQuest();
    _loadSavedState();
  }

  /// 保存済みの状態を復元する
  Future<void> _loadSavedState() async {
    if (widget.initialPlayer != null) {
      // テスト用の初期プレイヤーが指定されている場合は永続化データを無視
      setState(() => _isLoading = false);
      _exportCurrentQuest();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkCareerCoachBookBonus();
        _checkRpgTaskBonus();
        _checkTsundokuBookCompletion();
      });
      return;
    }

    final savedPlayer = await widget.repository.loadPlayer();
    final savedQuest = await widget.repository.loadQuest();

    if (mounted) {
      setState(() {
        if (savedPlayer != null) {
          _player = savedPlayer;
        }
        if (savedQuest != null) {
          _currentQuest = savedQuest;
        } else {
          _currentQuest = _createInitialQuest();
        }
        _isLoading = false;
      });
      _exportCurrentQuest();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkCareerCoachBookBonus();
        _checkRpgTaskBonus();
        _checkTsundokuBookCompletion();
      });
    }
  }

  /// 現在の状態を永続化する
  Future<void> _persistState() async {
    await widget.repository.savePlayer(_player);
    if (_currentQuest != null) {
      await widget.repository.saveQuest(_currentQuest!);
    }
  }

  /// キャリアコーチの蔵書追加ボーナスをチェックして適用する
  ///
  /// tsundoku-quest が共有ストレージに書き出した book_added イベントを読み取り、
  /// アドバイザーがキャリアコーチの場合に EXP ボーナスを付与する。
  void _checkCareerCoachBookBonus() {
    final advisor = _player.advisor;
    if (advisor == null) return;

    const service = CareerCoachBookBonusService();
    service.checkAndConsume(advisor).then((result) {
      if (result != null && mounted) {
        setState(() {
          _player = _player.addExp(result.bonusExp);
        });
        _persistState();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📚 キャリアコーチボーナス！『${result.bookTitle}』の蔵書追加でEXP +${result.bonusExp}',
            ),
          ),
        );
      }
    });
  }

  /// rpg-taskの敵討伐ボーナスをチェックして適用する
  ///
  /// rpg-task が共有ストレージに書き出した enemy_defeated イベントを読み取り、
  /// クエストランクに応じたボーナスEXPを付与する。
  /// 1日最大3回。アドバイザー未契約でも付与される。
  void _checkRpgTaskBonus() {
    const service = RpgTaskBonusService();
    service.checkAndConsume().then((result) {
      if (result != null && mounted) {
        final rankEmoji = switch (result.questRank) {
          'S' => '👹',
          'A' => '👺',
          _ => '👾',
        };
        setState(() {
          _player = _player.addExp(result.bonusExp);
        });
        _persistState();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$rankEmoji rpg-task討伐ボーナス！『${result.taskTitle}』討伐でEXP +${result.bonusExp}',
            ),
          ),
        );
      }
    });
  }

  /// tsundoku読了による金運上昇バフをチェックして適用する
  ///
  /// tsundoku-quest が共有ストレージに書き出した book_completed イベントを読み取り、
  /// 金運上昇バフ（収入2倍、60分間）を発動する。
  /// アドバイザー未契約でも付与される。
  void _checkTsundokuBookCompletion() {
    const service = TsundokuGoldLuckBuffService();
    service.checkAndConsume().then((buff) {
      if (buff != null && mounted) {
        setState(() {
          _player = _player.applyGoldLuckBuff(buff);
        });
        _persistState();
        final bookInfo =
            buff.bookTitle != null ? '『${buff.bookTitle}』' : '本';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text(
              '📖✨ 金運上昇！${bookInfo}を読了した祝福で、'
              '${buff.remainingDisplay}の間収入が${buff.multiplier.toInt()}倍に！',
            ),
          ),
        );
      }
    });
  }

  /// 現在のクエストを共有ストレージに書き出す
  /// 試練が未契約状態（title == 'アドバイザーと契約せよ'）の場合は書き出さない
  void _exportCurrentQuest() {
    if (_currentQuest != null && _currentQuest!.title != 'アドバイザーと契約せよ') {
      widget.exporter.export(_currentQuest);
    }
  }

  TrialQuest _createInitialQuest() {
    // アドバイザー未契約の場合は試練を表示しない
    if (_player.advisor == null) {
      return TrialQuest(
        title: 'アドバイザーと契約せよ',
        description: 'まずは四天のアドバイザーから1柱を選び、契約を結べ。',
        suggestedOffering: 0,
        advisor: Advisor.lifePlanner,
      );
    }
    return TrialQuest(
      title: '試練を待て',
      description: 'アドバイザーからの試練を待っている…',
      suggestedOffering: 0,
      advisor: _player.advisor!,
    );
  }

  void _openAdvisorSelection() {
    Navigator.of(context).push<Advisor>(
      MaterialPageRoute(
        builder: (_) => AdvisorSelectionScreen(
          onSelected: (deity) {
            setState(() {
              _player = _player.contractWith(deity);
              _currentQuest = _createInitialQuest();
            });
            _persistState();
            _exportCurrentQuest();
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _openTrialQuest() {
    if (_currentQuest == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrialQuestScreen(
          quest: _currentQuest!,
          player: _player,
          onQuestUpdated: (quest, player) {
            setState(() {
              _currentQuest = quest;
              _player = player;
            });
            _persistState();
            _exportCurrentQuest();
          },
        ),
      ),
    );
  }

  void _toggleUraMode() {
    setState(() {
      _isUraMode = !_isUraMode;
    });
  }

  void _openBudgetSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BudgetSettingsScreen(
          repository: const BudgetRepository(),
          onSaved: () {
            // 予算設定後に必要なUI再描画があればここで
          },
        ),
      ),
    );
  }

  void _openAchievementList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AchievementListScreen(),
      ),
    );
  }

  Future<void> _openIncomeInput() async {
    final result = await Navigator.of(context).push<IncomeResult>(
      MaterialPageRoute(
        builder: (_) => IncomeInputScreen(player: _player),
      ),
    );
    if (result != null) {
      setState(() {
        _player = result.updatedPlayer;
      });
      _persistState();
      // 入金エフェクト：画面中央に桜吹雪を発動
      EffectManager.of(context).playEffect(
        'cherry_snow',
        Offset(
          MediaQuery.of(context).size.width / 2,
          MediaQuery.of(context).size.height / 2,
        ),
      );
    }
  }

  bool get _canUseUraMode => _player.levelStage == LevelStage.kuu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // データ読み込み中はローディング表示
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      key: AppKeys.mainScreen,
      appBar: AppBar(
        title: const Text('打ち出の小槌'),
        centerTitle: true,
        backgroundColor: _isUraMode
            ? colorScheme.surface
            : null,
        foregroundColor: _isUraMode
            ? colorScheme.onSurface
            : null,
        actions: [
          if (widget.onToggleTheme != null)
            IconButton(
              key: const Key('themeToggleButton'),
              icon: Icon(widget.themeIcon),
              tooltip: switch (widget.themeMode) {
                ThemeMode.light => 'ライトモード（タップでダークに切替）',
                ThemeMode.dark => 'ダークモード（タップで自動に切替）',
                ThemeMode.system => '自動（システム連動・タップでライトに切替）',
              },
              onPressed: widget.onToggleTheme,
            ),
          IconButton(
            key: const Key('achievementListButton'),
            icon: const Icon(Icons.emoji_events),
            tooltip: '実績一覧',
            onPressed: _openAchievementList,
          ),
          IconButton(
            key: const Key('budgetSettingsButton'),
            icon: const Icon(Icons.savings),
            tooltip: '月間予算設定',
            onPressed: _openBudgetSettings,
          ),
          IconButton(
            key: const Key('incomeButton'),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '収入を記録',
            onPressed: _openIncomeInput,
          ),
          if (_player.advisor != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_player.advisor!.emoji} ${_player.advisor!.label}',
                    style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: MoneyBackground(
        child: PinchZoneOverlay(
          isPinchState: _player.isPinchState,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ピンチゾーン警告バナー
                if (_player.isPinchState) PinchZoneWarningBanner(player: _player),
                // HPバー（裏面モード時はフェードアウト）
                AnimatedOpacity(
                  opacity: (_isUraMode && _canUseUraMode) ? 0.3 : 1.0,
                  duration: const Duration(milliseconds: 600),
                  child: HpBarWidget(player: _player),
                ),
                // 裏面モード時のみ支出可視化ツリーを表示
                if (_isUraMode && _canUseUraMode) ...[
                  const SizedBox(height: 8),
                  AnalysisChartWidget(
                    key: const Key('analysisChart'),
                    isVisible: true,
                  ),
                  const SizedBox(height: 16),
                  const PeriodComparisonSummary(
                    key: Key('periodComparisonSummary'),
                  ),
                ],
                const SizedBox(height: 24),
                // EXPゲージ
                ExpGaugeWidget(player: _player),
                const SizedBox(height: 24),
                // 開眼段階バッジ
                _buildLevelBadge(colorScheme),
                const SizedBox(height: 24),
                // マスター領域ラベル（裏面モード時）
                if (_isUraMode && _canUseUraMode)
                  Padding(
                    key: const Key('kuuWorldLabel'),
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: Text(
                        '🌌 マスター領域',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.withValues(alpha: 0.8),
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ),
                // 現在の試練セクション
                _buildCurrentTrialSection(colorScheme),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (!_canUseUraMode) return null;

    if (_isUraMode) {
      // 裏面モード → 表に戻るFAB
      return FloatingActionButton(
        key: const Key('omoteModeFab'),
        onPressed: _toggleUraMode,
        backgroundColor: Colors.amber.shade800,
        child: const Icon(Icons.wb_sunny, color: Colors.white),
      );
    }

    // 表モード → 裏面に切り替えるFAB
    return FloatingActionButton(
      key: const Key('uraModeFab'),
      onPressed: _toggleUraMode,
      backgroundColor: Colors.indigo.shade800,
      child: const Icon(Icons.nights_stay, color: Colors.white70),
    );
  }

  Widget _buildLevelBadge(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.secondaryContainer,
            colorScheme.tertiaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('🧘', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '開眼段階: ${_player.levelStage.label}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              Text(
                _player.levelStage.description,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTrialSection(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📜 現在の試練', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              if (_currentQuest?.isCompleted == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '完了',
                    style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_player.advisor == null) ...[
            // アドバイザー未契約 → 契約を促す
            Text(
              'まだアドバイザーと契約していない',
              style: TextStyle(color: colorScheme.outline),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openAdvisorSelection,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('アドバイザーと契約する'),
              ),
            ),
          ] else ...[
            // 試練を表示
            if (_currentQuest != null) ...[
              Text(
                _currentQuest!.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currentQuest!.description,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    _currentQuest!.advisor.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _currentQuest!.advisor.label,
                    style: TextStyle(color: colorScheme.outline, fontSize: 12),
                  ),
                  const Spacer(),
                  if (_currentQuest!.suggestedOffering > 0)
                    Text(
                      '目安: ¥${_currentQuest!.suggestedOffering}',
                      style: TextStyle(color: colorScheme.outline, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openTrialQuest,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    _currentQuest!.isCompleted ? '講評を確認する' : '試練に臨む',
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
