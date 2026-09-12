import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/installment/domain/models/installment_plan.dart';
import 'package:kozuchi/features/installment/domain/models/subscription.dart';

/// 分割払いプランとサブスクリプションの永続化リポジトリ。
///
/// SharedPreferences に JSON 文字列として保存する。
/// - 分割払い: `kozuchi_installment_plans`
/// - サブスク: `kozuchi_subscriptions`
///
/// 破損データは空として扱い、例外を投げない。
class InstallmentRepository {
  static const String plansKey = 'kozuchi_installment_plans';
  static const String subscriptionsKey = 'kozuchi_subscriptions';

  const InstallmentRepository();

  // ── 分割払い ─────────────────────────────────────

  /// 分割払いプランを読み出す（未保存・破損時は空リスト）。
  Future<List<InstallmentPlan>> loadPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(plansKey);
    if (jsonString == null) return const [];
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return const [];
      final plans = <InstallmentPlan>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final plan = InstallmentPlan.fromJson(item);
          if (plan.id.isNotEmpty) plans.add(plan);
        } else if (item is Map) {
          final plan = InstallmentPlan.fromJson(Map<String, dynamic>.from(item));
          if (plan.id.isNotEmpty) plans.add(plan);
        }
      }
      return List.unmodifiable(plans);
    } catch (_) {
      return const [];
    }
  }

  /// 分割払いプラン一覧を保存する。
  Future<void> savePlans(List<InstallmentPlan> plans) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      plansKey,
      jsonEncode(plans.map((p) => p.toJson()).toList()),
    );
  }

  /// プランを追加する（同一idは置換）。更新後の一覧を返す。
  ///
  /// 総額が負、分割回数が1未満、名称が空白のみなら [ArgumentError]。
  Future<List<InstallmentPlan>> addPlan({
    required String purpose,
    required String category,
    required int totalAmount,
    required int installmentCount,
    required DateTime startDate,
    String? id,
  }) async {
    final trimmed = purpose.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(purpose, 'purpose', '名称を空にはできません');
    }
    if (totalAmount < 0) {
      throw ArgumentError.value(totalAmount, 'totalAmount', '総額は0以上');
    }
    if (installmentCount <= 0) {
      throw ArgumentError.value(installmentCount, 'installmentCount', '回数は1以上');
    }
    final plans = await loadPlans();
    final plan = InstallmentPlan(
      id: id ?? 'plan_${DateTime.now().microsecondsSinceEpoch}',
      purpose: trimmed,
      category: category.trim(),
      totalAmount: totalAmount,
      installmentCount: installmentCount,
      startDate: startDate,
    );
    final updated = [...plans.where((p) => p.id != plan.id), plan];
    await savePlans(updated);
    return List.unmodifiable(updated);
  }

  /// プランを削除する。更新後の一覧を返す。
  Future<List<InstallmentPlan>> removePlan(String id) async {
    final plans = await loadPlans();
    final updated = plans.where((p) => p.id != id).toList();
    await savePlans(updated);
    return List.unmodifiable(updated);
  }

  /// 返済回数を1つ進める（完済済みなら変化しない）。更新後の一覧を返す。
  Future<List<InstallmentPlan>> incrementPaid(String id) async {
    final plans = await loadPlans();
    final updated = [
      for (final plan in plans)
        if (plan.id == id && !plan.isCompleted)
          plan.copyWith(paidCount: plan.paidCount + 1)
        else
          plan,
    ];
    await savePlans(updated);
    return List.unmodifiable(updated);
  }

  /// 有効・無効を切り替える。更新後の一覧を返す。
  Future<List<InstallmentPlan>> togglePlan(String id) async {
    final plans = await loadPlans();
    final updated = [
      for (final plan in plans)
        plan.id == id ? plan.copyWith(isActive: !plan.isActive) : plan,
    ];
    await savePlans(updated);
    return List.unmodifiable(updated);
  }

  // ── サブスク ─────────────────────────────────────

  /// サブスク一覧を読み出す（未保存・破損時は空リスト）。
  Future<List<Subscription>> loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(subscriptionsKey);
    if (jsonString == null) return const [];
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return const [];
      final subs = <Subscription>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final sub = Subscription.fromJson(item);
          if (sub.id.isNotEmpty) subs.add(sub);
        } else if (item is Map) {
          final sub = Subscription.fromJson(Map<String, dynamic>.from(item));
          if (sub.id.isNotEmpty) subs.add(sub);
        }
      }
      return List.unmodifiable(subs);
    } catch (_) {
      return const [];
    }
  }

  /// サブスク一覧を保存する。
  Future<void> saveSubscriptions(List<Subscription> subscriptions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      subscriptionsKey,
      jsonEncode(subscriptions.map((s) => s.toJson()).toList()),
    );
  }

  /// サブスクを追加する（同一idは置換）。更新後の一覧を返す。
  ///
  /// 月額が負、請求日が1〜31の範囲外、名称が空白のみなら [ArgumentError]。
  Future<List<Subscription>> addSubscription({
    required String purpose,
    required String category,
    required int amount,
    required int billingDay,
    required DateTime startDate,
    String? id,
  }) async {
    final trimmed = purpose.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(purpose, 'purpose', '名称を空にはできません');
    }
    if (amount < 0) {
      throw ArgumentError.value(amount, 'amount', '月額は0以上');
    }
    if (billingDay < 1 || billingDay > 31) {
      throw ArgumentError.value(billingDay, 'billingDay', '請求日は1〜31');
    }
    final subs = await loadSubscriptions();
    final sub = Subscription(
      id: id ?? 'sub_${DateTime.now().microsecondsSinceEpoch}',
      purpose: trimmed,
      category: category.trim(),
      amount: amount,
      billingDay: billingDay,
      startDate: startDate,
    );
    final updated = [...subs.where((s) => s.id != sub.id), sub];
    await saveSubscriptions(updated);
    return List.unmodifiable(updated);
  }

  /// サブスクを削除する。更新後の一覧を返す。
  Future<List<Subscription>> removeSubscription(String id) async {
    final subs = await loadSubscriptions();
    final updated = subs.where((s) => s.id != id).toList();
    await saveSubscriptions(updated);
    return List.unmodifiable(updated);
  }

  /// サブスクの有効・無効を切り替える。更新後の一覧を返す。
  Future<List<Subscription>> toggleSubscription(String id) async {
    final subs = await loadSubscriptions();
    final updated = [
      for (final sub in subs)
        sub.id == id ? sub.copyWith(isActive: !sub.isActive) : sub,
    ];
    await saveSubscriptions(updated);
    return List.unmodifiable(updated);
  }
}
