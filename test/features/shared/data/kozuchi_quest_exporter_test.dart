import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/guardian_deity.dart';
import 'package:kozuchi/features/shared/data/kozuchi_quest_exporter.dart';

void main() {
  late Directory tempDir;
  late String filePath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kozuchi_test_');
    filePath = '${tempDir.path}/kozuchi_quest.json';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('KozuchiQuestExporter', () {
    test('正常にJSONファイルが書き出されること', () async {
      final quest = TrialQuest(
        title: 'コンビニ誘惑を断て',
        description: '3日間コンビニで無駄遣いせず、必要なものだけ買う',
        suggestedOffering: 500,
        guardianDeity: GuardianDeity.bishamonten,
      );

      final exporter = KozuchiQuestExporter(filePath: filePath);
      await exporter.export(quest);

      expect(File(filePath).existsSync(), isTrue);

      final content = await File(filePath).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      expect(json['title'], 'コンビニ誘惑を断て');
      expect(json['description'], '3日間コンビニで無駄遣いせず、必要なものだけ買う');
      expect(json['suggestedOffering'], 500);
      expect(json['guardianDeity'], 'bishamonten');
      expect(json['isCompleted'], false);
    });

    test('guardianDeityが正しい文字列キーで出力されること（全4種）', () async {
      final deities = {
        GuardianDeity.daikokuten: 'daikokuten',
        GuardianDeity.benzaiten: 'benzaiten',
        GuardianDeity.bishamonten: 'bishamonten',
        GuardianDeity.kisshoten: 'kisshoten',
      };

      for (final entry in deities.entries) {
        final quest = TrialQuest(
          title: 'テスト',
          description: 'テスト',
          suggestedOffering: 100,
          guardianDeity: entry.key,
        );

        final filePath2 = '${tempDir.path}/${entry.value}.json';
        final exporter = KozuchiQuestExporter(filePath: filePath2);
        await exporter.export(quest);

        final content = await File(filePath2).readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        expect(json['guardianDeity'], entry.value);
      }
    });

    test('ディレクトリが存在しない場合は作成されること', () async {
      final deepPath = '${tempDir.path}/sub/deep/nested/kozuchi_quest.json';
      final quest = TrialQuest(
        title: '深いパス',
        description: 'テスト',
        suggestedOffering: 100,
        guardianDeity: GuardianDeity.daikokuten,
      );

      final exporter = KozuchiQuestExporter(filePath: deepPath);
      await exporter.export(quest);

      expect(File(deepPath).existsSync(), isTrue);

      final content = await File(deepPath).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      expect(json['title'], '深いパス');
    });

    test('isCompletedが正しく判定されること（未完了）', () async {
      final quest = TrialQuest(
        title: 'テスト',
        description: '未完了の試練',
        suggestedOffering: 100,
        guardianDeity: GuardianDeity.daikokuten,
      );

      final exporter = KozuchiQuestExporter(filePath: filePath);
      await exporter.export(quest);

      final content = await File(filePath).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      expect(json['isCompleted'], false);
    });

    test('isCompletedが正しく判定されること（完了）', () async {
      final quest = TrialQuest(
        title: 'テスト',
        description: '完了した試練',
        suggestedOffering: 100,
        guardianDeity: GuardianDeity.daikokuten,
      ).recordOffering(amount: 500, purpose: '寄付')
       .recordReflection('よく頑張った');

      expect(quest.isCompleted, isTrue);

      final exporter = KozuchiQuestExporter(filePath: filePath);
      await exporter.export(quest);

      final content = await File(filePath).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      expect(json['isCompleted'], true);
    });

    test('TrialQuestがnullの場合は何もしないこと', () async {
      final exporter = KozuchiQuestExporter(filePath: filePath);
      await exporter.export(null);

      expect(File(filePath).existsSync(), isFalse);
    });
  });
}
