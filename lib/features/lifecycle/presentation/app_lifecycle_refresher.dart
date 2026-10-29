import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:kozuchi/features/lifecycle/domain/day_rollover_detector.dart';

/// アプリが前面復帰した時にローカル暦日の跨ぎを検出し、
/// [onRollover] で日付依存データの再読込を促す薄いラッパー。
///
/// - `resumed` の時だけ判定する（paused / inactive / hidden / detached では何もしない）。
/// - [DayRolloverResult.rolledOver] の時だけ [onRollover] を投げっぱなしで1回呼ぶ。
/// - [onRollover] の例外は握りつぶし、アプリを落とさない。
class AppLifecycleRefresher extends StatefulWidget {
  const AppLifecycleRefresher({
    super.key,
    required this.detector,
    required this.onRollover,
    required this.child,
    this.now,
  });

  /// 暦日跨ぎの判定器（呼び出し側が保持する）。
  final DayRolloverDetector detector;

  /// 日付依存データの再読込。失敗してもアプリは継続する。
  final Future<void> Function() onRollover;

  /// ラップ対象のウィジェットツリー。
  final Widget child;

  /// 現在時刻の供給元（既定は [DateTime.now]）。
  final DateTime Function()? now;

  @override
  State<AppLifecycleRefresher> createState() => _AppLifecycleRefresherState();
}

class _AppLifecycleRefresherState extends State<AppLifecycleRefresher>
    with WidgetsBindingObserver {
  /// onRollover 実行中の再入防止。
  bool _isRefreshing = false;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    _handleResumed();
  }

  void _handleResumed() {
    if (_isRefreshing) return;

    final result = widget.detector.check(_now());
    if (result != DayRolloverResult.rolledOver) return;

    _isRefreshing = true;
    // 投げっぱなし（await しない）。失敗しても画面は生かす。
    unawaited(_runRollover());
  }

  Future<void> _runRollover() async {
    try {
      await widget.onRollover();
    } catch (error, stackTrace) {
      debugPrint('[kozuchi] ⚠️ 日付跨ぎ再計算に失敗: $error\n$stackTrace');
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
