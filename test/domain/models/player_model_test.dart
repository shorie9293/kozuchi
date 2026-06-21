import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/advisor.dart';
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
          .contractWith(Advisor.lifePlanner);
      expect(player.advisor, Advisor.lifePlanner);
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
  });
}
