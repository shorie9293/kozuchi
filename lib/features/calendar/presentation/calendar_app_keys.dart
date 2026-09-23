import 'package:flutter/widgets.dart';

/// 取引カレンダー画面の試練用Key一元管理。
class CalendarAppKeys {
  const CalendarAppKeys._();

  static const Key screen = Key('calendarScreen');
  static const Key monthLabel = Key('calendar_monthLabel');
  static const Key prevMonthButton = Key('calendar_prevMonthButton');
  static const Key nextMonthButton = Key('calendar_nextMonthButton');
  static const Key totalAmount = Key('calendar_totalAmount');
  static const Key spendingDays = Key('calendar_spendingDays');
  static const Key maxDay = Key('calendar_maxDay');
  static const Key emptyMessage = Key('calendar_emptyMessage');
  static const Key dayDetailDialog = Key('calendar_dayDetailDialog');
  static const Key openButton = Key('calendar_openButton');

  static Key dayCell(DateTime d) =>
      Key('calendar_dayCell_${d.year}-${d.month}-${d.day}');

  static Key dayAmount(DateTime d) =>
      Key('calendar_dayAmount_${d.year}-${d.month}-${d.day}');

  static Key dayDetailRow(String entryId) =>
      Key('calendar_dayDetailRow_$entryId');
}