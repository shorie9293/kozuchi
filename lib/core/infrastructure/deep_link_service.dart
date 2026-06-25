/// ディープリンクの解析を担当するサービス。
///
/// URL パースロジックを分離し、単体テスト可能にする。
///
/// 対応URL形式:
///   app://weekly-report?week=YYYY-WW
class DeepLinkService {
  DeepLinkService._(); // インスタンス化不要（static utility）

  /// 週間レポートのディープリンクから week パラメータを抽出する。
  ///
  /// [uri] が `app://weekly-report?week=YYYY-WW` 形式にマッチする場合、
  /// week パラメータ（例: "2026-W25"）を返す。
  ///
  /// マッチしない形式（scheme が "app" でない、host が
  /// "weekly-report" でない、week パラメータがない）の場合は `null`。
  static String? parseWeeklyReportWeek(Uri uri) {
    if (uri.scheme != 'app' || uri.host != 'weekly-report') {
      return null;
    }
    return uri.queryParameters['week'];
  }

  /// [uri] が週間レポートのディープリンクかどうかを判定する。
  static bool isWeeklyReportLink(Uri uri) {
    return parseWeeklyReportWeek(uri) != null;
  }
}
