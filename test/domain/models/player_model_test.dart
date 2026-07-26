import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/domain/models/gold_luck_buff.dart';
import 'package:kozuchi/domain/models/level_stage.dart';
import 'package:kozuchi/domain/models/player_model.dart';

void main() {
  group('PlayerModel', () {
    test('デフォルト値で生成できる', () {
      final player = PlayerModel.defaultPlayer();
      expect(player.hp, 100000);
      expect(player.exp, 0);
      expect(player.advisor, isNull);
      expect(player.levelStage, LevelStage.shoTenborin);
    });

    test('HPを設定して生成できる', () {
      final player = PlayerModel(hp: 50000);
      expect(player.hp, 50000);
      expect(player.exp, 0);
    });

    test('EXP値から開眼段階が自動計算される', () {
      final player = PlayerModel(exp: 60);
      expect(player.levelStage, LevelStage.engi);
    });

    test('支出（HP減少）が実行できる', () {
      final player = PlayerModel(hp: 50000).performOffering(1000);
      expect(player.hp, 49000);
    });

    test('支出額がHPを超える場合はエラーにならない（0以上にクランプ）', () {
      final player = PlayerModel(hp: 500).performOffering(1000);
      expect(player.hp, 0);
    });

    test('EXPを加算できる', () {
      final player = PlayerModel(exp: 10).addExp(15);
      expect(player.exp, 25);
    });

    test('アドバイザーを契約できる', () {
      final player = PlayerModel.defaultPlayer()
          .contractWith(Advisor.daikokuten);
      expect(player.advisor, Advisor.daikokuten);
    });

    test('ピンチ状態（HPが生活防衛ライン以下）を検出できる', () {
      final player = PlayerModel(hp: 25000);
      expect(player.isPinchState, isTrue);
    });

    test('通常状態ではピンチ状態ではない', () {
      final player = PlayerModel(hp: 50000);
      expect(player.isPinchState, isFalse);
    });

    test('生活防衛ラインと同額（30,000円）ではピンチ状態と判定される', () {
      final player = PlayerModel(hp: 30000);
      expect(player.isPinchState, isTrue);
    });

    test('生活防衛ラインは固定値30,000円', () {
      expect(PlayerModel.livingDefenseLine, 30000);
    });

    group('addHp', () {
      test('残高に指定額を加算できる', () {
        final player = PlayerModel(hp: 50000);
        final updated = player.addHp(30000);
        expect(updated.hp, 80000);
      });

      test('加算後のHPは元のEXPを保持する', () {
        final player = PlayerModel(hp: 50000, exp: 100);
        final updated = player.addHp(30000);
        expect(updated.exp, 100);
      });

      test('加算後にアドバイザー契約状態を保持する', () {
        final player = PlayerModel(hp: 50000, advisor: Advisor.daikokuten);
        final updated = player.addHp(30000);
        expect(updated.advisor, Advisor.daikokuten);
      });

      test('金運上昇バフが有効な場合は倍率が適用される', () {
        final buff = GoldLuckBuff(
          multiplier: 2.0,
          expiresAt: DateTime.now().add(const Duration(days: 1)),
          source: 'test',
          activatedAt: DateTime.now(),
        );
        final player = PlayerModel(hp: 50000, goldLuckBuff: buff);
        final updated = player.addHp(10000);
        expect(updated.hp, 70000);
      });
    });
  });
}
