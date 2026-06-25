import 'dart:convert';
import 'dart:io';

import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/advisor.dart';

/// 試練クエストを共有ストレージにJSONとして書き出すエクスポーター
///
/// rpg-taskアプリが読み取れるよう、共有ストレージにJSONファイルを書き出す。
/// パス: /data/local/tmp/takamagahara_shared/kozuchi_quest.json
class KozuchiQuestExporter {
  /// 出力先ファイルパス
  final String filePath;

  const KozuchiQuestExporter({
    this.filePath = '/data/local/tmp/takamagahara_shared/kozuchi_quest.json',
  });

  /// TrialQuest を共有ストレージにJSONとして書き出す
  ///
  /// [quest] がnullの場合は何もしない（ファイルを削除しない）。
  Future<void> export(TrialQuest? quest) async {
    if (quest == null) return;

    final file = File(filePath);

    // 親ディレクトリを作成（存在しない場合のみ）
    await file.parent.create(recursive: true);

    final json = {
      'title': quest.title,
      'description': quest.description,
      'suggestedOffering': quest.suggestedOffering,
      'advisor': _deityKey(quest.advisor),
      'isCompleted': quest.isCompleted,
    };

    await file.writeAsString(jsonEncode(json));
  }

  /// Advisor enum を文字列キーに変換する
  ///
  /// 例: Advisor.bishamonten → "investmentMentor"
  String _deityKey(Advisor deity) {
    return deity.name;
  }
}
