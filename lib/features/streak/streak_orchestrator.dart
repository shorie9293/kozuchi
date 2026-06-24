import 'package:kozuchi/domain/models/return_mission.dart';
import 'package:kozuchi/domain/streak/streak.dart';
import 'package:kozuchi/domain/services/streak_service.dart';
import 'package:kozuchi/features/streak/data/streak_persistence_impl.dart';

/// ストリークシステムの統合オーケストレーター
///
/// MainScreen 等が利用する単一の窓口。
/// 日次ログイン記録、ストリーク追跡、飢餓地帯管理、復帰ミッションを統合する。
class StreakOrchestrator {
  final StreakRepository _repository;
  late final HungryZone _hungryZone;

  /// 現在の復帰ミッション（未発行の場合は none）
  ReturnMission _returnMission = ReturnMission.none();

  StreakOrchestrator({
    StreakPersistence? persistence,
    HungryZone? hungryZone,
  })  : _repository = StreakRepository(
          persistence: persistence ?? const StreakPersistenceImpl(),
        ),
        _hungryZone = hungryZone ??
            HungryZone(
              entryProbability: 0.3,
              statMultiplier: 0.7,
              cooldownDuration: const Duration(hours: 24),
            );

  /// 保存済みの状態を復元し、初期化する。
  /// アプリ起動時に必ず呼ぶこと。
  Future<void> initialize() async {
    final tracker = await _repository.loadOrCreate();
    _hungryZone.attachTo(tracker);
  }

  /// 現在のストリーク状態
  StreakState get streakState => _repository.tracker.currentState;

  /// 現在のストリーク日数
  int get streakDays => streakState.streakDays;

  /// 飢餓地帯の状態
  HungryZoneState get hungryZoneState => _hungryZone.currentState;

  /// 飢餓地帯が発動中か
  bool get isHungryZoneActive => _hungryZone.isActive;

  /// 現在の復帰ミッション
  ReturnMission get returnMission => _returnMission;

  /// 復帰ミッションが発行中か
  bool get hasReturnMission =>
      _returnMission.id.isNotEmpty && !_returnMission.isCompleted;

  /// 日次ログイン/活動を記録する。
  ///
  /// [now] は活動日時。ストリークの増加・継続・途絶を判定し、
  /// 必要に応じて飢餓地帯を発動・復帰ミッションを発行する。
  Future<void> recordDailyActivity(DateTime now) async {
    final oldStreakDays = streakState.streakDays;
    await _repository.recordActivity(now);

    // 途絶検知：ストリークがリセットされ、かつ前回1日以上だった場合
    if (oldStreakDays > 0 && streakState.streakDays <= 1) {
      // 飢餓地帯の確率判定は HungryZone.attachTo のコールバックで行われる
      // ここでは復帰ミッションの発行判定のみ行う
      if (_hungryZone.isActive) {
        _returnMission = ReturnMission.generate(
          _hungryZone.currentState.brokenStreakDays,
        );
      }
    }

    // 飢餓地帯のクールダウンチェック
    _hungryZone.tick(now);
  }

  /// 復帰ミッションの進捗を更新する。
  ///
  /// [amount] は追加の進捗値（支出額など）。
  /// 目標値に達すると自動的に完了し、飢餓地帯から脱出する。
  void updateReturnMission(int amount) {
    if (!hasReturnMission) return;
    _returnMission = _returnMission.updateProgress(
      _returnMission.currentProgress + amount,
    );
    if (_returnMission.isCompleted) {
      _hungryZone.completeReturnMission();
    }
  }

  /// 現在の EXP 倍率を計算する。
  double get expMultiplier =>
      StreakService.calcTotalExpMultiplier(streakDays, _hungryZone);

  /// ストリークボーナス込みの EXP を計算する。
  int calcBoostedExp(int baseExp) {
    // 飢餓地帯ペナルティも適用
    final totalMult = expMultiplier;
    return (baseExp * totalMult).round();
  }

  /// 全状態をリセットする（デバッグ用）
  Future<void> resetAll() async {
    await _repository.tracker.recordActivity(DateTime(2000));
    // リポジトリ経由で空状態を保存
  }
}
