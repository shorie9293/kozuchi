import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/notification_settings/domain/notification_settings.dart';

void main() {
  group('NotificationKind', () {
    test('全種が storageKey/label/description を持つ', () {
      expect(NotificationKind.values.length, 3);
      expect(NotificationKind.dailyReminder.storageKey, 'daily_reminder');
      expect(NotificationKind.dailyReminder.label, '記帳リマインド');
      expect(NotificationKind.budgetAlert.label, '予算超過アラート');
      expect(NotificationKind.recurringTransaction.description, isNotEmpty);
    });

    test('fromStorageKey は既知キーを復元する', () {
      expect(
        NotificationKind.fromStorageKey('daily_reminder'),
        NotificationKind.dailyReminder,
      );
      expect(
        NotificationKind.fromStorageKey('budget_alert'),
        NotificationKind.budgetAlert,
      );
      expect(
        NotificationKind.fromStorageKey('recurring_transaction'),
        NotificationKind.recurringTransaction,
      );
    });

    test('fromStorageKey は未知キーで null を返す', () {
      expect(NotificationKind.fromStorageKey('unknown_key'), isNull);
      expect(NotificationKind.fromStorageKey(''), isNull);
    });
  });

  group('NotificationSettings.defaults', () {
    test('既定値は enabled=true, 21:00, 全種有効', () {
      final s = NotificationSettings.defaults();
      expect(s.enabled, isTrue);
      expect(s.hour, 21);
      expect(s.minute, 0);
      expect(s.enabledKinds, NotificationKind.values.toSet());
      expect(s.timeLabel, '21:00');
    });
  });

  group('NotificationSettings 範囲検証', () {
    test('hour が範囲外なら ArgumentError', () {
      expect(
        () => NotificationSettings(
          enabled: true,
          hour: -1,
          minute: 0,
          enabledKinds: {},
        ),
        throwsArgumentError,
      );
      expect(
        () => NotificationSettings(
          enabled: true,
          hour: 24,
          minute: 0,
          enabledKinds: {},
        ),
        throwsArgumentError,
      );
    });

    test('minute が範囲外なら ArgumentError', () {
      expect(
        () => NotificationSettings(
          enabled: true,
          hour: 0,
          minute: -1,
          enabledKinds: {},
        ),
        throwsArgumentError,
      );
      expect(
        () => NotificationSettings(
          enabled: true,
          hour: 0,
          minute: 60,
          enabledKinds: {},
        ),
        throwsArgumentError,
      );
    });

    test('境界値（0:0 と 23:59）は有効', () {
      expect(
        () => NotificationSettings(
          enabled: false,
          hour: 0,
          minute: 0,
          enabledKinds: {},
        ),
        returnsNormally,
      );
      expect(
        () => NotificationSettings(
          enabled: false,
          hour: 23,
          minute: 59,
          enabledKinds: {},
        ),
        returnsNormally,
      );
    });
  });

  group('NotificationSettings.timeLabel', () {
    test('ゼロ埋めされる', () {
      expect(
        NotificationSettings(
          enabled: true,
          hour: 9,
          minute: 5,
          enabledKinds: {},
        ).timeLabel,
        '09:05',
      );
      expect(
        NotificationSettings(
          enabled: true,
          hour: 23,
          minute: 59,
          enabledKinds: {},
        ).timeLabel,
        '23:59',
      );
    });
  });

  group('NotificationSettings.isKindEnabled / toggleKind', () {
    test('isKindEnabled は含む場合 true', () {
      final s = NotificationSettings.defaults();
      expect(s.isKindEnabled(NotificationKind.dailyReminder), isTrue);
    });

    test('isKindEnabled は含まない場合 false', () {
      final s = NotificationSettings(
        enabled: true,
        hour: 21,
        minute: 0,
        enabledKinds: {NotificationKind.dailyReminder},
      );
      expect(s.isKindEnabled(NotificationKind.budgetAlert), isFalse);
    });

    test('toggleKind は無い種類を追加する', () {
      final s = NotificationSettings(
        enabled: true,
        hour: 21,
        minute: 0,
        enabledKinds: {NotificationKind.dailyReminder},
      );
      final toggled = s.toggleKind(NotificationKind.budgetAlert);
      expect(toggled.isKindEnabled(NotificationKind.budgetAlert), isTrue);
      expect(toggled.isKindEnabled(NotificationKind.dailyReminder), isTrue);
      expect(identical(toggled, s), isFalse);
    });

    test('toggleKind は有る種類を除去する', () {
      final s = NotificationSettings.defaults();
      final toggled = s.toggleKind(NotificationKind.dailyReminder);
      expect(toggled.isKindEnabled(NotificationKind.dailyReminder), isFalse);
      expect(s.isKindEnabled(NotificationKind.dailyReminder), isTrue);
    });

    test('toggleKind の二重適用は元に戻る', () {
      final s = NotificationSettings.defaults();
      final toggled =
          s.toggleKind(NotificationKind.budgetAlert).toggleKind(
                NotificationKind.budgetAlert,
              );
      expect(toggled, s);
    });
  });

  group('NotificationSettings.copyWith', () {
    test('指定フィールドのみ差し替わる', () {
      final s = NotificationSettings.defaults();
      final c = s.copyWith(enabled: false, hour: 8, minute: 30);
      expect(c.enabled, isFalse);
      expect(c.hour, 8);
      expect(c.minute, 30);
      expect(c.enabledKinds, s.enabledKinds);
    });

    test('引数なしの copyWith は等価なコピーを返す', () {
      final s = NotificationSettings.defaults();
      expect(s.copyWith(), s);
    });

    test('enabledKinds の差し替え', () {
      final s = NotificationSettings.defaults();
      final c = s.copyWith(enabledKinds: {});
      expect(c.enabledKinds, isEmpty);
      expect(s.enabledKinds, isNotEmpty);
    });
  });

  group('NotificationSettings toJson/fromJson', () {
    test('toJson は storageKey リストを保存する', () {
      final json = NotificationSettings.defaults().toJson();
      expect(json['enabled'], isTrue);
      expect(json['hour'], 21);
      expect(json['minute'], 0);
      expect(json['enabledKinds'], [
        'daily_reminder',
        'budget_alert',
        'recurring_transaction',
      ]);
    });

    test('toJson→fromJson の往復で等価になる', () {
      final s = NotificationSettings(
        enabled: false,
        hour: 7,
        minute: 45,
        enabledKinds: {NotificationKind.budgetAlert},
      );
      final restored = NotificationSettings.fromJson(s.toJson());
      expect(restored, s);
    });

    test('fromJson は欠落キーを既定値で補う', () {
      final s = NotificationSettings.fromJson({});
      expect(s.enabled, isTrue);
      expect(s.hour, 21);
      expect(s.minute, 0);
      expect(s.enabledKinds, NotificationKind.values.toSet());
    });

    test('fromJson は範囲外の hour/minute を既定値へフォールバックする', () {
      final s = NotificationSettings.fromJson({
        'hour': 99,
        'minute': -5,
      });
      expect(s.hour, 21);
      expect(s.minute, 0);
    });

    test('fromJson は非intの hour/minute を既定値へフォールバックする', () {
      final s = NotificationSettings.fromJson({
        'hour': 'twenty',
        'minute': 30.5,
      });
      expect(s.hour, 21);
      expect(s.minute, 0);
    });

    test('fromJson は未知の storageKey を無視する', () {
      final s = NotificationSettings.fromJson({
        'enabledKinds': ['daily_reminder', 'unknown_kind'],
      });
      expect(s.enabledKinds, {NotificationKind.dailyReminder});
    });

    test('fromJson は不正な enabled を既定値(true)へフォールバックする', () {
      final s = NotificationSettings.fromJson({'enabled': 'yes'});
      expect(s.enabled, isTrue);
    });
  });

  group('NotificationSettings ==/hashCode', () {
    test('同値ペアは == かつ hashCode が一致', () {
      final a = NotificationSettings.defaults();
      final b = NotificationSettings.defaults();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('順序の異なる enabledKinds でも等価', () {
      final a = NotificationSettings(
        enabled: true,
        hour: 21,
        minute: 0,
        enabledKinds: {
          NotificationKind.dailyReminder,
          NotificationKind.budgetAlert,
        },
      );
      final b = NotificationSettings(
        enabled: true,
        hour: 21,
        minute: 0,
        enabledKinds: {
          NotificationKind.budgetAlert,
          NotificationKind.dailyReminder,
        },
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('異なる設定は非等価', () {
      final a = NotificationSettings.defaults();
      final b = a.copyWith(enabled: false);
      final c = a.copyWith(hour: 22);
      final d = a.copyWith(enabledKinds: {});
      expect(a == b, isFalse);
      expect(a == c, isFalse);
      expect(a == d, isFalse);
    });

    test('他型との比較は false', () {
      expect((NotificationSettings.defaults() as Object) == 'other', isFalse);
    });
  });
}
