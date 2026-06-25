import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/features/satori/domain/satori_change_event.dart';
import 'package:kozuchi/features/satori/domain/satori_reason.dart';
import 'package:kozuchi/features/satori/data/satori_event_dispatcher.dart';

/// SATORI値の変動を検出し、イベントを生成・発行する
///
/// 新旧の [PlayerModel] と文脈情報 [SatoriContext] を受け取り、
/// 変動があれば [SatoriChangeEvent] を生成して [SatoriEventDispatcher] に発行する。
///
/// 使用例:
/// ```dart
/// final detector = const SatoriChangeDetector();
/// final event = detector.detectAndDispatch(
///   oldPlayer: currentPlayer,
///   newPlayer: updatedPlayer,
///   context: SatoriContext.reflectionReview(
///     advisorLabel: '大黒天',
///     expMultiplier: 1.5,
///     offeringAmount: 3000,
///     previousStage: currentPlayer.levelStage,
///     newStage: updatedPlayer.levelStage,
///   ),
/// );
/// ```
class SatoriChangeDetector {
  const SatoriChangeDetector();

  /// 新旧プレイヤーを比較し、SATORI変動があればイベントを生成して発行する
  ///
  /// [oldPlayer] 変動前のプレイヤー状態
  /// [newPlayer] 変動後のプレイヤー状態
  /// [context] 変動の文脈情報
  ///
  /// 変動がなければ null を返し、イベントは発行されない。
  SatoriChangeEvent? detectAndDispatch({
    required PlayerModel oldPlayer,
    required PlayerModel newPlayer,
    required SatoriContext context,
  }) {
    final event = detect(
      oldPlayer: oldPlayer,
      newPlayer: newPlayer,
      context: context,
    );
    if (event != null) {
      SatoriEventDispatcher.instance.dispatch(event);
    }
    return event;
  }

  /// 新旧プレイヤーを比較し、SATORI変動があればイベントを返す
  ///
  /// 発行は行わない。テスト用または発行のタイミングを制御したい場合に使用する。
  SatoriChangeEvent? detect({
    required PlayerModel oldPlayer,
    required PlayerModel newPlayer,
    required SatoriContext context,
  }) {
    final delta = newPlayer.exp - oldPlayer.exp;
    if (delta == 0) return null;

    final direction = delta > 0 ? SatoriDirection.increase : SatoriDirection.decrease;
    final reason = direction == SatoriDirection.increase
        ? SatoriReason.forIncrease(context)
        : SatoriReason.forDecrease(context);

    return SatoriChangeEvent(
      direction: direction,
      reason: reason,
      oldValue: oldPlayer.exp,
      newValue: newPlayer.exp,
      delta: delta.abs(),
      context: context.advisorLabel,
    );
  }
}
