import 'package:flutter/widgets.dart';

import 'package:kozuchi/features/calendar_export/domain/payment_calendar_export_service.dart';

/// 支払い予定書き出し画面の試練用Key一元管理。
class CalendarExportAppKeys {
  const CalendarExportAppKeys._();

  static const Key screen = Key('calendarExportScreen');
  static const Key countLabel = Key('calendarExportCountLabel');
  static const Key previewList = Key('calendarExportPreviewList');
  static const Key exportButton = Key('calendarExportExportButton');
  static const Key emptyLabel = Key('calendarExportEmptyLabel');

  static Key kindChip(PaymentEntryKind kind) =>
      Key('calendarExportKindChip_${kind.name}');
}
