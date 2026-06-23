import 'package:kozuchi/features/satori/domain/satori_change_event.dart';

/// SATORI変動イベントの同期ディスパッチャー
///
/// シングルトンパターンで提供され、リスナー登録・解除・イベント発行を行う。
///
/// **同期的**: リスナーは `dispatch()` 呼び出し時に即座に実行される。
/// Stream は使用せず、UI のビルドサイクルとは独立している。
///
/// 使用例:
/// ```dart
/// // リスナー登録
/// SatoriEventDispatcher.instance.addListener((event) {
///   if (event.direction == SatoriDirection.increase) {
///     // 光の粒子アニメーションを開始
///   }
/// });
///
/// // リスナー解除（dispose時など）
/// SatoriEventDispatcher.instance.removeListener(myListener);
/// ```
class SatoriEventDispatcher {
  /// シングルトンインスタンス
  static final SatoriEventDispatcher instance = SatoriEventDispatcher._();

  SatoriEventDispatcher._();

  final List<void Function(SatoriChangeEvent)> _listeners = [];

  /// 直近に発行されたイベント（テスト・デバッグ用）
  SatoriChangeEvent? lastEvent;

  /// リスナーを登録する
  ///
  /// 同一の関数を複数回登録しても、重複して呼び出される。
  void addListener(void Function(SatoriChangeEvent) listener) {
    _listeners.add(listener);
  }

  /// リスナーを解除する
  void removeListener(void Function(SatoriChangeEvent) listener) {
    _listeners.remove(listener);
  }

  /// 全てのリスナーを解除する
  void removeAllListeners() {
    _listeners.clear();
  }

  /// イベントを発行する
  ///
  /// 登録された全リスナーを同期的に呼び出す。
  /// リスナー内で例外が発生しても他のリスナーには影響しない。
  void dispatch(SatoriChangeEvent event) {
    lastEvent = event;
    // リストのコピーを操作して、dispatch中のaddListener/removeListenerを安全に
    final listeners = List<void Function(SatoriChangeEvent)>.from(_listeners);
    for (final listener in listeners) {
      try {
        listener(event);
      } catch (_) {
        // リスナーの例外はログに残さず無視（UIアニメーションの失敗が
        // ゲームロジックに影響しないようにする）
      }
    }
  }

  /// 登録リスナー数を返す（テスト用）
  int get listenerCount => _listeners.length;
}
