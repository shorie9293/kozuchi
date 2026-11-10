import 'dart:convert';
import 'dart:io';

import 'package:kozuchi/core/infrastructure/shared_file_store.dart';
import 'package:kozuchi/core/logging/app_logger.dart';
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';

/// 試練クエストを共有ストレージにJSONとして書き出すエクスポーター
///
/// rpg-taskアプリが読み取れるよう、共有ストレージにJSONファイルを書き出す。
/// 契約名: [SharedCrossAppFiles.kozuchiQuest]
///
/// 保存先の解決:
/// - [filePath] が非 null → そのパスへ直に書く（試練・デスクトップ）
/// - [filePath] が null → [SharedFileStore.instance]（Android は SAF）
class KozuchiQuestExporter {
  /// 出力先ファイルパス。null なら [SharedFileStore.instance] を使う。
  final String? filePath;

  const KozuchiQuestExporter({this.filePath});

  /// 書出先ストア。filePath 指定時はその親ディレクトリへ直に書く（後方互換）。
  ISharedFileStore get _store => filePath != null
      ? FileSharedFileStore(File(filePath!).parent)
      : SharedFileStore.instance;

  /// 出力ファイル名。共有ストレージ経由のときは契約名を使う。
  String get _fileName {
    if (filePath == null) return SharedCrossAppFiles.kozuchiQuest;
    return filePath!.split('/').last;
  }

  /// TrialQuest を共有ストレージにJSONとして書き出す
  ///
  /// [quest] がnullの場合は何もしない（ファイルを削除しない）。
  /// 書出の失敗は [SharedStorageException] として上位へ伝える。
  Future<void> export(TrialQuest? quest) async {
    if (quest == null) return;

    final json = {
      'title': quest.title,
      'description': quest.description,
      'suggestedOffering': quest.suggestedOffering,
      'advisor': _deityKey(quest.advisor),
      'isCompleted': quest.isCompleted,
    };

    try {
      await _store.writeString(_fileName, jsonEncode(json));
    } on SharedStorageException catch (e) {
      appLog.warn('[KozuchiQuestExporter] 共有ストレージ書出失敗', e);
      rethrow;
    }
  }

  /// Advisor enum を文字列キーに変換する
  ///
  /// 例: Advisor.bishamonten → "bishamonten"
  String _deityKey(Advisor deity) {
    return deity.name;
  }
}
