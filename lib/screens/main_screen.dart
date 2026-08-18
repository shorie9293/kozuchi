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
import 'package:kozuchi/features/hp_bar/presentation/widgets/hp_bar_widget.dart';
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
import 'package:kozuchi/features/income/presentation/screens/income_input_screen.dart';
import 'package:kozuchi/features/csv_import/presentation/screens/csv_import_screen.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_auto_recorder.dart';
import 'package:kozuchi/features/recurring_transaction/presentation/screens/recurring_transaction_screen.dart';
import 'package:kozuchi/features/transaction_history/presentation/screens/transaction_history_page.dart';
import 'package:kozuchi/features/summary_chart/presentation/screens/summary_screen.dart';
import 'package:kozuchi/features/collaboration_dashboard/presentation/screens/collaboration_dashboard_screen.dart';
import 'package:kozuchi/core/infrastructure/env.dart';
import 'package:kozuchi/core/infrastructure/cloud_sync_service.dart';
import 'package:kozuchi/core/infrastructure/supabase_provider.dart';
import 'package:kozuchi/domain/services/expense_entry_recording_service.dart';
import 'package:kozuchi/domain/services/supabase_expense_repository.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/domain/classifier/classifier_service.dart';

/// メイン画面
///
/// 目標支出ゲージ + 3タブ（目標/試練/加護）+ 支出FAB
class MainScreen extends StatefulWidget {
  final PlayerModel? initialPlayer;
  final KozuchiQuestExporter exporter;
  final PlayerRepository repository;
  final ThemeMode themeMode;
  final IconData themeIcon;
  final VoidCallback? onToggleTheme;

  /// 支出明細の保存先。null の場合は Supabase（expense_entries）を使用する。
  final ExpenseRepository? expenseRepository;

