import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:kozuchi/core/widgets/money_background.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/guardian_deity.dart';
import 'package:kozuchi/domain/models/enlightenment_stage.dart';
import 'package:kozuchi/features/hp_bar/presentation/widgets/hp_bar_widget.dart';
import 'package:kozuchi/features/satori_gauge/presentation/widgets/satori_gauge_widget.dart';
import 'package:kozuchi/features/guardian_selection/presentation/guardian_selection_screen.dart';
import 'package:kozuchi/features/trial_quest/presentation/screens/trial_quest_screen.dart';
import 'package:kozuchi/features/gaki_zone/presentation/widgets/gaki_zone_overlay.dart';
import 'package:kozuchi/features/gaki_zone/presentation/widgets/gaki_zone_warning_banner.dart';
import 'package:kozuchi/features/engi_mandala/presentation/widgets/engi_mandala_widget.dart';
import 'package:kozuchi/features/shared/data/kozuchi_quest_exporter.dart';
import 'package:kozuchi/features/shared/data/player_repository.dart';
import 'package:kozuchi/features/benzaiten/data/benzaiten_book_bonus_service.dart';

/// メイン画面
///
/// HPバー + SATORIゲージ + 現在の試練を表示する
/// アプリの中心画面。
/// 空段階（kuu）到達後は裏面モードに切り替え可能。
class MainScreen extends StatefulWidget {
  /// テスト用の初期プレイヤー（nullの場合はデフォルト値）
  final PlayerModel? initialPlayer;

  /// テスト用に注入可能なKozuchiQuestExporter（デフォルトで実インスタンス）
  final KozuchiQuestExporter exporter;

  /// データ永続化リポジトリ（テスト時にモック注入可能）
  final PlayerRepository repository;

  const MainScreen({
    super.key,
    this.initialPlayer,
    this.exporter = const KozuchiQuestExporter(),
    this.repository = const PlayerRepository(),
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkBenzaitenBookBonus());
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkBenzaitenBookBonus());
    }
  }

  /// 現在の状態を永続化する
  Future<void> _persistState() async {
    await widget.repository.savePlayer(_player);
    if (_currentQuest != null) {
      await widget.repository.saveQuest(_currentQuest!);
    }
  }

  /// 弁財天の蔵書追加ボーナスをチェックして適用する
  ///
  /// tsundoku-quest が共有ストレージに書き出した book_added イベントを読み取り、
  /// 守護神が弁財天の場合に SATORI ボーナスを付与する。
  void _checkBenzaitenBookBonus() {
    final guardian = _player.guardianDeity;
    if (guardian == null) return;

    const service = BenzaitenBookBonusService();
    service.checkAndConsume(guardian).then((result) {
      if (result != null && mounted) {
        setState(() {
          _player = _player.addSatori(result.bonusSatori);
        });
        _persistState();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📚 弁財天ボーナス！『${result.bookTitle}』の蔵書追加でSATORI +${result.bonusSatori}',
            ),
          ),
        );
      }
    });
  }

  /// 現在のクエストを共有ストレージに書き出す
  /// 試練が未契約状態（title == '守護神と契約せよ'）の場合は書き出さない
  void _exportCurrentQuest() {
    if (_currentQuest != null && _currentQuest!.title != '守護神と契約せよ') {
      widget.exporter.export(_currentQuest);
    }
  }

  TrialQuest _createInitialQuest() {
    // 守護神未契約の場合は試練を表示しない
    if (_player.guardianDeity == null) {
      return TrialQuest(
        title: '守護神と契約せよ',
        description: 'まずは四天の守護神から1柱を選び、契約を結べ。',
        suggestedOffering: 0,
        guardianDeity: GuardianDeity.daikokuten,
      );
    }
    return TrialQuest(
      title: '試練を待て',
      description: '守護神からの試練を待っている…',
      suggestedOffering: 0,
      guardianDeity: _player.guardianDeity!,
    );
  }

  void _openGuardianSelection() {
    Navigator.of(context).push<GuardianDeity>(
      MaterialPageRoute(
        builder: (_) => GuardianSelectionScreen(
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

  bool get _canUseUraMode => _player.enlightenmentStage == EnlightenmentStage.kuu;

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
            ? Colors.black87
            : null,
        foregroundColor: _isUraMode
            ? Colors.white70
            : null,
        actions: [
          if (_player.guardianDeity != null)
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
                    '${_player.guardianDeity!.emoji} ${_player.guardianDeity!.label}',
                    style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: MoneyBackground(
        child: GakiZoneOverlay(
          isGakiState: _player.isGakiState,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 餓鬼ゾーン警告バナー
                if (_player.isGakiState) GakiZoneWarningBanner(player: _player),
                // HPバー（裏面モード時はフェードアウト）
                AnimatedOpacity(
                  opacity: (_isUraMode && _canUseUraMode) ? 0.3 : 1.0,
                  duration: const Duration(milliseconds: 600),
                  child: HpBarWidget(player: _player),
                ),
                // 裏面モード時のみ縁起曼荼羅を表示
                if (_isUraMode && _canUseUraMode) ...[
                  const SizedBox(height: 8),
                  EngiMandalaWidget(
                    key: const Key('engiMandala'),
                    isVisible: true,
                  ),
                ],
                const SizedBox(height: 24),
                // SATORIゲージ
                SatoriGaugeWidget(player: _player),
                const SizedBox(height: 24),
                // 開眼段階バッジ
                _buildEnlightenmentBadge(colorScheme),
                const SizedBox(height: 24),
                // 空の世界ラベル（裏面モード時）
                if (_isUraMode && _canUseUraMode)
                  Padding(
                    key: const Key('kuuWorldLabel'),
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: Text(
                        '🌌 空の世界',
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

  Widget _buildEnlightenmentBadge(ColorScheme colorScheme) {
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
                '開眼段階: ${_player.enlightenmentStage.label}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              Text(
                _player.enlightenmentStage.description,
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
          if (_player.guardianDeity == null) ...[
            // 守護神未契約 → 契約を促す
            Text(
              'まだ守護神と契約していない',
              style: TextStyle(color: colorScheme.outline),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openGuardianSelection,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('守護神と契約する'),
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
                    _currentQuest!.guardianDeity.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _currentQuest!.guardianDeity.label,
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
