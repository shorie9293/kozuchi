import 'dart:convert';
import 'dart:io';

import 'package:kozuchi/domain/models/advisor.dart';

/// CareerCoach（キャリアコーチ）の蔵書追加ボーナスを処理するサービス
///
/// tsundoku-questが書き出す共有ストレージのJSONファイルを読み取り、
/// アドバイザーがキャリアコーチの場合にEXPボーナスを返す。
class CareerCoachBookBonusService {
  /// 共有ストレージのファイルパス
  final String filePath;

  /// EXPボーナス値（キャリアコーチの場合に付与）
  static const int careerCoachBonusExp = 10;

  const CareerCoachBookBonusService({
    this.filePath =
        '/data/local/tmp/takamagahara_shared/tsundoku_book_events.json',
  });

  /// 共有ファイルを読み取り、条件を満たす場合にボーナス情報を返す
  ///
  /// 戻り値:
  /// - [advisor] が CareerCoach でない場合 → null（ボーナスなし）
  /// - ファイルが存在しない場合 → null
  /// - ファイルが存在し、アドバイザーがキャリアコーチの場合 → CareerCoachBonusResult
  Future<CareerCoachBonusResult?> checkAndConsume(
    Advisor advisor,
  ) async {
    // キャリアコーチでなければボーナスなし
    if (advisor != Advisor.careerCoach) return null;

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

      return CareerCoachBonusResult(
        bookTitle: bookTitle,
        bookAuthor: bookAuthor,
        bonusExp: careerCoachBonusExp,
      );
    } catch (_) {
      return null;
    }
  }
}

/// キャリアコーチボーナスの結果
class CareerCoachBonusResult {
  final String bookTitle;
  final String? bookAuthor;
  final int bonusExp;

  const CareerCoachBonusResult({
    required this.bookTitle,
    this.bookAuthor,
    required this.bonusExp,
  });
}
