import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/lifecycle/domain/day_rollover_detector.dart';

/// 日付跨ぎ検出の純粋ロジック試練。
///
/// 判定は端末ローカル暦（年/月/日）で行う。UTC は混ぜない。
void main() {
  group('DayRolloverDetector', () {
    test('同じローカル暦日なら sameDay を返し lastSeen を更新する', () {
      final detector = DayRolloverDetector(
        lastSeen: DateTime(2026, 10, 29, 9, 0),
      );

      final result = detector.check(DateTime(2026, 10, 29, 23, 30));

      expect(result, DayRolloverResult.sameDay);
      expect(detector.lastSeen, DateTime(2026, 10, 29, 23, 30));
    });

    test('翌日へ進んでいれば rolledOver を返し lastSeen を now にする', () {
      final detector = DayRolloverDetector(
        lastSeen: DateTime(2026, 10, 29, 23, 50),
      );

      final result = detector.check(DateTime(2026, 10, 30, 0, 10));

      expect(result, DayRolloverResult.rolledOver);
      expect(detector.lastSeen, DateTime(2026, 10, 30, 0, 10));
    });

    test('暦日が巻き戻ったら clockWentBack を返し lastSeen は据え置く', () {
      final lastSeen = DateTime(2026, 10, 30, 8, 0);
      final detector = DayRolloverDetector(lastSeen: lastSeen);

      final result = detector.check(DateTime(2026, 10, 29, 22, 0));

      expect(result, DayRolloverResult.clockWentBack);
      expect(detector.lastSeen, lastSeen);
    });

    test('翌日跨ぎ後、同じ日のうちは sameDay に戻る', () {
      final detector = DayRolloverDetector(
        lastSeen: DateTime(2026, 10, 29, 23, 59),
      );

      expect(
        detector.check(DateTime(2026, 10, 30, 0, 1)),
        DayRolloverResult.rolledOver,
      );
      expect(
        detector.check(DateTime(2026, 10, 30, 18, 0)),
        DayRolloverResult.sameDay,
      );
      expect(detector.lastSeen, DateTime(2026, 10, 30, 18, 0));
    });

    test('月跨ぎ・年跨ぎでもローカル暦日で判定する', () {
      final detector = DayRolloverDetector(
        lastSeen: DateTime(2026, 12, 31, 23, 30),
      );

      final result = detector.check(DateTime(2027, 1, 1, 0, 5));

      expect(result, DayRolloverResult.rolledOver);
      expect(detector.lastSeen, DateTime(2027, 1, 1, 0, 5));
    });

    test('時刻だけが巻き戻っても同一暦日なら sameDay を返す', () {
      final detector = DayRolloverDetector(
        lastSeen: DateTime(2026, 10, 29, 12, 0),
      );

      final result = detector.check(DateTime(2026, 10, 29, 8, 0));

      expect(result, DayRolloverResult.sameDay);
      expect(detector.lastSeen, DateTime(2026, 10, 29, 8, 0));
    });
  });
}
