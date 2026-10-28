import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/notification/notification_route_resolver.dart';
import 'package:kozuchi/core/notification/notification_tap_router.dart';

/// Navigator に実際に積まれた route を記録する監視者。
class _RecordingObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = <Route<dynamic>>[];
  final List<Route<dynamic>> popped = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped.add(route);
    super.didPop(route, previousRoute);
  }
}

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late _RecordingObserver observer;

  /// 既定画面の代わりに軽量なマーカー画面を使う（ネットワーク・プラグイン不要）。
  Map<String, NotificationRouteBuilder> fakeBuilders() =>
      <String, NotificationRouteBuilder>{
        NotificationRoutes.home: (_) => const Scaffold(body: Text('page:home')),
        NotificationRoutes.budget: (route) =>
            Scaffold(body: Text('page:budget:${route.id ?? '-'}')),
        NotificationRoutes.transactions: (route) =>
            Scaffold(body: Text('page:transactions:${route.id ?? '-'}')),
      };

  setUp(() {
    navigatorKey = GlobalKey<NavigatorState>();
    observer = _RecordingObserver();
  });

  Future<NotificationTapRouter> pumpApp(
    WidgetTester tester, {
    Map<String, NotificationRouteBuilder>? builders,
  }) async {
    final router = NotificationTapRouter(
      navigatorKey: navigatorKey,
      builders: builders ?? fakeBuilders(),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: <NavigatorObserver>[observer],
        home: const Scaffold(body: Text('page:root')),
      ),
    );
    return router;
  }

  group('対応表', () {
    test('allowedRoutes は resolver 側の対応表と一致する', () {
      expect(NotificationTapRouter.allowedRoutes, NotificationRoutes.all);
    });

    test('既定の builders は全 allowedRoutes を網羅する', () {
      expect(
        NotificationTapRouter.defaultRouteBuilders.keys.toSet(),
        NotificationTapRouter.allowedRoutes,
      );
    });
  });

  group('既知 route の遷移', () {
    testWidgets('budget を渡すと Navigator に push される', (tester) async {
      final router = await pumpApp(tester);
      final before = observer.pushed.length;

      router
          .handle(ResolvedNotificationRoute(route: NotificationRoutes.budget));
      await tester.pumpAndSettle();

      expect(observer.pushed.length, before + 1);
      expect(observer.pushed.last, isA<MaterialPageRoute<void>>());
      expect(find.text('page:budget:-'), findsOneWidget);
    });

    testWidgets('transactions を渡すと該当画面が表示される', (tester) async {
      final router = await pumpApp(tester);

      router.handle(
        ResolvedNotificationRoute(
          route: NotificationRoutes.transactions,
          id: '2026-10',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('page:transactions:2026-10'), findsOneWidget);
    });

    testWidgets('home を渡すとホーム画面が表示される', (tester) async {
      final router = await pumpApp(tester);

      router.handle(ResolvedNotificationRoute(route: NotificationRoutes.home));
      await tester.pumpAndSettle();

      expect(find.text('page:home'), findsOneWidget);
    });

    testWidgets('id は builder へ引き渡される', (tester) async {
      final ids = <String?>[];
      final router = await pumpApp(
        tester,
        builders: <String, NotificationRouteBuilder>{
          NotificationRoutes.budget: (route) {
            ids.add(route.id);
            return const Scaffold(body: Text('page:budget'));
          },
        },
      );

      router.handle(
        ResolvedNotificationRoute(route: NotificationRoutes.budget, id: 'b-1'),
      );
      await tester.pumpAndSettle();

      expect(ids, <String?>['b-1']);
    });

    testWidgets('2回続けて渡すと2回 push される（置換ではなく積み上げ）', (tester) async {
      final router = await pumpApp(tester);
      final before = observer.pushed.length;

      router
          .handle(ResolvedNotificationRoute(route: NotificationRoutes.budget));
      router.handle(
        ResolvedNotificationRoute(route: NotificationRoutes.transactions),
      );
      await tester.pumpAndSettle();

      expect(observer.pushed.length, before + 2);
    });
  });

  group('遷移しない場合', () {
    testWidgets('null では push されない', (tester) async {
      final router = await pumpApp(tester);
      final before = observer.pushed.length;

      router.handle(null);
      await tester.pumpAndSettle();

      expect(observer.pushed.length, before);
      expect(find.text('page:root'), findsOneWidget);
    });

    testWidgets('未知 route では push されず何も起きない', (tester) async {
      final router = await pumpApp(tester);
      final before = observer.pushed.length;

      router.handle(ResolvedNotificationRoute(route: 'settings'));
      await tester.pumpAndSettle();

      expect(observer.pushed.length, before);
      expect(find.text('page:root'), findsOneWidget);
    });

    testWidgets('builders に無い route でも例外を投げない', (tester) async {
      final router = await pumpApp(
        tester,
        builders: <String, NotificationRouteBuilder>{},
      );

      expect(
        () => router.handle(
          ResolvedNotificationRoute(route: NotificationRoutes.budget),
        ),
        returnsNormally,
      );
      await tester.pumpAndSettle();
      expect(find.text('page:root'), findsOneWidget);
    });
  });

  group('Navigator 未接続時の保留', () {
    testWidgets('currentState が null のときは保留し push しない', (tester) async {
      final router = NotificationTapRouter(
        navigatorKey: navigatorKey,
        builders: fakeBuilders(),
      );

      router
          .handle(ResolvedNotificationRoute(route: NotificationRoutes.budget));

      expect(observer.pushed, isEmpty);
      expect(router.pendingRoute?.route, NotificationRoutes.budget);
    });

    testWidgets('consumePendingRoute は1度だけ取り出せる', (tester) async {
      final router = NotificationTapRouter(
        navigatorKey: navigatorKey,
        builders: fakeBuilders(),
      );
      router.handle(
        ResolvedNotificationRoute(route: NotificationRoutes.transactions),
      );

      final first = router.consumePendingRoute();
      final second = router.consumePendingRoute();

      expect(first?.route, NotificationRoutes.transactions);
      expect(second, isNull);
      expect(router.pendingRoute, isNull);
    });
  });
}
