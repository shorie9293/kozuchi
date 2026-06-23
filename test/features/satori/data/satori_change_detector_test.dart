import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/level_stage.dart';
import 'package:kozuchi/features/satori/data/satori_change_detector.dart';
import 'package:kozuchi/features/satori/data/satori_event_dispatcher.dart';
import 'package:kozuchi/features/satori/domain/satori_change_event.dart';
import 'package:kozuchi/features/satori/domain/satori_reason.dart';

void main() {
  setUp(() {
    // テスト前にリスナーをクリア
    SatoriEventDispatcher.instance.removeAllListeners();
  });

  group('SatoriChangeDetector.detect', () {
    const detector = SatoriChangeDetector();

    test('SATORI増加を検出する', () {
      final oldPlayer = PlayerModel.defaultPlayer(); // exp=0
      final newPlayer = oldPlayer.addExp(15); // exp=15
      final event = detector.detect(
        oldPlayer: oldPlayer,
        newPlayer: newPlayer,
        context: SatoriContext.generic(),
      );

      expect(event, isNotNull);
      expect(event!.direction, SatoriDirection.increase);
      expect(event.oldValue, 0);
      expect(event.newValue, 15);
      expect(event.delta, 15);
    });

    test('SATORI減少を検出する（将来のピンチゾーン等）', () {
      final oldPlayer = PlayerModel(exp: 30);
      // 減少をシミュレート（直接コンストラクタで作成）
      final newPlayer = PlayerModel(exp: 20);
      final event = detector.detect(
        oldPlayer: oldPlayer,
        newPlayer: newPlayer,
        context: const SatoriContext(triggerType: SatoriTriggerType.pinchPenalty),
      );

      expect(event, isNotNull);
      expect(event!.direction, SatoriDirection.decrease);
      expect(event.oldValue, 30);
      expect(event.newValue, 20);
      expect(event.delta, 10);
    });

    test('変動なしの場合はnullを返す', () {
      final player = PlayerModel.defaultPlayer();
      final event = detector.detect(
        oldPlayer: player,
        newPlayer: player,
        context: SatoriContext.generic(),
      );

      expect(event, isNull);
    });

    test('変動なし（同一exp値）の場合はnull', () {
      final oldPlayer = PlayerModel(exp: 42);
      final newPlayer = PlayerModel(exp: 42);
      final event = detector.detect(
        oldPlayer: oldPlayer,
        newPlayer: newPlayer,
        context: SatoriContext.generic(),
      );

      expect(event, isNull);
    });

    test('文脈情報がイベントに反映される', () {
      final oldPlayer = PlayerModel.defaultPlayer();
      final newPlayer = oldPlayer.addExp(10);
      final event = detector.detect(
        oldPlayer: oldPlayer,
        newPlayer: newPlayer,
        context: SatoriContext.reflectionReview(
          advisorLabel: '弁財天',
          expMultiplier: 1.5,
          offeringAmount: 3000,
          previousStage: LevelStage.shoTenborin,
          newStage: LevelStage.shoTenborin,
        ),
      );

      expect(event, isNotNull);
      expect(event!.reason, '善き振り返りの恵み');
      expect(event.context, '弁財天');
    });

    test('段階突破が検出される', () {
      final oldPlayer = PlayerModel(exp: 45); // レベル1
      final newPlayer = PlayerModel(exp: 55); // レベル2
      final event = detector.detect(
        oldPlayer: oldPlayer,
        newPlayer: newPlayer,
        context: SatoriContext.generic(
          previousStage: LevelStage.shoTenborin,
          newStage: LevelStage.engi,
        ),
      );

      expect(event, isNotNull);
      expect(event!.reason, '新たな開眼 — 金は縁として巡る');
      expect(event.delta, 10);
    });
  });

  group('SatoriChangeDetector.detectAndDispatch', () {
    const detector = SatoriChangeDetector();

    test('イベントを発行し、リスナーが受け取る', () {
      SatoriChangeEvent? received;
      SatoriEventDispatcher.instance.addListener((event) {
        received = event;
      });

      final oldPlayer = PlayerModel.defaultPlayer();
      final newPlayer = oldPlayer.addExp(20);
      final event = detector.detectAndDispatch(
        oldPlayer: oldPlayer,
        newPlayer: newPlayer,
        context: SatoriContext.generic(),
      );

      expect(event, isNotNull);
      expect(received, isNotNull);
      expect(received, same(event));
    });

    test('変動なしの場合は発行されずnullを返す', () {
      var called = false;
      SatoriEventDispatcher.instance.addListener((_) {
        called = true;
      });

      final player = PlayerModel.defaultPlayer();
      final event = detector.detectAndDispatch(
        oldPlayer: player,
        newPlayer: player,
        context: SatoriContext.generic(),
      );

      expect(event, isNull);
      expect(called, isFalse);
    });

    test('複数リスナーが全て呼ばれる', () {
      var count = 0;
      SatoriEventDispatcher.instance.addListener((_) => count++);
      SatoriEventDispatcher.instance.addListener((_) => count++);
      SatoriEventDispatcher.instance.addListener((_) => count++);

      final oldPlayer = PlayerModel.defaultPlayer();
      final newPlayer = oldPlayer.addExp(5);
      detector.detectAndDispatch(
        oldPlayer: oldPlayer,
        newPlayer: newPlayer,
        context: SatoriContext.generic(),
      );

      expect(count, 3);
    });
  });

  group('SatoriEventDispatcher', () {
    test('シングルトン', () {
      expect(SatoriEventDispatcher.instance, same(SatoriEventDispatcher.instance));
    });

    test('リスナーが登録・解除できる', () {
      final dispatcher = SatoriEventDispatcher.instance;
      expect(dispatcher.listenerCount, 0);

      void listener(SatoriChangeEvent _) {}
      dispatcher.addListener(listener);
      expect(dispatcher.listenerCount, 1);

      dispatcher.removeListener(listener);
      expect(dispatcher.listenerCount, 0);
    });

    test('removeAllListenersで全解除', () {
      final dispatcher = SatoriEventDispatcher.instance;
      dispatcher.addListener((_) {});
      dispatcher.addListener((_) {});
      expect(dispatcher.listenerCount, 2);

      dispatcher.removeAllListeners();
      expect(dispatcher.listenerCount, 0);
    });

    test('lastEventが更新される', () {
      final dispatcher = SatoriEventDispatcher.instance;
      const event = SatoriChangeEvent(
        direction: SatoriDirection.increase,
        reason: 'test',
        oldValue: 0,
        newValue: 10,
        delta: 10,
      );

      dispatcher.dispatch(event);
      expect(dispatcher.lastEvent, same(event));
    });

    test('リスナー内で例外が発生しても他のリスナーは呼ばれる', () {
      var secondCalled = false;
      SatoriEventDispatcher.instance.addListener((_) {
        throw Exception('test error');
      });
      SatoriEventDispatcher.instance.addListener((_) {
        secondCalled = true;
      });

      const event = SatoriChangeEvent(
        direction: SatoriDirection.increase,
        reason: 'test',
        oldValue: 0,
        newValue: 10,
        delta: 10,
      );
      SatoriEventDispatcher.instance.dispatch(event);

      expect(secondCalled, isTrue);
    });

    test('dispatch中にaddListenerしても安全', () {
      var nestedAdded = false;
      void nestedListener(SatoriChangeEvent _) {
        nestedAdded = true;
      }

      SatoriEventDispatcher.instance.addListener((_) {
        SatoriEventDispatcher.instance.addListener(nestedListener);
      });

      const event = SatoriChangeEvent(
        direction: SatoriDirection.increase,
        reason: 'test',
        oldValue: 0,
        newValue: 10,
        delta: 10,
      );
      SatoriEventDispatcher.instance.dispatch(event);

      // nestedListenerはこのdispatchでは呼ばれない（コピーに対して反復するため）
      expect(nestedAdded, isFalse);
      // しかし登録はされている
      expect(SatoriEventDispatcher.instance.listenerCount, 2);
    });
  });
}
