import 'package:flutter/foundation.dart';

import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/weekly_quest/data/shared_preferences_weekly_quest_store.dart';
import 'package:kozuchi/features/weekly_quest/data/weekly_quest_generator.dart';
import 'package:kozuchi/features/weekly_quest/data/weekly_quest_store.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/active_weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest_state.dart';
import 'package:kozuchi/features/weekly_quest/domain/weekly_quest_period.dart';
import 'package:kozuchi/features/weekly_quest/domain/weekly_quest_progress.dart';

/// 週次クエストの状態管理。
///
/// - 週が変わったときだけ生成器を呼ぶ（同一週は保存済みを再利用）
/// - 例外は握って [errorMessage] に載せ、アプリを落とさない
/// - `DateTime.now()` はフィールド初期化の [clock] 経由でのみ触る
class WeeklyQuestNotifier extends ChangeNotifier {
  WeeklyQuestNotifier({
    required WeeklyQuestGenerator generator,
    WeeklyQuestStore store = const SharedPreferencesWeeklyQuestStore(),
    WeeklyQuestProgressService service = const WeeklyQuestProgressService(),
    DateTime Function() clock = DateTime.now,
    Future<List<WeeklyQuest>> Function(DateTime weekStart)? generateOverride,
  })  : _generator = generator,
        _store = store,
        _service = service,
        _clock = clock,
        _generateOverride = generateOverride;

  final WeeklyQuestGenerator _generator;
  final WeeklyQuestStore _store;
  final WeeklyQuestProgressService _service;
  final DateTime Function() _clock;

  /// 生成器を差し替えるためのフック（試練用）。null なら [_generator] を使う。
  final Future<List<WeeklyQuest>> Function(DateTime weekStart)?
      _generateOverride;

  bool _isLoading = false;
  String? _errorMessage;
  WeeklyQuestState? _state;

  /// 直近の集計に使った支出エントリ（activeProgress 算出用）。
  List<ExpenseEntry> _entries = const [];

  /// 読み込み中か。
  bool get isLoading => _isLoading;

  /// 直近の失敗理由（成功時は null）。
  String? get errorMessage => _errorMessage;

  /// 現在の週次クエスト状態。
  WeeklyQuestState? get state => _state;

  /// 未選択の候補。
  List<WeeklyQuest> get pendingQuests => _state?.pending ?? const [];

  /// 選択中のクエスト。
  ActiveWeeklyQuest? get activeQuest => _state?.active;

  /// 選択中クエストの進捗（未選択なら null）。保存はしない。
  WeeklyQuestProgress? get activeProgress {
    final active = _state?.active;
    if (active == null) return null;
    final now = _clock();
    final period = WeeklyQuestPeriod.of(now);
    if (active.quest.weekStart != period.weekStart) {
      // 週が変わった古いクエストは、その週の期間で評価する。
      final questPeriod = WeeklyQuestPeriod(weekStart: active.quest.weekStart);
      return _service.evaluate(
        quest: active.quest,
        entries: _entries,
        period: questPeriod,
        now: now,
        baseStatus: WeeklyQuestStatus.active,
      );
    }
    return _service.evaluate(
      quest: active.quest,
      entries: _entries,
      period: period,
      now: now,
      baseStatus: WeeklyQuestStatus.active,
    );
  }

  /// 対象週の状態を用意する。
  ///
  /// 保存済み state の weekKey が現在週と一致すれば生成しない。
  /// 一致しない／未保存なら生成して保存する。生成が空でも例外にしない。
  Future<void> ensureForWeek({
    required List<ExpenseEntry> entries,
    DateTime? now,
  }) async {
    final at = now ?? _clock();
    _entries = entries;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final period = WeeklyQuestPeriod.of(at);
      final stored = await _store.load();
      if (stored != null && stored.weekKey == period.weekKey) {
        _state = stored;
        return;
      }

      final quests = await _generate(period.weekStart);
      final next = WeeklyQuestState(
        weekKey: period.weekKey,
        pending: quests,
        active: null,
        generatedAt: at,
      );
      _state = next;
      await _store.save(next);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 候補からクエストを選び、active に昇格させる。
  ///
  /// 未知の [questId] は何もせず戻る（例外禁止）。
  Future<void> selectQuest(String questId, {DateTime? now}) async {
    final current = _state;
    if (current == null) return;

    WeeklyQuest? selected;
    for (final quest in current.pending) {
      if (quest.id == questId) {
        selected = quest;
        break;
      }
    }
    if (selected == null) return;

    final at = now ?? _clock();
    final rest = current.pending.where((q) => q.id != questId).toList();
    final next = current.copyWith(
      pending: rest,
      active: ActiveWeeklyQuest(
        quest: selected,
        status: WeeklyQuestStatus.active,
        selectedAt: at,
      ),
    );
    _state = next;
    try {
      await _store.save(next);
    } catch (error) {
      _errorMessage = error.toString();
    }
    notifyListeners();
  }

  /// 現在週の状態を作り直す（保存済みを無視して再生成）。
  Future<void> reload({
    required List<ExpenseEntry> entries,
    DateTime? now,
  }) async {
    final at = now ?? _clock();
    _entries = entries;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final period = WeeklyQuestPeriod.of(at);
      final quests = await _generate(period.weekStart);
      final next = WeeklyQuestState(
        weekKey: period.weekKey,
        pending: quests,
        active: null,
        generatedAt: at,
      );
      _state = next;
      await _store.save(next);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<WeeklyQuest>> _generate(DateTime weekStart) {
    final override = _generateOverride;
    if (override != null) return override(weekStart);
    return _generator.generate(weekStart);
  }
}
