import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_policy.dart';
import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_settings.dart';

/// 静穏時間設定の値オブジェクト試練。
void main() {
  group('QuietHoursPolicy', () {
    test('storageKey と label を持つ', () {
      expect(QuietHoursPolicy.defer.storageKey, 'defer');
      expect(QuietHoursPolicy.skip.storageKey, 'skip');
      expect(QuietHoursPolicy.defer.label, '翌朝に繰り延べ');
      expect(QuietHoursPolicy.skip.label, '通知しない');
    });

    test('fromStorageKey は既知のみ復元し、不明は defer', () {
      expect(QuietHoursPolicy.fromStorageKey('defer'), QuietHoursPolicy.defer);
      expect(QuietHoursPolicy.fromStorageKey('skip'), QuietHoursPolicy.skip);
      expect(
          QuietHoursPolicy.fromStorageKey('unknown'), QuietHoursPolicy.defer);
      expect(QuietHoursPolicy.fromStorageKey(''), QuietHoursPolicy.defer);
    });
  });

  group('QuietHoursSettings', () {
    test('defaults は 無効・22:00-07:00・defer', () {
      final s = QuietHoursSettings.defaults();
      expect(s.enabled, isFalse);
      expect(s.startHour, 22);
      expect(s.startMinute, 0);
      expect(s.endHour, 7);
      expect(s.endMinute, 0);
      expect(s.policy, QuietHoursPolicy.defer);
    });

    test('startMinutes / endMinutes / ラベル', () {
      final s = QuietHoursSettings.defaults();
      expect(s.startMinutes, 22 * 60);
      expect(s.endMinutes, 7 * 60);
      expect(s.startLabel, '22:00');
      expect(s.endLabel, '07:00');
    });

    test('範囲外の時は ArgumentError', () {
      expect(
        () => QuietHoursSettings(
          enabled: true,
          startHour: 24,
          startMinute: 0,
          endHour: 7,
          endMinute: 0,
          policy: QuietHoursPolicy.defer,
        ),
        throwsArgumentError,
      );
      expect(
        () => QuietHoursSettings(
          enabled: true,
          startHour: -1,
          startMinute: 0,
          endHour: 7,
          endMinute: 0,
          policy: QuietHoursPolicy.defer,
        ),
        throwsArgumentError,
      );
      expect(
        () => QuietHoursSettings(
          enabled: true,
          startHour: 22,
          startMinute: 60,
          endHour: 7,
          endMinute: 0,
          policy: QuietHoursPolicy.defer,
        ),
        throwsArgumentError,
      );
      expect(
        () => QuietHoursSettings(
          enabled: true,
          startHour: 22,
          startMinute: 0,
          endHour: 7,
          endMinute: 60,
          policy: QuietHoursPolicy.defer,
        ),
        throwsArgumentError,
      );
    });

    test('copyWith は指定値のみ差し替える', () {
      final s = QuietHoursSettings.defaults();
      final next = s.copyWith(enabled: true, endHour: 6, endMinute: 30);
      expect(next.enabled, isTrue);
      expect(next.endLabel, '06:30');
      expect(next.startLabel, '22:00');
      expect(next.policy, QuietHoursPolicy.defer);
    });

    test('toJson / fromJson が往復する', () {
      final s = QuietHoursSettings(
        enabled: true,
        startHour: 21,
        startMinute: 45,
        endHour: 8,
        endMinute: 15,
        policy: QuietHoursPolicy.skip,
      );
      expect(QuietHoursSettings.fromJson(s.toJson()), s);
    });

    test('fromJson は破損データで defaults を返す', () {
      final d = QuietHoursSettings.defaults();
      expect(QuietHoursSettings.fromJson(<String, dynamic>{}), d);
      expect(
        QuietHoursSettings.fromJson(<String, dynamic>{'startHour': 99}),
        d,
      );
      expect(
        QuietHoursSettings.fromJson(<String, dynamic>{
          'startHour': '22',
          'endHour': null,
        }),
        d,
      );
      expect(
        QuietHoursSettings.fromJson(<String, dynamic>{
          'startHour': 22,
          'startMinute': 0,
          'endHour': 7,
          'endMinute': -5,
        }),
        d,
      );
    });

    test('fromJson の未知 policy は defer にフォールバック', () {
      final s = QuietHoursSettings.fromJson(<String, dynamic>{
        'enabled': true,
        'startHour': 22,
        'startMinute': 0,
        'endHour': 7,
        'endMinute': 0,
        'policy': 'nonsense',
      });
      expect(s.policy, QuietHoursPolicy.defer);
      expect(s.enabled, isTrue);
    });

    test('値等価・hashCode が一致する', () {
      final a = QuietHoursSettings.defaults();
      final b = QuietHoursSettings.defaults();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(a.copyWith(enabled: true)));
      expect(a, isNot(a.copyWith(policy: QuietHoursPolicy.skip)));
    });
  });
}
