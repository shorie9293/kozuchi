import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:kozuchi/core/widgets/washi_background.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/domain/services/guardian_switch_service.dart';
import 'package:kozuchi/domain/models/level_stage.dart';

import 'package:kozuchi/features/daily_quest/presentation/state/daily_quest_notifier.dart';
import 'package:kozuchi/features/daily_quest/data/quest_action.dart';
import 'package:kozuchi/features/daily_quest/presentation/widgets/daily_quest_list.dart';
import 'package:kozuchi/features/daily_quest/presentation/widgets/quest_achievement_effect.dart';
import 'package:kozuchi/features/hp_bar/presentation/widgets/hp_bar_widget.dart';
import 'package:kozuchi/features/exp_gauge/presentation/widgets/exp_gauge_widget.dart';
import 'package:kozuchi/features/advisor_selection/presentation/advisor_selection_screen.dart';
import 'package:kozuchi/features/trial_quest/presentation/screens/trial_quest_screen.dart';
import 'package:kozuchi/features/effects/presentation/effect_manager.dart';
import 'package:kozuchi/features/pinch_zone/presentation/widgets/pinch_zone_overlay.dart';
import 'package:kozuchi/features/pinch_zone/presentation/widgets/pinch_zone_warning_banner.dart';
import 'package:kozuchi/features/analysis_chart/presentation/widgets/analysis_chart_widget.dart';
import 'package:kozuchi/features/shared/data/kozuchi_quest_exporter.dart';
import 'package:kozuchi/features/shared/data/player_repository.dart';
import 'package:kozuchi/features/careerCoach/data/careerCoach_book_bonus_service.dart';
import 'package:kozuchi/features/rpg_task_bonus/data/rpg_task_bonus_service.dart';
import 'package:kozuchi/features/tsundoku/data/tsundoku_gold_luck_buff_service.dart';
import 'package:kozuchi/features/goal_spending/presentation/widgets/goal_spending_gauge.dart';
import 'package:kozuchi/features/budget/presentation/screens/budget_settings_screen.dart';
import 'package:kozuchi/features/budget/presentation/widgets/budget_warning_banner.dart';
import 'package:kozuchi/features/budget/domain/daily_budget.dart';
import 'package:kozuchi/features/budget/data/daily_budget_service.dart';
import 'package:kozuchi/features/shared/data/budget_repository.dart';
import 'package:kozuchi/features/period_comparison/presentation/widgets/period_comparison_summary.dart';
import 'package:kozuchi/features/achievements/data/achievement_service.dart';
import 'package:kozuchi/features/achievements/presentation/screens/achievement_list_screen.dart';
import 'package:kozuchi/features/achievements/presentation/widgets/achievement_unlock_overlay.dart';
import 'package:kozuchi/features/goals/data/goal_api_service.dart';
import 'package:kozuchi/core/infrastructure/auth_service.dart';
import 'package:kozuchi/features/goals/presentation/screens/goal_list_screen.dart';
import 'package:kozuchi/features/transaction_history/presentation/screens/transaction_history_page.dart';
import 'package:kozuchi/features/summary_chart/presentation/screens/summary_screen.dart';
import 'package:kozuchi/features/collaboration_dashboard/presentation/screens/collaboration_dashboard_screen.dart';
import 'package:kozuchi/core/infrastructure/env.dart';

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
  /// 既に通知済みの解除済み実績キー（セッション内重複通知防止）
  static final Set<String> _knownUnlockedKeys = {};

  late PlayerModel _player;
  TrialQuest? _currentQuest;
  bool _isUraMode = false;
  bool _isLoading = true;
  late final DailyQuestNotifier _dailyQuestNotifier;
  bool _dailyQuestsLoaded = false;

  // 予算表示用の状態
  int _budgetAmount = 0;
  int _monthlyExpenditure = 0;
  double _warningThreshold = 0.8;
  DailyBudget _displayBudget = DailyBudget.empty();

  @override
  void initState() {
    super.initState();
    _player = widget.initialPlayer ?? PlayerModel.defaultPlayer();
    _currentQuest = _createInitialQuest();
    _dailyQuestNotifier = DailyQuestNotifier();
    _loadSavedState();
    _loadDailyQuests();
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
        _checkNewAchievements();
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
        _checkNewAchievements();
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

  /// デイリークエストを読み込む
  ///
  /// アプリ起動時または日付跨ぎ時に、今日のクエストを割り当て・読み込む。
  /// テスト用に初期プレイヤーが指定されている場合はスキップ。
  Future<void> _loadDailyQuests() async {
    if (widget.initialPlayer != null) return;

    try {
      // 予算情報を取得（DailyBudgetServiceで計算）
      final dailyBudgetService = DailyBudgetService();
      final dailyBudget = await dailyBudgetService.calculate();
      final budgetIsSet = !dailyBudget.isBudgetNotSet;
      final dailyBudgetAmount = dailyBudget.dailyAllowance;

      // 予算表示用の状態を保存
      final budgetRepo = const BudgetRepository();
      final threshold = await budgetRepo.loadWarningThreshold();
      if (mounted) {
        setState(() {
          _budgetAmount = dailyBudget.monthlyBudget;
          _monthlyExpenditure = dailyBudget.totalSpent;
          _warningThreshold = threshold;
          _displayBudget = dailyBudget;
        });
      }

      await _dailyQuestNotifier.loadQuestsForToday(
        budgetIsSet: budgetIsSet,
        dailyBudgetAmount: dailyBudgetAmount,
        allCategoriesUsedRecently: false, // TODO: 実際のカテゴリ使用状況を取得
        yesterdayWasHighSpending: false,   // TODO: 前日の支出分析
      );

      // 日跨ぎ時に前日未達成クエストのSATORIペナルティを適用
      final satoriPenalty = _dailyQuestNotifier.lastSatoriPenalty;
      if (satoriPenalty > 0 && mounted) {
        setState(() {
          _player = _player.addExp(-satoriPenalty);
        });
        _persistState();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🌅 日が変わった… 昨日の未達成クエストによりSATORI -$satoriPenalty',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      if (mounted) {
        setState(() => _dailyQuestsLoaded = true);
      }
    } catch (_) {
      // クエスト読み込み失敗時もアプリは継続
      if (mounted) {
        setState(() => _dailyQuestsLoaded = true);
      }
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

  /// 新たに解除された実績をチェックして通知する
  void _checkNewAchievements() {
    final userId = AuthService.currentUserId;
    if (userId == null) return;

    final service = AchievementService();
    service.fetchAchievements(userId: userId).then((achievements) {
      if (!mounted) return;
      final newlyUnlocked = achievements
          .where((a) => a.unlocked && !_knownUnlockedKeys.contains(a.key))
          .toList();
      if (newlyUnlocked.isNotEmpty) {
        for (final a in newlyUnlocked) {
          _knownUnlockedKeys.add(a.key);
        }
        // ポップアップで実績解除を演出
        showAchievementUnlockPopup(context, newlyUnlocked);
      }
      // 既存の解除済み実績もキャッシュに追加
      for (final a in achievements.where((a) => a.unlocked)) {
        _knownUnlockedKeys.add(a.key);
      }
    }).catchError((_) {
      // 実績通知は非クリティカル — 失敗してもアプリは継続
    });
  }

  /// 現在のクエストを共有ストレージに書き出す
  /// 試練が未契約状態（title == 'アドバイザーと契約せよ'）の場合は書き出さない
  void _exportCurrentQuest() {
    if (_currentQuest != null && _currentQuest!.title != 'アドバイザーと契約せよ') {
      widget.exporter.export(_currentQuest);
    }
  }

  /// 支出記録時にデイリークエスト進捗を検出し、達成時はEXPを付与する
  void _onExpenseRecorded(int amount, String category) {
    final completed = _dailyQuestNotifier.detectAction(
      QuestAction.expenseRecorded(amount: amount, category: category),
    );

    if (completed.isNotEmpty) {
      final totalExp = completed.fold<int>(0, (sum, q) => sum + q.expReward);
      if (totalExp > 0) {
        setState(() {
          _player = _player.addExp(totalExp);
        });
        _persistState();
        // 永続化（SharedPreferencesに保存）
        _dailyQuestNotifier.persist();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✨ デイリークエスト達成！ ${completed.map((q) => q.title).join('、')} EXP +$totalExp',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
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

  void _openGuardianSwitch() async {
    final oldAdvisor = _player.advisor;
    if (oldAdvisor == null) return;

    final deity = await Navigator.of(context).push<Advisor>(
      MaterialPageRoute(
        builder: (_) => AdvisorSelectionScreen(
          onSelected: (selected) {
            Navigator.of(context).pop(selected);
          },
        ),
      ),
    );

    if (deity == null || !mounted) return;

    final result = const GuardianSwitchService().switchGuardian(_player, deity);
    if (!result.isSuccess) {
      final msg = result.error == GuardianSwitchError.insufficientExp
          ? 'EXPが不足しています'
          : result.error == GuardianSwitchError.alreadyContracted
              ? 'すでに同じ守護神です'
              : 'クールダウン中です';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }

    setState(() {
      _player = result.player!;
      _currentQuest = _createInitialQuest();
    });
    _persistState();
    _exportCurrentQuest();

    // 切替演出エフェクトを発火（全画面オーバーレイ）
    EffectManager.of(context).playEffect(
      'guardian_switch',
      Offset.zero,
      parameters: {
        'oldAdvisor': oldAdvisor.index,
        'newAdvisor': deity.index,
      },
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
          onExpenseRecorded: (amount, category) {
            _onExpenseRecorded(amount, category);
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
            // 予算設定後に必要なUI再描画
          },
        ),
      ),
    );
    _refreshBudgetDisplay();
  }

  /// 予算表示データを再読み込みする
  Future<void> _refreshBudgetDisplay() async {
    final dailyBudgetService = DailyBudgetService();
    final dailyBudget = await dailyBudgetService.calculate();
    final budgetRepo = const BudgetRepository();
    final threshold = await budgetRepo.loadWarningThreshold();
    if (mounted) {
      setState(() {
        _budgetAmount = dailyBudget.monthlyBudget;
        _monthlyExpenditure = dailyBudget.totalSpent;
        _warningThreshold = threshold;
        _displayBudget = dailyBudget;
      });
    }
    // デイリークエストも予算変更に応じて再読み込み
    _loadDailyQuests();
  }

  void _openAchievementList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AchievementListScreen(),
      ),
    );
  }

  void _openGoalList() {
    final apiService = GoalApiService(baseUrl: Env.goalsApiUrl);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoalListScreen(apiService: apiService),
      ),
    );
  }

  void _openTransactionHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TransactionHistoryPage(),
      ),
    );
  }

  void _openSummary() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SummaryScreen(),
      ),
    );
  }

  void _openCollaborationDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CollaborationDashboardScreen(
          player: _player,
        ),
      ),
    );
  }

  bool get _canUseUraMode => _player.levelStage == LevelStage.kuu;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
        backgroundColor: _isUraMode ? colorScheme.surface : null,
        foregroundColor: _isUraMode ? colorScheme.onSurface : null,
      ),
      body: WashiBackground(
        child: PinchZoneOverlay(
          isPinchState: _player.isPinchState,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🎯 目標支出ゲージ（主役・最上部）
                GoalSpendingGauge(
                  monthlyBudget: _budgetAmount,
                  totalSpent: _monthlyExpenditure,
                  remainingDays: _displayBudget.remainingDays,
                  onTapBudget:
                      _budgetAmount == 0 ? _openBudgetSettings : null,
                ),
                const SizedBox(height: 8),
                // HP/EXPコンパクト表示
                _buildHpExpCompactRow(colorScheme),
                // ピンチゾーン警告バナー（HPバー直下）
                if (_player.isPinchState) ...[
                  const SizedBox(height: 8),
                  PinchZoneWarningBanner(player: _player),
                ],
                // 予算超過接近時の警告バナー
                if (_budgetAmount > 0 &&
                    _monthlyExpenditure >= _budgetAmount * _warningThreshold) ...[
                  const SizedBox(height: 8),
                  BudgetWarningBanner(
                    spentAmount: _monthlyExpenditure,
                    budgetAmount: _budgetAmount,
                    ratio: _budgetAmount > 0
                        ? _monthlyExpenditure / _budgetAmount
                        : 0.0,
                    threshold: _warningThreshold,
                  ),
                ],
                const SizedBox(height: 16),
                // 🔮 現在の加護（常時表示）
                _buildGuardianBlessingLine(colorScheme),
                const SizedBox(height: 12),
                // 📋 デイリークエスト
                _buildDailyQuestSection(colorScheme),
                const SizedBox(height: 12),
                // 3カードグリッド（収入/試練/加護）
                _buildCardGrid(colorScheme),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  /// 📋 デイリークエストセクション
  Widget _buildDailyQuestSection(ColorScheme colorScheme) {
    if (!_dailyQuestsLoaded) {
      return const SizedBox.shrink();
    }

    final quests = _dailyQuestNotifier.state?.quests ?? [];

    return ListenableBuilder(
      listenable: _dailyQuestNotifier,
      builder: (context, _) {
        final currentQuests = _dailyQuestNotifier.state?.quests ?? [];
        final allCompleted = _dailyQuestNotifier.isAllCompleted;

        return DailyQuestList(
          quests: currentQuests,
          isLoading: _dailyQuestNotifier.isLoading && currentQuests.isEmpty,
          errorMessage: _dailyQuestNotifier.errorMessage,
          onRetry: () => _loadDailyQuests(),
          allCompletedEffect: allCompleted
              ? QuestAchievementEffect(showAllComplete: true)
              : null,
          onQuestTap: (quest) {
            // 将来のクエスト詳細画面用
          },
        );
      },
    );
  }

  /// HPバーとEXPゲージを横並びのコンパクトなRowで表示
  Widget _buildHpExpCompactRow(ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AnimatedOpacity(
            opacity: (_isUraMode && _canUseUraMode) ? 0.3 : 1.0,
            duration: const Duration(milliseconds: 600),
            child: HpBarWidget(
              player: _player,
              budgetAmount: _budgetAmount,
              monthlyExpenditure: _monthlyExpenditure,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ExpGaugeWidget(player: _player),
        ),
      ],
    );
  }

  /// 🔮 現在の加護（常時表示用コンパクト行）
  Widget _buildGuardianBlessingLine(ColorScheme colorScheme) {
    final advisor = _player.advisor;
    if (advisor != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.withValues(alpha: 0.1),
              Colors.amber.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Text('🔮', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '現在の加護: ${advisor.emoji} ${advisor.label}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'EXP${advisor.expMultiplierText}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Text('🔮', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '加護なし',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            GestureDetector(
              onTap: _openAdvisorSelection,
              child: Text(
                '契約する →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  /// 3カードグリッド：収入カード / 試練カード / 加護カード
  Widget _buildCardGrid(ColorScheme colorScheme) {
    return Column(
      children: [
        // 1行目：目標カード + 試練カード
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildGoalCard(colorScheme)),
            const SizedBox(width: 12),
            Expanded(child: _buildTrialCard(colorScheme)),
          ],
        ),
        const SizedBox(height: 12),
        // 2行目：加護カード（全幅）
        _buildProtectionCard(colorScheme),
      ],
    );
  }

  /// 🎯 目標カード
  Widget _buildGoalCard(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GoalSpendingGauge(
              monthlyBudget: _budgetAmount,
              totalSpent: _monthlyExpenditure,
              remainingDays: _displayBudget.remainingDays,
              onTapBudget:
                  _budgetAmount == 0 ? _openBudgetSettings : null,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                InkWell(
                  onTap: _openBudgetSettings,
                  child: const Text('💵 予算', style: TextStyle(fontSize: 11)),
                ),
                InkWell(
                  onTap: _openAchievementList,
                  child: const Text('🏆 実績', style: TextStyle(fontSize: 11)),
                ),
                InkWell(
                  onTap: _openGoalList,
                  child: const Text('🎯 目標', style: TextStyle(fontSize: 11)),
                ),
                InkWell(
                  onTap: _openTransactionHistory,
                  child: const Text('📋 履歴', style: TextStyle(fontSize: 11)),
                ),
                InkWell(
                  onTap: _openSummary,
                  child: const Text('📊 分析', style: TextStyle(fontSize: 11)),
                ),
                InkWell(
                  onTap: _openCollaborationDashboard,
                  child: const Text('🔗 連携', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 📜 試練カード
  Widget _buildTrialCard(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('📜 試練',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                if (_currentQuest?.isCompleted == true)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '完了',
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onPrimaryContainer),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_player.advisor == null) ...[
              Text(
                'まだアドバイザーと契約していない',
                style: TextStyle(color: colorScheme.outline, fontSize: 12),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openAdvisorSelection,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('契約する'),
                ),
              ),
            ] else ...[
              if (_currentQuest != null) ...[
                Text(
                  _currentQuest!.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _currentQuest!.description,
                  style: TextStyle(
                      color: colorScheme.onSurfaceVariant, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(_currentQuest!.advisor.emoji,
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _currentQuest!.advisor.label,
                        style: TextStyle(
                            color: colorScheme.outline, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_currentQuest!.suggestedOffering > 0)
                      Text(
                        '¥${_currentQuest!.suggestedOffering}',
                        style: TextStyle(
                            color: colorScheme.outline, fontSize: 11),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openTrialQuest,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(
                      _currentQuest!.isCompleted ? '講評を確認' : '試練に臨む',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 🛡️ 加護カード（アドバイザー情報 + 開眼段階 + 裏面モード切替）
  Widget _buildProtectionCard(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // タイトル行（テーマ切替 + 裏面モード切替）
            Row(
              children: [
                const Text('🛡️ 加護',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                if (widget.onToggleTheme != null)
                  IconButton(
                    icon: Icon(widget.themeIcon, size: 20),
                    tooltip: 'テーマ切替',
                    onPressed: widget.onToggleTheme,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (_canUseUraMode)
                  IconButton(
                    icon: Icon(
                      _isUraMode ? Icons.wb_sunny : Icons.nights_stay,
                      size: 20,
                    ),
                    tooltip:
                        _isUraMode ? '表モードに戻る' : '裏モードに切替',
                    onPressed: _toggleUraMode,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // アドバイザー情報
            if (_player.advisor != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_player.advisor!.emoji} ${_player.advisor!.label}',
                  style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(height: 8),
              // 効果詳細
              _buildAdvisorEffectDetail(colorScheme, _player.advisor!),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed:
                    _player.isInCooldown ? null : _openGuardianSwitch,
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: Text(
                  _player.isInCooldown
                      ? '守護神切替 (あと${_player.remainingCooldown!.inDays}日)'
                      : '守護神切替',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ] else
              TextButton.icon(
                onPressed: _openAdvisorSelection,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('アドバイザーと契約'),
              ),
            const SizedBox(height: 12),
            // 開眼段階バッジ（コンパクト版）
            _buildLevelBadgeCompact(colorScheme),
            // 裏面モード時の分析チャート・期間比較（加護カード内に収納）
            if (_isUraMode && _canUseUraMode) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: Text(
                    '🌌 マスター領域',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.withValues(alpha: 0.8),
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
              const AnalysisChartWidget(
                key: Key('analysisChart'),
                isVisible: true,
              ),
              const SizedBox(height: 12),
              const PeriodComparisonSummary(
                key: Key('periodComparisonSummary'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// アドバイザーの効果詳細表示
  Widget _buildAdvisorEffectDetail(ColorScheme colorScheme, Advisor advisor) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  advisor.effect,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('🎤', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  advisor.trialStyle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'EXP${advisor.expMultiplierText}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 開眼段階バッジ（コンパクト版）
  Widget _buildLevelBadgeCompact(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.secondaryContainer,
            colorScheme.tertiaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Text('🧘', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '開眼段階: ${_player.levelStage.label}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                Text(
                  _player.levelStage.description,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
}
