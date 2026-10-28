import 'dart:convert';

/// kozuchi の通知タップで遷移できる経路名の対応表。
///
/// 通知 payload の `route` は必ずこの集合のいずれかでなければならない。
/// [NotificationRouteResolver.resolve] の `allowedRoutes` と、
/// タップ遷移を担う `NotificationTapRouter` の対応表は同じ集合を共有する。
abstract final class NotificationRoutes {
  /// ホーム（メイン画面）
  static const String home = 'home';

  /// 予算（予算設定・予算状況）
  static const String budget = 'budget';

  /// 取引履歴（記帳の確認）
  static const String transactions = 'transactions';

  /// 遷移可能な全経路。
  static const Set<String> all = <String>{home, budget, transactions};
}

/// 通知 payload を解決した結果。
///
/// 値等価（[route] と [id] が等しければ同一）として扱う。
class ResolvedNotificationRoute {
  /// 遷移先の経路名（[NotificationRoutes] のいずれか）。
  final String route;

  /// 遷移先へ引き渡す識別子（月キー・取引IDなど）。無ければ null。
  final String? id;

  const ResolvedNotificationRoute({required this.route, this.id});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ResolvedNotificationRoute &&
        other.route == route &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(route, id);

  @override
  String toString() => 'ResolvedNotificationRoute(route: $route, id: $id)';
}

/// 通知 payload（JSON文字列）と遷移先の相互変換を担う純粋層。
///
/// payload 形式: `{"route":"budget","id":"2026-10"}`
/// - [resolve] は未知・null・空・破損のいずれでも例外を投げず null を返す。
/// - UI・プラグイン・Navigator には一切依存しない。
abstract final class NotificationRouteResolver {
  /// payload を [ResolvedNotificationRoute] へ解決する。
  ///
  /// 次のいずれかに該当する場合は null（例外は投げない）:
  /// - payload が null / 空 / 空白のみ
  /// - JSON として不正、またはオブジェクトでない
  /// - `route` が文字列でない / 空 / [allowedRoutes] に含まれない
  /// - `id` が文字列でも null でもない（破損扱い）
  static ResolvedNotificationRoute? resolve(
    String? payload, {
    required Set<String> allowedRoutes,
  }) {
    if (payload == null) return null;
    final trimmed = payload.trim();
    if (trimmed.isEmpty) return null;

    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;

    final rawRoute = decoded['route'];
    if (rawRoute is! String) return null;
    final route = rawRoute.trim();
    if (route.isEmpty || !allowedRoutes.contains(route)) return null;

    final rawId = decoded['id'];
    if (rawId != null && rawId is! String) return null;
    final id = rawId is String && rawId.isNotEmpty ? rawId : null;

    return ResolvedNotificationRoute(route: route, id: id);
  }

  /// 通知スケジュール時に埋め込む payload を生成する。
  ///
  /// [id] が null の場合は `route` のみを含める。
  static String buildPayload(String route, {String? id}) {
    return jsonEncode(<String, String>{
      'route': route,
      if (id != null) 'id': id,
    });
  }
}
