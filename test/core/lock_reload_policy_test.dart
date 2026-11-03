import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/lock_reload_policy.dart';

void main() {
  group('LockReloadPolicy.graceOptionsSeconds', () {
    test('選択肢は 0/30/60/300', () {
      expect(LockReloadPolicy.graceOptionsSeconds, [0, 30, 60, 300]);
    });
  });

  group('LockReloadPolicy.graceLabel', () {
    test('既定の選択肢は日本語ラベル', () {
      expect(LockReloadPolicy.graceLabel(0), '即時');
      expect(LockReloadPolicy.graceLabel(30), '30秒');
      expect(LockReloadPolicy.graceLabel(60), '1分');
      expect(LockReloadPolicy.graceLabel(300), '5分');
    });

    test('未知の秒数は秒表記', () {
      expect(LockReloadPolicy.graceLabel(45), '45秒');
      expect(LockReloadPolicy.graceLabel(7), '7秒');
    });
  });

  group('LockReloadPolicy.shouldRelock', () {
    final now = DateTime(2026, 1, 1, 12, 0, 0);

    test('バックグラウンド開始時刻が無ければ施錠', () {
      expect(
        LockReloadPolicy.shouldRelock(null, now, const Duration(minutes: 5)),
        isTrue,
      );
    });

    test('猶予 0 以下は即時施錠', () {
      expect(
        LockReloadPolicy.shouldRelock(
          now,
          now,
          Duration.zero,
        ),
        isTrue,
      );
      expect(
        LockReloadPolicy.shouldRelock(
          now,
          now,
          const Duration(seconds: -1),
        ),
        isTrue,
      );
    });

    test('猶予内は施錠しない', () {
      final backgroundedAt = now.subtract(const Duration(seconds: 10));
      expect(
        LockReloadPolicy.shouldRelock(
          backgroundedAt,
          now,
          const Duration(seconds: 30),
        ),
        isFalse,
      );
    });

    test('猶予ちょうど・超過は施錠', () {
      final exactly = now.subtract(const Duration(seconds: 30));
      expect(
        LockReloadPolicy.shouldRelock(
          exactly,
          now,
          const Duration(seconds: 30),
        ),
        isTrue,
      );
      final over = now.subtract(const Duration(seconds: 31));
      expect(
        LockReloadPolicy.shouldRelock(
          over,
          now,
          const Duration(seconds: 30),
        ),
        isTrue,
      );
    });

    test('時計巻き戻りは施錠', () {
      final future = now.add(const Duration(minutes: 1));
      expect(
        LockReloadPolicy.shouldRelock(
          future,
          now,
          const Duration(minutes: 5),
        ),
        isTrue,
      );
    });
  });
}
