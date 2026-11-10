import 'dart:convert';
import 'dart:io';

import 'package:kozuchi/core/infrastructure/shared_file_store.dart';
import 'package:kozuchi/core/logging/app_logger.dart';
import 'package:kozuchi/domain/models/gold_luck_buff.dart';

/// tsundoku読了イベントを読み取り金運上昇バフを発動するサービス
///
/// tsundoku-quest が共有ストレージに書き出す読了イベントファイルを読み取り、
/// 金運上昇バフ（GoldLuckBuff）を生成する。
///
/// 使用パターンは CareerCoachBookBonusService と同様（ファイル読み取り→消費）。
///
/// 保存先の解決:
/// - [filePath] が非 null → そのパスを直に読む（試練・デスクトップ）
/// - [filePath] が null → [SharedFileStore.instance]（Android は SAF）
class TsundokuGoldLuckBuffService {
  /// 共有ストレージのファイルパス。null なら [SharedFileStore.instance] を使う。
  final String? filePath;

  /// バフのデフォルト倍率
  static const double defaultMultiplier = 2.0;

  /// バフのデフォルト持続時間
  static const Duration defaultDuration = Duration(minutes: 60);

  const TsundokuGoldLuckBuffService({this.filePath});

  /// 読取元ストア。filePath 指定時はその親ディレクトリを直に読む（後方互換）。
  ISharedFileStore get _store => filePath != null
      ? FileSharedFileStore(File(filePath!).parent)
      : SharedFileStore.instance;

  /// 共有ファイルを読み取り、読了イベントがあれば金運バフを返す
  ///
  /// 戻り値:
  /// - ファイルが存在しない場合 → null
  /// - イベントが読了でない場合 → null
  /// - 読了イベントがある場合 → [GoldLuckBuff]
  ///
  /// 読み取り成功後はファイルを削除して重複発動を防ぐ（consume パターン）。
  /// 共有ストレージ自体の失敗は [SharedStorageException] として上位へ伝える。
  Future<GoldLuckBuff?> checkAndConsume() async {
    final String? content;
    try {
      content = await _store.readString(_fileName);
    } on SharedStorageException catch (e) {
      appLog.warn('[TsundokuGoldLuckBuffService] 共有ストレージ読取失敗', e);
      rethrow;
    }
    // ファイルが無い＝未連携（正常系）
    if (content == null) return null;

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(content) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }

    final event = json['event'] as String?;
    if (event != 'book_completed') return null;

    final bookTitle = json['bookTitle'] as String?;
    final title =
        (bookTitle != null && bookTitle.isNotEmpty) ? bookTitle : null;

    // ファイルを消費（削除）して重複付与を防ぐ
    try {
      await _store.delete(_fileName);
    } on SharedStorageException catch (e) {
      appLog.warn('[TsundokuGoldLuckBuffService] 共有ストレージ削除失敗', e);
      rethrow;
    }

    return GoldLuckBuff.forBookCompleted(
      bookTitle: title,
      multiplier: defaultMultiplier,
      duration: defaultDuration,
    );
  }

  /// 契約名。共有ストレージ経由のときだけ使う。
  String get _fileName {
    if (filePath == null) return SharedCrossAppFiles.tsundokuBookCompleted;
    return filePath!.split('/').last;
  }
}
