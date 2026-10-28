import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/notification/notification_route_resolver.dart';

/// 通知 payload（JSON文字列）→ 遷移先 の純粋解決層の試練。
///
/// 解決層は UI にもプラグインにも依存しない。未知・null・空・破損は
/// すべて null（例外を投げない）でなければならない。
void main() {
  const allowed = <String>{'home', 'budget', 'transactions'};

  group('buildPayload', () {
    test('route のみの payload を JSON で生成する', () {
      final payload = NotificationRouteResolver.buildPayload('budget');

      expect(payload, '{"route":"budget"}');
    });

    test('id 付きの payload を JSON で生成する', () {
      final payload =
          NotificationRouteResolver.buildPayload('transactions', id: '2026-10');

      expect(payload, '{"route":"transactions","id":"2026-10"}');
    });

    test('buildPayload の出力は resolve で往復できる', () {
      final payload =
          NotificationRouteResolver.buildPayload('budget', id: 'abc');

      final resolved =
          NotificationRouteResolver.resolve(payload, allowedRoutes: allowed);

      expect(resolved?.route, 'budget');
      expect(resolved?.id, 'abc');
    });
  });

  group('resolve: 正常系', () {
    test('既知 route を解決する', () {
      final resolved = NotificationRouteResolver.resolve(
        '{"route":"home"}',
        allowedRoutes: allowed,
      );

      expect(resolved?.route, 'home');
      expect(resolved?.id, isNull);
    });

    test('id を保持する', () {
      final resolved = NotificationRouteResolver.resolve(
        '{"route":"transactions","id":"42"}',
        allowedRoutes: allowed,
      );

      expect(resolved?.route, 'transactions');
      expect(resolved?.id, '42');
    });

    test('前後の空白を無視する', () {
      final resolved = NotificationRouteResolver.resolve(
        '  {"route":"budget"}  ',
        allowedRoutes: allowed,
      );

      expect(resolved?.route, 'budget');
    });
  });

  group('resolve: 拒否系（例外なし）', () {
    test('null は null', () {
      expect(NotificationRouteResolver.resolve(null, allowedRoutes: allowed),
          isNull);
    });

    test('空文字は null', () {
      expect(NotificationRouteResolver.resolve('', allowedRoutes: allowed),
          isNull);
    });

    test('空白のみは null', () {
      expect(NotificationRouteResolver.resolve('   ', allowedRoutes: allowed),
          isNull);
    });

    test('壊れた JSON は null', () {
      expect(
        NotificationRouteResolver.resolve('{"route":', allowedRoutes: allowed),
        isNull,
      );
    });

    test('JSON だがオブジェクトでない（配列）は null', () {
      expect(
          NotificationRouteResolver.resolve('["budget"]',
              allowedRoutes: allowed),
          isNull);
    });

    test('JSON だがオブジェクトでない（文字列）は null', () {
      expect(
          NotificationRouteResolver.resolve('"budget"', allowedRoutes: allowed),
          isNull);
    });

    test('route キー欠落は null', () {
      expect(
          NotificationRouteResolver.resolve('{"id":"1"}',
              allowedRoutes: allowed),
          isNull);
    });

    test('route が文字列でない場合は null', () {
      expect(
          NotificationRouteResolver.resolve('{"route":1}',
              allowedRoutes: allowed),
          isNull);
    });

    test('route が空文字は null', () {
      expect(
          NotificationRouteResolver.resolve('{"route":""}',
              allowedRoutes: allowed),
          isNull);
    });

    test('未知の route は null', () {
      expect(
        NotificationRouteResolver.resolve('{"route":"settings"}',
            allowedRoutes: allowed),
        isNull,
      );
    });

    test('allowedRoutes が空なら常に null', () {
      expect(
        NotificationRouteResolver.resolve('{"route":"home"}',
            allowedRoutes: const <String>{}),
        isNull,
      );
    });

    test('id が数値なら破損として null', () {
      expect(
        NotificationRouteResolver.resolve('{"route":"home","id":7}',
            allowedRoutes: allowed),
        isNull,
      );
    });

    test('旧形式の素の文字列 payload は null', () {
      expect(
          NotificationRouteResolver.resolve('budget', allowedRoutes: allowed),
          isNull);
    });
  });

  group('ResolvedNotificationRoute', () {
    test('値等価: 別インスタンスでも同値なら等しい', () {
      final a = ResolvedNotificationRoute(route: 'budget', id: 'x');
      final b = ResolvedNotificationRoute(route: 'budget', id: 'x');

      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('値等価: 異なる値なら等しくない', () {
      final a = ResolvedNotificationRoute(route: 'budget');
      final b = ResolvedNotificationRoute(route: 'home');
      final c = ResolvedNotificationRoute(route: 'budget', id: 'x');

      expect(a == b, isFalse);
      expect(a == c, isFalse);
    });
  });

  group('NotificationRoutes 対応表', () {
    test('家計簿の通知種別に対応する3経路を公開する', () {
      expect(
        NotificationRoutes.all,
        equals(<String>{'home', 'budget', 'transactions'}),
      );
    });
  });
}
