import 'dart:math';

import 'package:kozuchi/domain/streak/hungry_zone_state.dart';
import 'package:kozuchi/domain/streak/streak_event.dart';
import 'package:kozuchi/domain/streak/streak_tracker.dart';

/// 飢餓地帯（Hungry Zone）のペナルティ管理サービス。
///
/// [StreakTracker] のストリーク途絶イベントに反応し、
/// 確率判定に基づいて飢餓地帯を発動する。
///
/// 脱出条件:
/// - クールダウン経過（[tick] で判定）
/// - 帰還任務の完了（[completeReturnMission] で即時脱出）
///
/// [randomCheck] はテスト用に注入可能な乱数関数。
/// true を返すと強制発動、false で強制抑制。
/// 省略時は [entryProbability] に基づく実乱数を使用。
class HungryZone {
  /// ストリーク途絶時に飢餓地帯に入る確率（0.0〜1.0）
  final double entryProbability;

  /// 発動時のステータス乗数（1.0未満＝ペナルティ）
  final double _statMultiplier;

  /// クールダウン期間
  final Duration _cooldownDuration;

  /// テスト用乱数関数
  final bool Function()? _randomCheck;

  /// 乱数生成器
  final Random _random = Random();

  HungryZoneState _state = HungryZoneState.inactive();

  /// 最後に観測したストリーク日数（broken イベント時に途絶前日数として使用）
  int _lastSeenStreakDays = 0;

  /// 飢餓地帯サービスを生成する。
  ///
  /// [entryProbability] は途絶時に飢餓地帯へ入る確率（例: 0.3）。
  /// [statMultiplier] は発動時のステータス乗数（例: 0.7）。
  /// [cooldownDuration] はペナルティの持続時間。
  /// [randomCheck] はテスト用。true で強制発動、false で強制抑制。
  HungryZone({
    required this.entryProbability,
    required double statMultiplier,
    required Duration cooldownDuration,
    bool Function()? randomCheck,
  })  : _statMultiplier = statMultiplier,
        _cooldownDuration = cooldownDuration,
        _randomCheck = randomCheck;

  /// 現在発動中か
  bool get isActive => _state.isActive;

  /// 現在のステータス乗数（未発動時は 1.0）
  double get currentStatMultiplier =>
      _state.isActive ? _state.statMultiplier : 1.0;

  /// 現在の飢餓地帯状態を返す
  HungryZoneState get currentState => _state;

  /// 指定された [tracker] に接続し、ストリークイベントを監視する。
  ///
  /// 接続時に現在のストリーク日数を取得し、全イベントで追跡する。
  /// ストリーク途絶（[StreakEvent.broken]）発生時には、
  /// 途絶前のストリーク日数を用いて確率判定を行い、
  /// 通過した場合に飢餓地帯を発動する。
  void attachTo(StreakTracker tracker) {
    // 接続時に現在のストリーク日数を取得（初回brokenイベントに備える）
    _lastSeenStreakDays = tracker.currentState.streakDays;

    tracker.onStreakEvent = (event, streakState) {
      if (event == StreakEvent.broken) {
        // broken イベントのコールバックはリセット後（streakDays=1）の状態で
        // 呼ばれるため、_lastSeenStreakDays には途絶前の日数が保持されている
        _onStreakBroken(activatedAt: streakState.lastActivityDate!);
        // broken 後は streakDays=1 にリセットされるので追従
        _lastSeenStreakDays = 1;
      } else {
        // started / continued では最新の streakDays を追跡
        _lastSeenStreakDays = streakState.streakDays;
      }
    };
  }

  /// ストリーク途絶時の内部処理: 確率判定 → 発動
  void _onStreakBroken({required DateTime activatedAt}) {
    // 確率判定
    final passes = _randomCheck?.call() ?? (_random.nextDouble() < entryProbability);
    if (!passes) return;

    _state = HungryZoneState(
      isActive: true,
      statMultiplier: _statMultiplier,
      cooldownDuration: _cooldownDuration,
      activatedAt: activatedAt,
      brokenStreakDays: _lastSeenStreakDays,
      returnMissionCompleted: false,
    );
  }

  /// 時間経過を通知し、クールダウン満了判定を行う。
  ///
  /// [now] を現在日時として、クールダウンが経過していれば
  /// 飢餓地帯を脱出する。
  void tick(DateTime now) {
    if (!_state.isActive) return;
    if (_state.isCooldownExpired(now)) {
      _state = _state.copyWith(isActive: false);
    }
  }

  /// 帰還任務を完了し、飢餓地帯を即時脱出する。
  ///
  /// 未発動時は何もしない。
  /// 脱出後は isActive=false かつ returnMissionCompleted=true となる。
  void completeReturnMission() {
    if (!_state.isActive) return;
    _state = _state.copyWith(
      isActive: false,
      returnMissionCompleted: true,
    );
  }
}
