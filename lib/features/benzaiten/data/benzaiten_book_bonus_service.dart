import 'dart:convert';
import 'dart:io';

import 'package:kozuchi/domain/models/guardian_deity.dart';

/// Benzaiten（弁財天）の蔵書追加ボーナスを処理するサービス
///
/// tsundoku-questが書き出す共有ストレージのJSONファイルを読み取り、
/// 守護神が弁財天の場合にSATORIボーナスを返す。
class BenzaitenBookBonusService {
  /// 共有ストレージのファイルパス
  final String filePath;

  /// SATORIボーナス値（弁財天の場合に付与）
  static const int benzaitenBonusSatori = 10;

  const BenzaitenBookBonusService({
    this.filePath =
        '/data/local/tmp/takamagahara_shared/tsundoku_book_events.json',
  });

  /// 共有ファイルを読み取り、条件を満たす場合にボーナス情報を返す
  ///
  /// 戻り値:
  /// - [guardianDeity] が Benzaiten でない場合 → null（ボーナスなし）
  /// - ファイルが存在しない場合 → null
  /// - ファイルが存在し、守護神が弁財天の場合 → BenzaitenBonusResult
  Future<BenzaitenBonusResult?> checkAndConsume(
    GuardianDeity guardianDeity,
  ) async {
    // 弁財天でなければボーナスなし
    if (guardianDeity != GuardianDeity.benzaiten) return null;

    final file = File(filePath);
    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      final event = json['event'] as String?;
      if (event != 'book_added') return null;

      final bookTitle = json['bookTitle'] as String? ?? '不明';
      final author = json['bookAuthor'] as String?;
      final bookAuthor = (author != null && author.isNotEmpty) ? author : null;

      // ファイルを消費（削除）して重複付与を防ぐ
      await file.delete();

      return BenzaitenBonusResult(
        bookTitle: bookTitle,
        bookAuthor: bookAuthor,
        bonusSatori: benzaitenBonusSatori,
      );
    } catch (_) {
      return null;
    }
  }
}

/// 弁財天ボーナスの結果
class BenzaitenBonusResult {
  final String bookTitle;
  final String? bookAuthor;
  final int bonusSatori;

  const BenzaitenBonusResult({
    required this.bookTitle,
    this.bookAuthor,
    required this.bonusSatori,
  });
}