  const MainScreen({
    super.key,
    this.initialPlayer,
    this.exporter = const KozuchiQuestExporter(),
    this.repository = const PlayerRepository(),
    this.themeMode = ThemeMode.system,
    this.themeIcon = Icons.brightness_auto,
    this.onToggleTheme,
    this.expenseRepository,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  static final Set<String> _knownUnlockedKeys = {};

  late PlayerModel _player;
  TrialQuest? _currentQuest;
  bool _isUraMode = false;
  bool _isLoading = true;
  late final DailyQuestNotifier _dailyQuestNotifier;
  bool _dailyQuestsLoaded = false;

  int _budgetAmount = 0;
  int _monthlyExpenditure = 0;
  double _warningThreshold = 0.8;
  DailyBudget _displayBudget = DailyBudget.empty();

  late final TabController _tabController;
  ExpenseRepository? _expenseRepository;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _player = widget.initialPlayer ?? PlayerModel.defaultPlayer();
    _currentQuest = _createInitialQuest();
    _dailyQuestNotifier = DailyQuestNotifier();
    _loadSavedState();
    _loadDailyQuests();
    _runRecurringAutoRecord();
  }

  /// アプリ起動時に定期取引を自動記録する（fire-and-forget）。
  Future<void> _runRecurringAutoRecord() async {
    try {
      await const RecurringAutoRecorder().run();
    } catch (_) {
      // 自動記録の失敗はアプリ起動を妨げない
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedState() async {
    if (widget.initialPlayer != null) {
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
        if (savedPlayer != null) _player = savedPlayer;
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

  Future<void> _persistState() async {
    await widget.repository.savePlayer(_player);
    if (_currentQuest != null) {
      await widget.repository.saveQuest(_currentQuest!);
    }
  }

  Future<void> _loadDailyQuests() async {
    if (widget.initialPlayer != null) return;
    try {
      final dailyBudgetService = DailyBudgetService();
      final dailyBudget = await dailyBudgetService.calculate();
      final budgetIsSet = !dailyBudget.isBudgetNotSet;
      final dailyBudgetAmount = dailyBudget.dailyAllowance;
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
        allCategoriesUsedRecently: false,
        yesterdayWasHighSpending: false,
      );
      final satoriPenalty = _dailyQuestNotifier.lastSatoriPenalty;
      if (satoriPenalty > 0 && mounted) {
        setState(() => _player = _player.addExp(-satoriPenalty));
        _persistState();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🌅 日が変わった… 昨日の未達成クエストによりSATORI -$satoriPenalty'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      if (mounted) setState(() => _dailyQuestsLoaded = true);
    } catch (_) {
      if (mounted) setState(() => _dailyQuestsLoaded = true);
    }
  }

  void _checkCareerCoachBookBonus() {
    final advisor = _player.advisor;
    if (advisor == null) return;
    const service = CareerCoachBookBonusService();
    service.checkAndConsume(advisor).then((result) {
      if (result != null && mounted) {
        setState(() => _player = _player.addExp(result.bonusExp));
        _persistState();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📚 キャリアコーチボーナス！『${result.bookTitle}』の蔵書追加でEXP +${result.bonusExp}')),
        );
      }
    });
  }

  void _checkRpgTaskBonus() {
    const service = RpgTaskBonusService();
    service.checkAndConsume().then((result) {
      if (result != null && mounted) {
        final rankEmoji = switch (result.questRank) {
          'S' => '👹', 'A' => '👺', _ => '👾',
        };
        setState(() => _player = _player.addExp(result.bonusExp));
        _persistState();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$rankEmoji rpg-task討伐ボーナス！『${result.taskTitle}』討伐でEXP +${result.bonusExp}')),
        );
      }
    });
  }

  void _checkTsundokuBookCompletion() {
    const service = TsundokuGoldLuckBuffService();
    service.checkAndConsume().then((buff) {
      if (buff != null && mounted) {
        setState(() => _player = _player.applyGoldLuckBuff(buff));
        _persistState();
        final bookInfo = buff.bookTitle != null ? '『${buff.bookTitle}』' : '本';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text('📖✨ 金運上昇！${bookInfo}を読了した祝福で、${buff.remainingDisplay}の間収入が${buff.multiplier.toInt()}倍に！'),
          ),
        );
      }
    });
  }

  void _checkNewAchievements() {
    final userId = AuthService.currentUserId;
    if (userId == null) return;
    final service = AchievementService();
    service.fetchAchievements(userId: userId).then((achievements) {
      if (!mounted) return;
      final newlyUnlocked = achievements.where((a) => a.unlocked && !_knownUnlockedKeys.contains(a.key)).toList();
      if (newlyUnlocked.isNotEmpty) {
        for (final a in newlyUnlocked) {
          _knownUnlockedKeys.add(a.key);
        }
        showAchievementUnlockPopup(context, newlyUnlocked);
      }
      for (final a in achievements.where((a) => a.unlocked)) {
        _knownUnlockedKeys.add(a.key);
      }
    }).catchError((_) {});
  }

  void _exportCurrentQuest() {
    if (_currentQuest != null && _currentQuest!.title != 'アドバイザーと契約せよ') {
      widget.exporter.export(_currentQuest);
    }
  }

  void _onExpenseRecorded(int amount, String category) {
    // 月間支出集計に記録
    const DailyBudgetService().recordSpending(amount);
    setState(() {
      _monthlyExpenditure += amount;
    });

    // 個別明細（ExpenseEntry）を Supabase expense_entries に保存（案B・一本化）
    _recordExpenseDetail(amount, category);

    final completed = _dailyQuestNotifier.detectAction(
      QuestAction.expenseRecorded(amount: amount, category: category),
    );
    if (completed.isNotEmpty) {
      final totalExp = completed.fold<int>(0, (sum, q) => sum + q.expReward);
      if (totalExp > 0) {
        setState(() => _player = _player.addExp(totalExp));
        _persistState();
        _dailyQuestNotifier.persist();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✨ デイリークエスト達成！ ${completed.map((q) => q.title).join('、')} EXP +$totalExp')),
          );
        }
      }
    }
  }

  /// 支出明細（ExpenseEntry）をリポジトリ経由で保存する（fire-and-forget）。
  ///
  /// 保存失敗や Supabase 未認証でも記録フローを妨げないよう防御する。
  void _recordExpenseDetail(int amount, String category) {
    try {
      final classification = ClassifierService.instance.classify(category);
      final service = ExpenseEntryRecordingService(
        repository: _getExpenseRepository(),
      );
      // fire-and-forget: 失敗は service 内で null に丸められる
      service.record(
        amount: amount,
        category: classification.category,
        note: category,
      );
    } catch (_) {
      // 明細保存の失敗は記録フローを中断させない
    }
  }

  /// 支出明細の保存先リポジトリを取得する。
  ///
  /// [expenseRepository] が注入されていればそれを用い、null なら
  /// Supabase（expense_entries）を遅延初期化する。
  ExpenseRepository _getExpenseRepository() {
    if (widget.expenseRepository != null) return widget.expenseRepository!;
    return _expenseRepository ??= SupabaseExpenseRepository(
      cloudStore: CloudSyncService(client: SupabaseProvider.client),
      userIdProvider: () => SupabaseProvider.currentUserId,
    );
  }

  TrialQuest _createInitialQuest() {
    if (_player.advisor == null) {
      return TrialQuest(
        title: 'アドバイザーと契約せよ',
        description: 'まずは四天の守護神から1柱を選び、契約を結べ。',
        suggestedOffering: 0,
        advisor: Advisor.daikokuten,
      );
    }
    return TrialQuest(
      title: '試練を待て',
      description: '守護神からの試練を待っている…',
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
          onSelected: (selected) => Navigator.of(context).pop(selected),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    setState(() {
      _player = result.player!;
      _currentQuest = _createInitialQuest();
    });
    _persistState();
    _exportCurrentQuest();
    EffectManager.of(context).playEffect('guardian_switch', Offset.zero,
      parameters: {'oldAdvisor': oldAdvisor.index, 'newAdvisor': deity.index});
  }

  void _openTrialQuest() {
    if (_currentQuest == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrialQuestScreen(
          quest: _currentQuest!,
          player: _player,
          onQuestUpdated: (quest, player) {
            setState(() { _currentQuest = quest; _player = player; });
            _persistState();
            _exportCurrentQuest();
          },
          onExpenseRecorded: (amount, category) => _onExpenseRecorded(amount, category),
        ),
      ),
    );
  }

  /// 支出FAB — 常時表示の支出記録ボタン
  void _openQuickOffering() {
    // 簡易支出記録: 試練がなくても支出を記録できる
    if (_currentQuest == null || _currentQuest!.isOfferingRecorded) {
      // クエストがない/完了済みなら新規簡易クエストで
      final quest = _player.advisor != null
          ? TrialQuest(title: '喜捨の記録', description: '日々の支出を記録せよ', suggestedOffering: 0, advisor: _player.advisor!)
          : TrialQuest(title: '喜捨の記録', description: '日々の支出を記録せよ', suggestedOffering: 0, advisor: Advisor.daikokuten);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrialQuestScreen(
            quest: quest,
            player: _player,
            onQuestUpdated: (q, p) { setState(() { _currentQuest = q; _player = p; }); _persistState(); _exportCurrentQuest(); },
            onExpenseRecorded: (amount, category) => _onExpenseRecorded(amount, category),
          ),
        ),
      );
    } else {
      _openTrialQuest();
    }
  }

  void _toggleUraMode() {
    setState(() => _isUraMode = !_isUraMode);
  }

  void _openBudgetSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BudgetSettingsScreen(repository: const BudgetRepository(), onSaved: () {})),
    );
    _refreshBudgetDisplay();
  }

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
    _loadDailyQuests();
  }

  void _openAchievementList() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AchievementListScreen()));
  }

  void _openGoalList() {
    final apiService = GoalApiService(baseUrl: Env.goalsApiUrl);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GoalListScreen(apiService: apiService)));
  }

  void _openTransactionHistory() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransactionHistoryPage()));
  }

  void _openCsvImport() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CsvImportScreen()));
  }

  void _openRecurringTransaction() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecurringTransactionScreen()));
  }

  void _openSummary() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SummaryScreen()));
  }

  void _openCollaborationDashboard() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CollaborationDashboardScreen(player: _player)));
  }

  /// 収入入力画面 — v2.0刷新: 残高調整不可を解決する入口
  ///
  /// IncomeInputScreen で記録した収入を PlayerModel.addHp で加算し、
  /// 即座に状態反映＋永続化する。これによりホームの残高表示が更新される。
  Future<void> _openIncomeInput() async {
    final result = await Navigator.of(context).push<IncomeResult>(
      MaterialPageRoute(
        builder: (_) => IncomeInputScreen(player: _player),
      ),
    );
    if (result != null && mounted) {
      setState(() => _player = result.updatedPlayer);
      _persistState();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💰 収入を記録しました: ¥${result.amount}（${result.source}）'),
        ),
      );
    }
  }

  bool get _canUseUraMode => _player.levelStage == LevelStage.kuu;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: AppKeys.mainScreen,
      appBar: AppBar(
        title: const Text('打ち出の小槌'),
        centerTitle: true,
        backgroundColor: _isUraMode ? colorScheme.surface : null,
        foregroundColor: _isUraMode ? colorScheme.onSurface : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '🎯 目標'),
            Tab(text: '📜 試練'),
            Tab(text: '🛡️ 加護'),
          ],
        ),
      ),
      body: WashiBackground(
        child: PinchZoneOverlay(
          isPinchState: _player.isPinchState,
          child: Column(
            children: [
              // 固定ヘッダー部
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: GoalSpendingGauge(
                  monthlyBudget: _budgetAmount,
                  totalSpent: _monthlyExpenditure,
                  remainingDays: _displayBudget.remainingDays,
                  onTapBudget: _budgetAmount == 0 ? _openBudgetSettings : null,
                ),
              ),
              // 警告バナー
              if (_player.isPinchState)
                PinchZoneWarningBanner(player: _player),
              if (_budgetAmount > 0 && _monthlyExpenditure >= _budgetAmount * _warningThreshold)
                BudgetWarningBanner(
                  spentAmount: _monthlyExpenditure,
                  budgetAmount: _budgetAmount,
                  ratio: _budgetAmount > 0 ? _monthlyExpenditure / _budgetAmount : 0.0,
                  threshold: _warningThreshold,
                ),
              // タブコンテンツ
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGoalTab(colorScheme),
                    _buildQuestTab(colorScheme),
                    _buildGuardianTab(colorScheme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openQuickOffering,
        tooltip: '支出を記録',
        child: const Icon(Icons.edit_note),
      ),
    );
  }

  /// 🎯 目標タブ
  ///
  /// v2.0刷新: 6つの独立した全幅ボタンを2列のコンパクトグリッドに再構成。
  /// 視覚ノイズを減らし、一画面により多くの情報を高密度に配置する。
  Widget _buildGoalTab(ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // HPバー（残高）— v2.0刷新: 収入記録の結果を即座に視覚確認できるよう配置
        HpBarWidget(
          player: _player,
          budgetAmount: _budgetAmount,
          monthlyExpenditure: _monthlyExpenditure,
        ),
        const SizedBox(height: 16),
        // EXPゲージ（コンパクト）
        const SizedBox(height: 4),
        ExpGaugeWidget(player: _player),
        const SizedBox(height: 16),
        // クイックリンク — 2列グリッドで情報密度向上
        _buildQuickLinkGrid(colorScheme),
        // 裏面モードリンク
        if (_canUseUraMode) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _toggleUraMode,
            icon: Icon(_isUraMode ? Icons.wb_sunny : Icons.nights_stay),
            label: Text(_isUraMode ? '表モードに戻る' : '🌌 マスター領域'),
          ),
          if (_isUraMode) ...[
            const SizedBox(height: 12),
            const AnalysisChartWidget(key: Key('analysisChart'), isVisible: true),
            const SizedBox(height: 12),
            const PeriodComparisonSummary(key: Key('periodComparisonSummary')),
          ],
        ],
      ],
    );
  }

  /// 📜 試練タブ
  Widget _buildQuestTab(ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 🔮 守護神 簡易表示
        _buildGuardianBlessingLine(colorScheme),
        const SizedBox(height: 12),
        // 試練カード
        _buildTrialCard(colorScheme),
        const SizedBox(height: 16),
        // デイリークエスト
        _buildDailyQuestSection(colorScheme),
      ],
    );
  }

  /// 🛡️ 加護タブ
  Widget _buildGuardianTab(ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_player.advisor != null) ...[
          // 守護神カード
          _buildAdvisorDetailCard(colorScheme),
          const SizedBox(height: 16),
        ] else
          _buildAdvisorContractPrompt(colorScheme),
        // テーマ切替
        if (widget.onToggleTheme != null)
          IconButton(
            icon: Icon(widget.themeIcon),
            tooltip: 'テーマ切替',
            onPressed: widget.onToggleTheme,
          ),
        // 開眼段階
        _buildLevelBadgeCompact(colorScheme),
      ],
    );
  }

  /// v2.0刷新: 全幅ボタン群を2列のコンパクトグリッドに集約し、
  /// 視覚ノイズを減らしつつ一画面での情報密度を上げる。
  Widget _buildQuickLinkGrid(ColorScheme colorScheme) {
    final links = <_QuickLink>[
      _QuickLink('💰 収入を記録', _openIncomeInput),
      _QuickLink('💵 予算を設定', _openBudgetSettings),
      _QuickLink('🏆 実績', _openAchievementList),
      _QuickLink('🎯 貯蓄目標', _openGoalList),
      _QuickLink('📋 取引履歴', _openTransactionHistory),
      _QuickLink('📥 CSV取り込み', _openCsvImport),
      _QuickLink('🔁 定期取引', _openRecurringTransaction),
      _QuickLink('📊 支出分析', _openSummary),
      _QuickLink('🔗 アプリ連携', _openCollaborationDashboard),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.6,
      children: [
        for (final link in links)
          OutlinedButton(
            onPressed: link.onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerLeft,
            ),
            child: Text(link.label, style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
  }

  Widget _buildAdvisorDetailCard(ColorScheme colorScheme) {
    final advisor = _player.advisor!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(advisor.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(advisor.label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            const SizedBox(height: 4),
            Text(advisor.domain, style: TextStyle(color: colorScheme.outline)),
            const SizedBox(height: 8),
            Text(advisor.role, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            // 加護（機能的影響）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: Colors.amber),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(advisor.blessing, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade800)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('講評: ${advisor.trialStyle}', style: TextStyle(fontSize: 11, color: colorScheme.outline)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _player.isInCooldown ? null : _openGuardianSwitch,
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: Text(_player.isInCooldown ? '守護神切替 (あと${_player.remainingCooldown!.inDays}日)' : '守護神切替',
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvisorContractPrompt(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('🔮', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text('まだ守護神と契約していません', style: TextStyle(fontSize: 16, color: colorScheme.onSurface)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openAdvisorSelection,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('守護神と契約する'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuardianBlessingLine(ColorScheme colorScheme) {
    final advisor = _player.advisor;
    if (advisor == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.amber.withValues(alpha: 0.1), Colors.amber.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Text('🔮', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text('${advisor.emoji} ${advisor.label}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
            child: Text(advisor.expMultiplierText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialCard(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Text('📜 試練', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              if (_currentQuest?.isCompleted == true)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                    child: Text('完了', style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer))),
            ]),
            const SizedBox(height: 8),
            if (_player.advisor == null) ...[
              Text('まだ守護神と契約していない', style: TextStyle(color: colorScheme.outline, fontSize: 12)),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _openAdvisorSelection, icon: const Icon(Icons.auto_awesome, size: 18), label: const Text('契約する'))),
            ] else if (_currentQuest != null) ...[
              Text(_currentQuest!.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface)),
              const SizedBox(height: 4),
              Text(_currentQuest!.description, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11)),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: _openTrialQuest,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(_currentQuest!.isCompleted ? '講評を確認' : '試練に臨む', style: const TextStyle(fontSize: 12)),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDailyQuestSection(ColorScheme colorScheme) {
    if (!_dailyQuestsLoaded) return const SizedBox.shrink();
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
          allCompletedEffect: allCompleted ? QuestAchievementEffect(showAllComplete: true) : null,
          onQuestTap: (quest) {},
        );
      },
    );
  }

  Widget _buildLevelBadgeCompact(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colorScheme.secondaryContainer, colorScheme.tertiaryContainer]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const Text('🧘', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('開眼段階: ${_player.levelStage.label}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.onSecondaryContainer)),
          Text(_player.levelStage.description, style: TextStyle(fontSize: 11, color: colorScheme.onSecondaryContainer.withValues(alpha: 0.7))),
        ])),
      ]),
    );
  }
}

class _QuickLink {
  final String label;
  final VoidCallback onTap;
  const _QuickLink(this.label, this.onTap);
}
