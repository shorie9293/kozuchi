import 'dart:convert';
import 'dart:io';

import 'package:kozuchi/core/infrastructure/shared_file_store.dart';
import 'package:kozuchi/core/logging/app_logger.dart';
import 'package:kozuchi/domain/models/advisor.dart';

/// CareerCoach（弁財天）の蔵書追加ボーナスを処理するサービス
///
/// tsundoku-questが書き出す共有ストレージのJSONファイルを読み取り、
/// アドバイザーが弁財天の場合にEXPボーナスを返す。
///
/// 保存先の解決:
/// - [filePath] が非 null → そのパスを直に読む（試練・デスクトップ）
/// - [filePath] が null → [SharedFileStore.instance]（Android は SAF）
class CareerCoachBookBonusService {
  /// 共有ストレージのファイルパス。null なら [SharedFileStore.instance] を使う。
  final String? filePath;

  /// EXPボーナス値（弁財天の場合に付与）
  static const int careerCoachBonusExp = 10;

  const CareerCoachBookBonusService({this.filePath});

  /// 読取元ストア。filePath 指定時はその親ディレクトリを直に読む（後方互換）。
  ISharedFileStore get _store => filePath != null
      ? FileSharedFileStore(File(filePath!).parent)
      : SharedFileStore.instance;

  /// 共有ファイルを読み取り、条件を満たす場合にボーナス情報を返す
  ///
  /// 戻り値:
  /// - [advisor] が CareerCoach でない場合 → null（ボーナスなし）
  /// - ファイルが存在しない場合 → null
  /// - ファイルが存在し、アドバイザーが弁財天の場合 → CareerCoachBonusResult
  ///
  /// 共有ストレージ自体の失敗は [SharedStorageException] として上位へ伝える。
  Future<CareerCoachBonusResult?> checkAndConsume(
    Advisor advisor,
  ) async {
    // 弁財天でなければボーナスなし
    if (advisor != Advisor.benzaiten) return null;

    final String? content;
    try {
      content = await _store.readString(_fileName);
    } on SharedStorageException catch (e) {
      appLog.warn('[CareerCoachBookBonusService] 共有ストレージ読取失敗', e);
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
    if (event != 'book_added') return null;

    final bookTitle = json['bookTitle'] as String? ?? '不明';
    final author = json['bookAuthor'] as String?;
    final bookAuthor = (author != null && author.isNotEmpty) ? author : null;

    // ファイルを消費（削除）して重複付与を防ぐ
    try {
      await _store.delete(_fileName);
    } on SharedStorageException catch (e) {
      appLog.warn('[CareerCoachBookBonusService] 共有ストレージ削除失敗', e);
      rethrow;
    }

    return CareerCoachBonusResult(
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      bonusExp: careerCoachBonusExp,
    );
  }

  /// 契約名。共有ストレージ経由のときだけ使う。
  String get _fileName {
    if (filePath == null) return SharedCrossAppFiles.tsundokuBookEvents;
    return filePath!.split('/').last;
  }
}

/// 弁財天ボーナスの結果
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
