import 'package:kozuchi/features/installment/domain/installment_service.dart';
import 'package:kozuchi/features/installment/domain/models/installment_plan.dart';
import 'package:kozuchi/features/installment/domain/models/subscription.dart';

/// 同一日の支払い予定をまとめたグループ。
class UpcomingBillingGroup {
  /// 支払い日（時刻は 00:00 に正規化済み）
  final DateTime date;

  /// 同日の支払い予定（id 昇順）
  final List<UpcomingBilling> billings;

  const UpcomingBillingGroup({required this.date, required this.billings});

  /// billings の amount 合計（円）
  int get totalAmount =>
      billings.fold(0, (sum, b) => sum + b.amount);

  /// 支払い予定の件数
  int get count => billings.length;
}

/// 支払い予定の全体サマリー。
class UpcomingBillingSummary {
  /// 日別グループ（date 昇順）
  final List<UpcomingBillingGroup> groups;

  /// 全グループの合計金額（円）
  final int totalAmount;

  /// 全件数
  final int count;

  /// 集計対象日数
  final int withinDays;

  const UpcomingBillingSummary({
    required this.groups,
    required this.totalAmount,
    required this.count,
    required this.withinDays,
  });

  /// 支払い予定が1件もないか
  bool get isEmpty => groups.isEmpty;

  /// 直近の支払い日（空なら null）
  DateTime? get nextDate => groups.isEmpty ? null : groups.first.date;
}

/// 支払い予定の日別集約を担う純粋ロジック。
///
/// 既存 [InstallmentService.upcomingBillings] を素材として再利用し、
/// 日付（00:00 正規化）ごとにグループ化する。副作用なし・決定的。
class UpcomingBillingSummaryService {
  const UpcomingBillingSummaryService._();

  /// 支払い予定を日別にグループ化した [UpcomingBillingSummary] を返す。
  ///
  /// [withinDays] が負なら 0 として扱う（例外にはしない）。
  /// [plans] / [subscriptions] は非破壊。
  static UpcomingBillingSummary build({
    required List<InstallmentPlan> plans,
    required List<Subscription> subscriptions,
    int withinDays = 30,
    DateTime? from,
  }) {
    final effectiveWithinDays = withinDays < 0 ? 0 : withinDays;
    final billings = InstallmentService.upcomingBillings(
      plans: plans,
      subscriptions: subscriptions,
      withinDays: effectiveWithinDays,
      from: from,
    );

    final groups = <UpcomingBillingGroup>[];
    for (final billing in billings) {
      final day = DateTime(
        billing.date.year,
        billing.date.month,
        billing.date.day,
      );
      if (groups.isNotEmpty && _sameDay(groups.last.date, day)) {
        groups.last.billings.add(billing);
      } else {
        groups.add(
          UpcomingBillingGroup(date: day, billings: [billing]),
        );
      }
    }

    return UpcomingBillingSummary(
      groups: groups,
      totalAmount: groups.fold(0, (sum, g) => sum + g.totalAmount),
      count: groups.fold(0, (sum, g) => sum + g.count),
      withinDays: effectiveWithinDays,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
