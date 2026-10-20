import 'package:flutter/widgets.dart';

import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_policy.dart';

/// 静穏時間設定画面の試練用 AppKeys。
class QuietHoursAppKeys {
  const QuietHoursAppKeys._();

  static const Key screen = Key('quietHoursScreen');
  static const Key enabledSwitch = Key('quietHoursEnabledSwitch');
  static const Key startHourDropdown = Key('quietHoursStartHourDropdown');
  static const Key startMinuteDropdown = Key('quietHoursStartMinuteDropdown');
  static const Key endHourDropdown = Key('quietHoursEndHourDropdown');
  static const Key endMinuteDropdown = Key('quietHoursEndMinuteDropdown');
  static const Key startLabel = Key('quietHoursStartLabel');
  static const Key endLabel = Key('quietHoursEndLabel');
  static const Key previewText = Key('quietHoursPreviewText');
  static const Key saveButton = Key('quietHoursSaveButton');

  static Key policyRadio(QuietHoursPolicy policy) =>
      Key('quietHoursPolicy_${policy.storageKey}');
}
