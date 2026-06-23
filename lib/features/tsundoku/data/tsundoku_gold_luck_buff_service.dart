import 'dart:convert';
import 'dart:io';

import 'package:kozuchi/domain/models/gold_luck_buff.dart';

/// tsundoku読了イベントを読み取り金運上昇バフを発動するサービス
///
/// tsundoku-quest が共有ストレージに書き出す読了イベントファイルを読み取り、
/// 金運上昇バフ（GoldLuckBuff）を生成する。
///
/// 使用パターンは CareerCoachBookBonusService と同様（ファイル読み取り→消費）。
class TsundokuGoldLuckBuffService {
  /// 共有ストレージのファイルパス
  final String filePath;

  /// バフのデフォルト倍率
  static const double defaultMultiplier = 2.0;

  /// バフのデフォルト持続時間
  static const Duration defaultDuration = Duration(minutes: 60);

  const TsundokuGoldLuckBuffService({
    this.filePath =
        '/data/local/tmp/takamagahara_shared/tsundoku_book_completed.json',
  });

  /// 共有ファイルを読み取り、読了イベントがあれば金運バフを返す
  ///
  /// 戻り値:
  /// - ファイルが存在しない場合 → null
  /// - イベントが読了でない場合 → null
  /// - 読了イベントがある場合 → [GoldLuckBuff]
  ///
  /// 読み取り成功後はファイルを削除して重複発動を防ぐ（consume パターン）。
  Future<GoldLuckBuff?> checkAndConsume() async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      final event = json['event'] as String?;
      if (event != 'book_completed') return null;

      final bookTitle = json['bookTitle'] as String?;
      final title = (bookTitle != null && bookTitle.isNotEmpty)
          ? bookTitle
          : null;

      // ファイルを消費（削除）して重複付与を防ぐ
      await file.delete();

      return GoldLuckBuff.forBookCompleted(
        bookTitle: title,
        multiplier: defaultMultiplier,
        duration: defaultDuration,
      );
    } catch (_) {
      return null;
    }
  }
}
