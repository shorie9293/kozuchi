import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/lifecycle/domain/day_rollover_detector.dart';
import 'package:kozuchi/features/lifecycle/presentation/app_lifecycle_refresher.dart';

/// `AppLifecycleRefresher` の試練。
///
/// `tester.binding.handleAppLifecycleStateChanged` は同一状態の連続通知を
/// 無視し得るため、必要に応じて inactive → paused → resumed の遷移を挟む。
void main() {
  /// 指定時刻を返す時計を組み立てる。
  DateTime Function() clockAt(DateTime fixed) => () => fixed;

  /// テキストを描画できる最小限の方向性を供給する。
  Widget wrap(Widget child) =>
      Directionality(textDirection: TextDirection.ltr, child: child);

  Future<void> resumeFromBackground(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }

  testWidgets('日付を跨いだ resumed で onRollover が1回だけ呼ばれる', (tester) async {
    var calls = 0;
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 23, 0));

    await tester.pumpWidget(
      wrap(
        AppLifecycleRefresher(
          detector: detector,
          onRollover: () async => calls++,
          now: clockAt(DateTime(2026, 10, 30, 8, 0)),
          child: const SizedBox.shrink(),
        ),
      ),
    );

    await resumeFromBackground(tester);

    expect(calls, 1);
  });

  testWidgets('paused / inactive では onRollover を呼ばない', (tester) async {
    var calls = 0;
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 23, 0));

    await tester.pumpWidget(
      wrap(
        AppLifecycleRefresher(
          detector: detector,
          onRollover: () async => calls++,
          now: clockAt(DateTime(2026, 10, 30, 8, 0)),
          child: const SizedBox.shrink(),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(calls, 0);
  });

  testWidgets('同一暦日の resumed では onRollover を呼ばない', (tester) async {
    var calls = 0;
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 1, 0));

    await tester.pumpWidget(
      wrap(
        AppLifecycleRefresher(
          detector: detector,
          onRollover: () async => calls++,
          now: clockAt(DateTime(2026, 10, 29, 20, 0)),
          child: const SizedBox.shrink(),
        ),
      ),
    );

    await resumeFromBackground(tester);

    expect(calls, 0);
  });

  testWidgets('onRollover が throw しても widget は生存し再入しない', (tester) async {
    var calls = 0;
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 23, 0));

    await tester.pumpWidget(
      wrap(
        AppLifecycleRefresher(
          detector: detector,
          onRollover: () async {
            calls++;
            throw StateError('boom');
          },
          now: clockAt(DateTime(2026, 10, 30, 8, 0)),
          child: const Text('生きている'),
        ),
      ),
    );

    await resumeFromBackground(tester);
    await tester.pump();

    expect(calls, 1);
    expect(find.text('生きている'), findsOneWidget);

    // 同一日のまま再度 resumed しても再実行しない
    await resumeFromBackground(tester);
    expect(calls, 1);
  });

  testWidgets('child をそのまま描画する', (tester) async {
    final detector = DayRolloverDetector(lastSeen: DateTime(2026, 10, 29));

    await tester.pumpWidget(
      wrap(
        AppLifecycleRefresher(
          detector: detector,
          onRollover: () async {},
          now: clockAt(DateTime(2026, 10, 29, 12, 0)),
          child: const Text('本文'),
        ),
      ),
    );

    expect(find.text('本文'), findsOneWidget);
  });
}
