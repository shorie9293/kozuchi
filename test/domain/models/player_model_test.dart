import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/guardian_deity.dart';
import 'package:kozuchi/domain/models/enlightenment_stage.dart';
import 'package:kozuchi/domain/models/player_model.dart';

void main() {
  group('PlayerModel', () {
    test('デフォルト値で生成できる', () {
      final player = PlayerModel.defaultPlayer();
      expect(player.hp, 100000);
      expect(player.satori, 0);
      expect(player.guardianDeity, isNull);
      expect(player.enlightenmentStage, EnlightenmentStage.shoTenborin);
    });

    test('HPを設定して生成できる', () {
      final player = PlayerModel(hp: 50000);
      expect(player.hp, 50000);
      expect(player.satori, 0);
    });

    test('SATORI値から開眼段階が自動計算される', () {
      final player = PlayerModel(satori: 60);
      expect(player.enlightenmentStage, EnlightenmentStage.engi);
    });

    test('喜捨（HP減少）が実行できる', () {
      final player = PlayerModel(hp: 50000).performOffering(1000);
      expect(player.hp, 49000);
    });

    test('喜捨額がHPを超える場合はエラーにならない（0以上にクランプ）', () {
      final player = PlayerModel(hp: 500).performOffering(1000);
      expect(player.hp, 0);
    });

    test('SATORIを加算できる', () {
      final player = PlayerModel(satori: 10).addSatori(15);
      expect(player.satori, 25);
    });

    test('守護神を契約できる', () {
      final player = PlayerModel.defaultPlayer()
          .contractWith(GuardianDeity.daikokuten);
      expect(player.guardianDeity, GuardianDeity.daikokuten);
    });

    test('餓鬼状態（HPが生活防衛ライン以下）を検出できる', () {
      final player = PlayerModel(hp: 25000);
      expect(player.isGakiState, isTrue);
    });

    test('通常状態では餓鬼状態ではない', () {
      final player = PlayerModel(hp: 50000);
      expect(player.isGakiState, isFalse);
    });

    test('生活防衛ラインと同額（30,000円）では餓鬼状態と判定される', () {
      final player = PlayerModel(hp: 30000);
      expect(player.isGakiState, isTrue);
    });

    test('生活防衛ラインは固定値30,000円', () {
      expect(PlayerModel.livingDefenseLine, 30000);
    });
  });
}
