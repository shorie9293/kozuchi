import 'package:kozuchi/features/installment/domain/models/installment_plan.dart';
import 'package:kozuchi/features/installment/domain/models/subscription.dart';

/// 今後到来する支払い予定（分割払い・サブスクの共通表現）
class UpcomingBilling {
  final String id;
  final String label;
  final String category;
  final DateTime date;

  /// 支払い額（円、正の値）
  final int amount;

  /// サブスク由来なら true、分割払い由来なら false
  final bool isSubscription;

  const UpcomingBilling({
    required this.id,
    required this.label,
    required this.category,
    required this.date,
    required this.amount,
    required this.isSubscription,
  });
}

/// 分割払い・サブスクリプションの計算を担う純粋ロジック。
///
/// 副作用を持たず、日付・金額の算出はすべて引数から決定論的に導出する。
class InstallmentService {
  const InstallmentService._();

  /// 月々の支払額（円、切り上げ）。
  ///
  /// [totalAmount] が負、または [installmentCount] が 1 未満なら [ArgumentError]。
  static int monthlyAmount(int totalAmount, int installmentCount) {
    if (totalAmount < 0) {
      throw ArgumentError.value(totalAmount, 'totalAmount', '総額は0以上');
    }
    if (installmentCount <= 0) {
      throw ArgumentError.value(installmentCount, 'installmentCount', '回数は1以上');
    }
    return (totalAmount / installmentCount).ceil();
  }

  /// プランの月額
  static int monthlyAmountOf(InstallmentPlan plan) =>
      monthlyAmount(plan.totalAmount, plan.installmentCount);

  /// 残債額（円、0以上）
  static int remainingAmount(InstallmentPlan plan) {
    final paid = monthlyAmountOf(plan) * plan.paidCount;
    final remaining = plan.totalAmount - paid;
    return remaining < 0 ? 0 : remaining;
  }

  /// 返済済み額（円）
  static int paidAmount(InstallmentPlan plan) =>
      plan.totalAmount - remainingAmount(plan);

  /// 指定した年月の日付を作る。月の桁溢れは正規化し、日は月末で丸める。
  static DateTime dateInMonth(int year, int month, int day) {
    final normalized = DateTime(year, month, 1);
    final y = normalized.year;
    final m = normalized.month;
    final lastDay = DateTime(y, m + 1, 0).day;
    final d = day < 1 ? 1 : (day > lastDay ? lastDay : day);
    return DateTime(y, m, d);
  }

  /// 次回の支払日（完済なら null）。
  ///
  /// 初回支払日を起点に、返済済み回数ぶん進めた月の同日を返す。
  static DateTime? nextPaymentDate(InstallmentPlan plan) {
    if (plan.isCompleted) return null;
    return dateInMonth(
      plan.startDate.year,
      plan.startDate.month + plan.paidCount,
      plan.startDate.day,
    );
  }

  /// サブスクの次回請求日（[from] 当日を含む直近の請求日）。
  ///
  /// 基準日 [from]（省略時は現在）の当月請求日が基準日より前なら翌月を返す。
  static DateTime nextBillingDate(Subscription sub, {DateTime? from}) {
    final base = from ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    var candidate = dateInMonth(base.year, base.month, sub.billingDay);
    if (candidate.isBefore(today)) {
      candidate = dateInMonth(base.year, base.month + 1, sub.billingDay);
    }
    return candidate;
  }

  /// 有効なサブスクの月額合計（円）
  static int subscriptionMonthlyTotal(List<Subscription> subscriptions) {
    var total = 0;
    for (final sub in subscriptions) {
      if (sub.isActive) total += sub.amount;
    }
    return total;
  }

  /// 有効なサブスクの年額合計（円）
  static int subscriptionYearlyTotal(List<Subscription> subscriptions) =>
      subscriptionMonthlyTotal(subscriptions) * 12;

  /// 有効かつ未完済の分割払いの月額合計（円）
  static int totalMonthlyInstallmentBurden(List<InstallmentPlan> plans) {
    var total = 0;
    for (final plan in plans) {
      if (plan.isActive && !plan.isCompleted) total += monthlyAmountOf(plan);
    }
    return total;
  }

  /// 有効な分割払いの総残債額（円）
  static int totalRemainingAmount(List<InstallmentPlan> plans) {
    var total = 0;
    for (final plan in plans) {
      if (plan.isActive) total += remainingAmount(plan);
    }
    return total;
  }

  /// 毎月の固定費負担（分割払い月額 + サブスク月額、円）
  static int totalMonthlyFixedCost({
    required List<InstallmentPlan> plans,
    required List<Subscription> subscriptions,
  }) =>
      totalMonthlyInstallmentBurden(plans) +
      subscriptionMonthlyTotal(subscriptions);

  /// 基準日 [from] から [withinDays] 日以内に到来する支払い予定を返す。
  ///
  /// 無効なもの・完済済みの分割払いは対象外。日付昇順、同日なら id 昇順で並ぶ。
  static List<UpcomingBilling> upcomingBillings({
    required List<InstallmentPlan> plans,
    required List<Subscription> subscriptions,
    int withinDays = 7,
    DateTime? from,
  }) {
    final base = from ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    final limit = today.add(Duration(days: withinDays < 0 ? 0 : withinDays));
    final items = <UpcomingBilling>[];

    for (final plan in plans) {
      if (!plan.isActive || plan.isCompleted) continue;
      final date = nextPaymentDate(plan);
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      if (day.isBefore(today) || day.isAfter(limit)) continue;
      items.add(
        UpcomingBilling(
          id: plan.id,
          label: plan.purpose,
          category: plan.category,
          date: day,
          amount: monthlyAmountOf(plan),
          isSubscription: false,
        ),
      );
    }

    for (final sub in subscriptions) {
      if (!sub.isActive) continue;
      final date = nextBillingDate(sub, from: base);
      final day = DateTime(date.year, date.month, date.day);
      if (day.isBefore(today) || day.isAfter(limit)) continue;
      items.add(
        UpcomingBilling(
          id: sub.id,
          label: sub.purpose,
          category: sub.category,
          date: day,
          amount: sub.amount,
          isSubscription: true,
        ),
      );
    }

    items.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return a.id.compareTo(b.id);
    });
    return items;
  }
}
