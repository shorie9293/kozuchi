import 'package:flutter/material.dart';

import 'package:kozuchi/core/notification/notification_route_resolver.dart';
import 'package:kozuchi/features/budget/presentation/screens/category_budget_screen.dart';
import 'package:kozuchi/features/transaction_history/presentation/screens/transaction_history_page.dart';
import 'package:kozuchi/screens/main_screen.dart';

/// [ResolvedNotificationRoute] から遷移先 Widget を組み立てる関数。
typedef NotificationRouteBuilder = Widget Function(
  ResolvedNotificationRoute route,
);

/// 通知タップ（および起動経由）の遷移を担う薄い router。
///
/// 役割は「解決済み route → Navigator.push」だけであり、判定・解析は
/// [NotificationRouteResolver] に、通知の発火は `NotificationService` に属する。
/// 対応表（[allowedRoutes]）は resolver 側の [NotificationRoutes.all] と同一で、
/// 未知の route は何もしない。
class NotificationTapRouter {
  /// アプリの [NavigatorState] を保持するキー（`MaterialApp.navigatorKey`）。
  final GlobalKey<NavigatorState> navigatorKey;

  /// route 名 → 画面ビルダー。試練では軽量な偽画面を注入できる。
  final Map<String, NotificationRouteBuilder> _builders;

  /// 遷移を許可する経路の集合（resolver の allowedRoutes と一致）。
  static const Set<String> allowedRoutes = NotificationRoutes.all;

  /// 既定の route 対応表。キーは [allowedRoutes] と一致する。
  static final Map<String, NotificationRouteBuilder> defaultRouteBuilders =
      <String, NotificationRouteBuilder>{
    NotificationRoutes.home: (_) => const MainScreen(),
    NotificationRoutes.budget: (_) => const CategoryBudgetScreen(),
    NotificationRoutes.transactions: (_) => const TransactionHistoryPage(),
  };

  NotificationTapRouter({
    required this.navigatorKey,
    Map<String, NotificationRouteBuilder>? builders,
  }) : _builders = builders ?? defaultRouteBuilders;

  /// Navigator が未接続（起動直後）の間に届いた route を保持する。
  ResolvedNotificationRoute? _pendingRoute;

  /// 保留中の route（無ければ null）。
  ResolvedNotificationRoute? get pendingRoute => _pendingRoute;

  bool _flushScheduled = false;

  /// 保留中の route を取り出す。取り出した時点で消えるため2度目は null。
  ResolvedNotificationRoute? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  /// 解決済み route へ遷移する。null・未知 route・未登録 builder では何もしない。
  ///
  /// Navigator がまだ用意されていない場合は保留し、次のフレームで遷移する。
  void handle(ResolvedNotificationRoute? route) {
    if (route == null) return;
    if (!_builders.containsKey(route.route)) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _pendingRoute = route;
      _scheduleFlush();
      return;
    }
    _push(navigator, route);
  }

  /// 保留分を次フレームで流し込む（多重登録しない）。
  void _scheduleFlush() {
    if (_flushScheduled) return;
    _flushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      final route = _pendingRoute;
      if (route == null) return;
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      _pendingRoute = null;
      _push(navigator, route);
    });
  }

  void _push(NavigatorState navigator, ResolvedNotificationRoute route) {
    final builder = _builders[route.route];
    if (builder == null) return;
    navigator.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: route.route, arguments: route.id),
        builder: (_) => builder(route),
      ),
    );
  }
}
