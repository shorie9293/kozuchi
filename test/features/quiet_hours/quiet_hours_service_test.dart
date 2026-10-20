import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_policy.dart';
import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_service.dart';
import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_settings.dart';

/// 静穏時間の純粋ロジック（境界・繰り延べ・抑止判定）の試練。
void main() {
  // 22:00-07:00（日跨ぎ）
  const start = 22 * 60;
  const end = 7 * 60;

  DateTime at(int hour, int minute, {int day = 21}) =>
      DateTime(2026, 10, day, hour, minute);

  group('isWithinQuietHours（22:00-07:00）', () {
    test('21:59 は静穏外', () {
      expect(
        QuietHoursService.isWithinQuietHours(at(21, 59), start, end),
        isFalse,
      );
    });

    test('22:00 は静穏内（開始は含む）', () {
      expect(
          QuietHoursService.isWithinQuietHours(at(22, 0), start, end), isTrue);
    });

    test('03:00 は静穏内', () {
      expect(
          QuietHoursService.isWithinQuietHours(at(3, 0), start, end), isTrue);
    });

    test('06:59 は静穏内', () {
      expect(
        QuietHoursService.isWithinQuietHours(at(6, 59), start, end),
        isTrue,
      );
    });

    test('07:00 は静穏外（終了は含まない）', () {
      expect(
          QuietHoursService.isWithinQuietHours(at(7, 0), start, end), isFalse);
    });

    test('日跨ぎでない範囲（01:00-05:00）も判定できる', () {
      expect(QuietHoursService.isWithinQuietHours(at(0, 59), 60, 300), isFalse);
      expect(QuietHoursService.isWithinQuietHours(at(1, 0), 60, 300), isTrue);
      expect(QuietHoursService.isWithinQuietHours(at(4, 59), 60, 300), isTrue);
      expect(QuietHoursService.isWithinQuietHours(at(5, 0), 60, 300), isFalse);
    });

    test('start == end は常に false', () {
      for (var h = 0; h < 24; h++) {
        final m = h * 60;
        expect(
          QuietHoursService.isWithinQuietHours(at(h, 0), m, m),
          isFalse,
          reason: '$h時 で start==end は静穏なし',
        );
      }
    });
  });

  group('deferUntil', () {
    test('静穏外なら now をそのまま返す', () {
      final now = at(12, 34);
      expect(QuietHoursService.deferUntil(now, start, end), now);
    });

    test('静穏内（深夜）なら当日の終了時刻を返す', () {
      final now = at(3, 0);
      final until = QuietHoursService.deferUntil(now, start, end);
      expect(until, DateTime(2026, 10, 21, 7, 0));
    });

    test('静穏内（開始直後）なら翌日の終了時刻を返す', () {
      final now = at(23, 15);
      final until = QuietHoursService.deferUntil(now, start, end);
      expect(until, DateTime(2026, 10, 22, 7, 0));
    });

    test('返り値の秒以下は 0', () {
      final now = DateTime(2026, 10, 21, 3, 0, 45, 123, 456);
      final until = QuietHoursService.deferUntil(now, start, end);
      expect(until, DateTime(2026, 10, 21, 7, 0));
      expect(until.second, 0);
      expect(until.millisecond, 0);
      expect(until.microsecond, 0);
    });
  });

  group('formatMinutes', () {
    test('ゼロ埋め HH:mm を返す', () {
      expect(QuietHoursService.formatMinutes(0), '00:00');
      expect(QuietHoursService.formatMinutes(7 * 60), '07:00');
      expect(QuietHoursService.formatMinutes(22 * 60 + 5), '22:05');
      expect(QuietHoursService.formatMinutes(23 * 60 + 59), '23:59');
    });
  });

  group('resolveDelivery', () {
    QuietHoursSettings settings({
      bool enabled = true,
      QuietHoursPolicy policy = QuietHoursPolicy.defer,
    }) =>
        QuietHoursSettings(
          enabled: enabled,
          startHour: 22,
          startMinute: 0,
          endHour: 7,
          endMinute: 0,
          policy: policy,
        );

    test('無効時は素通し', () {
      final scheduled = at(23, 0);
      expect(
        QuietHoursService.resolveDelivery(settings(enabled: false), scheduled),
        scheduled,
      );
    });

    test('静穏外は素通し', () {
      final scheduled = at(12, 0);
      expect(
        QuietHoursService.resolveDelivery(settings(), scheduled),
        scheduled,
      );
    });

    test('静穏内 + defer は翌朝へ繰り延べ', () {
      expect(
        QuietHoursService.resolveDelivery(settings(), at(23, 0)),
        DateTime(2026, 10, 22, 7, 0),
      );
      expect(
        QuietHoursService.resolveDelivery(settings(), at(3, 0)),
        DateTime(2026, 10, 21, 7, 0),
      );
    });

    test('静穏内 + skip は null（通知しない）', () {
      expect(
        QuietHoursService.resolveDelivery(
          settings(policy: QuietHoursPolicy.skip),
          at(23, 0),
        ),
        isNull,
      );
    });
  });
}
