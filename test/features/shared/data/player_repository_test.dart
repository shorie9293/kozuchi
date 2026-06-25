import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/features/shared/data/player_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlayerRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = const PlayerRepository();
  });

  group('PlayerRepository', () {
    // ──────────────────────────────────────────────
    // 1. savePlayer → loadPlayer 往復 (正常系)
    // ──────────────────────────────────────────────
    test('savePlayer → loadPlayer 往復で同一のPlayerModelが復元されること', () async {
      final player = PlayerModel(
        hp: 50000,
        exp: 42,
        advisor: Advisor.bishamonten,
      );

      await repository.savePlayer(player);

      final loaded = await repository.loadPlayer();

      expect(loaded, isNotNull);
      expect(loaded!.hp, 50000);
      expect(loaded.exp, 42);
      expect(loaded.advisor, Advisor.bishamonten);
    });

    // ──────────────────────────────────────────────
    // 2. loadPlayer (保存なし)
    // ──────────────────────────────────────────────
    test('loadPlayer: 未保存時はnullが返ること', () async {
      final result = await repository.loadPlayer();
      expect(result, isNull);
    });

    // ──────────────────────────────────────────────
    // 3. loadPlayer (破損データ)
    // ──────────────────────────────────────────────
    test('loadPlayer: 不正なJSON文字列ではnullが返ること', () async {
      // SharedPreferencesに直接破損JSONを書き込む
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kozuchi_player_state', 'これはJSONではない破損データ{{{');

      final result = await repository.loadPlayer();
      expect(result, isNull);
    });

    // ──────────────────────────────────────────────
    // 4. saveQuest → loadQuest 往復 (正常系)
    // ──────────────────────────────────────────────
    test('saveQuest → loadQuest 往復で同一のTrialQuestが復元されること', () async {
      final quest = TrialQuest(
        title: 'コンビニ誘惑を断て',
        description: '3日間コンビニで無駄遣いしない',
        suggestedOffering: 500,
        advisor: Advisor.daikokuten,
        offeringAmount: 300,
        offeringPurpose: '食費節約',
        offeringNote: 'おにぎりだけ買った',
        reflection: 'よく我慢した',
        review: '素晴らしい',
        receiptImagePath: '/path/to/receipt.jpg',
      );

      await repository.saveQuest(quest);

      final loaded = await repository.loadQuest();

      expect(loaded, isNotNull);
      expect(loaded!.title, 'コンビニ誘惑を断て');
      expect(loaded.description, '3日間コンビニで無駄遣いしない');
      expect(loaded.suggestedOffering, 500);
      expect(loaded.advisor, Advisor.daikokuten);
      expect(loaded.offeringAmount, 300);
      expect(loaded.offeringPurpose, '食費節約');
      expect(loaded.offeringNote, 'おにぎりだけ買った');
      expect(loaded.reflection, 'よく我慢した');
      expect(loaded.review, '素晴らしい');
      expect(loaded.receiptImagePath, '/path/to/receipt.jpg');
    });

    // ──────────────────────────────────────────────
    // 5. loadQuest (保存なし)
    // ──────────────────────────────────────────────
    test('loadQuest: 未保存時はnullが返ること', () async {
      final result = await repository.loadQuest();
      expect(result, isNull);
    });

    // ──────────────────────────────────────────────
    // 6. clearAll: 全削除後に両方null
    // ──────────────────────────────────────────────
    test('clearAll: savePlayer + saveQuest → clearAll → 両方null', () async {
      final player = PlayerModel(hp: 99999, exp: 10);
      final quest = TrialQuest(
        title: '試練',
        description: 'テスト',
        suggestedOffering: 100,
        advisor: Advisor.kichijoten,
      );

      await repository.savePlayer(player);
      await repository.saveQuest(quest);

      // 保存直後は読み出せることを確認
      expect(await repository.loadPlayer(), isNotNull);
      expect(await repository.loadQuest(), isNotNull);

      await repository.clearAll();

      // clearAll後は両方null
      expect(await repository.loadPlayer(), isNull);
      expect(await repository.loadQuest(), isNull);
    });

    // ──────────────────────────────────────────────
    // 7. キー分離確認: savePlayer → saveQuest → loadPlayerでquestデータが混入しない
    // ──────────────────────────────────────────────
    test('savePlayer → saveQuest → loadPlayerでquestデータが混入しないこと', () async {
      final player = PlayerModel(
        hp: 77777,
        exp: 7,
        advisor: Advisor.benzaiten,
      );

      final quest = TrialQuest(
        title: '混入テスト用クエスト',
        description: 'このデータがPlayerに混ざってはいけない',
        suggestedOffering: 999,
        advisor: Advisor.bishamonten,
      );

      await repository.savePlayer(player);
      await repository.saveQuest(quest);

      final loaded = await repository.loadPlayer();

      // PlayerModelとして正しく復元され、questのデータは混入していない
      expect(loaded, isNotNull);
      expect(loaded!.hp, 77777);
      expect(loaded.exp, 7);
      expect(loaded.advisor, Advisor.benzaiten);

      // quest側も正しく保存されていることを確認
      final loadedQuest = await repository.loadQuest();
      expect(loadedQuest, isNotNull);
      expect(loadedQuest!.title, '混入テスト用クエスト');
    });
  });
}
