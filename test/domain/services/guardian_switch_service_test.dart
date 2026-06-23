import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/services/guardian_switch_service.dart';

void main() {
  group('GuardianSwitchService', () {
    late GuardianSwitchService service;

    setUp(() {
      service = const GuardianSwitchService();
    });

    // ── 正常系 ──

    test('守護神を切り替えられる（EXP消費・クールダウン記録）', () {
      final player = PlayerModel(
        hp: 100000,
        exp: 500,
        advisor: Advisor.lifePlanner,
      );

      final result = service.switchGuardian(player, Advisor.careerCoach);

      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
      expect(result.newAdvisor, Advisor.careerCoach);
      expect(result.player!.advisor, Advisor.careerCoach);
      expect(result.player!.exp, 500 - PlayerModel.switchExpCost);
      expect(result.player!.lastSwitchTimestamp, isNotNull);
      expect(
        result.player!.lastSwitchTimestamp!
            .difference(DateTime.now())
            .inSeconds
            .abs(),
        lessThan(5),
      );
      expect(result.remainingCooldown, PlayerModel.switchCooldownDuration);
    });

    test('EXPがちょうどコスト分ある場合も切り替えられる', () {
      final player = PlayerModel(
        hp: 100000,
        exp: PlayerModel.switchExpCost,
        advisor: Advisor.lifePlanner,
      );

      final result = service.switchGuardian(player, Advisor.investmentMentor);

      expect(result.isSuccess, isTrue);
      expect(result.player!.exp, 0);
      expect(result.player!.advisor, Advisor.investmentMentor);
    });

    test('任意の守護神に切り替えられる', () {
      final player = PlayerModel(
        hp: 100000,
        exp: 500,
        advisor: Advisor.careerCoach,
      );

      final result = service.switchGuardian(player, Advisor.wellnessAdvisor);

      expect(result.isSuccess, isTrue);
      expect(result.newAdvisor, Advisor.wellnessAdvisor);
    });

    // ── エラー系: EXP不足 ──

    test('EXP不足の場合はエラー（insufficientExp）', () {
      final player = PlayerModel(
        hp: 100000,
        exp: 50,
        advisor: Advisor.lifePlanner,
      );

      final result = service.switchGuardian(player, Advisor.careerCoach);

      expect(result.isSuccess, isFalse);
      expect(result.error, GuardianSwitchError.insufficientExp);
      expect(result.player, isNull);
    });

    test('EXPが0の場合はエラー（insufficientExp）', () {
      final player = PlayerModel(
        hp: 100000,
        exp: 0,
        advisor: Advisor.lifePlanner,
      );

      final result = service.switchGuardian(player, Advisor.careerCoach);

      expect(result.isSuccess, isFalse);
      expect(result.error, GuardianSwitchError.insufficientExp);
    });

    // ── エラー系: クールダウン中 ──

    test('クールダウン中（6日前に切替済）はエラー（inCooldown）', () {
      final player = PlayerModel(
        hp: 100000,
        exp: 500,
        advisor: Advisor.lifePlanner,
        lastSwitchTimestamp:
            DateTime.now().subtract(const Duration(days: 6)),
      );

      final result = service.switchGuardian(player, Advisor.careerCoach);

      expect(result.isSuccess, isFalse);
      expect(result.error, GuardianSwitchError.inCooldown);
    });

    test('クールダウン中（1時間前に切替済）はエラー（inCooldown）', () {
      final player = PlayerModel(
        hp: 100000,
        exp: 500,
        advisor: Advisor.lifePlanner,
        lastSwitchTimestamp:
            DateTime.now().subtract(const Duration(hours: 1)),
      );

      final result = service.switchGuardian(player, Advisor.careerCoach);

      expect(result.isSuccess, isFalse);
      expect(result.error, GuardianSwitchError.inCooldown);
    });

    test('クールダウンが7日以上経過していれば切替可能', () {
      final player = PlayerModel(
        hp: 100000,
        exp: 500,
        advisor: Advisor.lifePlanner,
        lastSwitchTimestamp:
            DateTime.now().subtract(const Duration(days: 7, minutes: 1)),
      );

      final result = service.switchGuardian(player, Advisor.investmentMentor);

      expect(result.isSuccess, isTrue);
    });

    // ── エラー系: 同一守護神 ──

    test('同じ守護神への切替はエラー（alreadyContracted）', () {
      final player = PlayerModel(
        hp: 100000,
        exp: 500,
        advisor: Advisor.lifePlanner,
      );

      final result = service.switchGuardian(player, Advisor.lifePlanner);

      expect(result.isSuccess, isFalse);
      expect(result.error, GuardianSwitchError.alreadyContracted);
    });

    // ── エラー系: 守護神未契約 ──

    test('守護神未契約状態では切替不可（noActiveGuardian）', () {
      final player = PlayerModel(
        hp: 100000,
        exp: 500,
        advisor: null,
      );

      final result = service.switchGuardian(player, Advisor.lifePlanner);

      expect(result.isSuccess, isFalse);
      expect(result.error, GuardianSwitchError.noActiveGuardian);
    });

    // ── カスタム設定 ──

    test('カスタムEXPコストを設定できる', () {
      final customService = GuardianSwitchService(expCost: 300);
      final player = PlayerModel(
        hp: 100000,
        exp: 300,
        advisor: Advisor.lifePlanner,
      );

      final result = customService.switchGuardian(player, Advisor.careerCoach);

      expect(result.isSuccess, isTrue);
      expect(result.player!.exp, 0);
    });

    test('カスタムEXPコスト不足の場合はエラー', () {
      final customService = GuardianSwitchService(expCost: 300);
      final player = PlayerModel(
        hp: 100000,
        exp: 200,
        advisor: Advisor.lifePlanner,
      );

      final result = customService.switchGuardian(player, Advisor.careerCoach);

      expect(result.isSuccess, isFalse);
      expect(result.error, GuardianSwitchError.insufficientExp);
    });
  });
}
