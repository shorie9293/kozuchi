/// 復帰時の再施錠（リロード）判定を担う純粋ロジック。
///
/// バックグラウンドから復帰した際にロックを掛け直すか否かを、
/// バックグラウンド開始時刻・現在時刻・猶予時間のみで判定する。
/// 時刻は全て引数注入（TZ 非依存）。
class LockReloadPolicy {
  LockReloadPolicy._();

  /// 設定画面に出す猶予の選択肢（秒）。
  static const List<int> graceOptionsSeconds = [0, 30, 60, 300];

  /// 猶予秒数の表示ラベル。
  static String graceLabel(int seconds) {
    switch (seconds) {
      case 0:
        return '即時';
      case 30:
        return '30秒';
      case 60:
        return '1分';
      case 300:
        return '5分';
      default:
        // 秒は Dart の識別子文字のため、波括弧を外すと変数名として解釈される。
        // ignore: unnecessary_brace_in_string_interps
        return '${seconds}秒';
    }
  }

  /// 復帰時に再施錠すべきか。
  ///
  /// - バックグラウンド開始時刻が無い → 施錠する
  /// - 猶予が 0 以下 → 施錠する
  /// - 猶予内 → 施錠しない
  /// - 猶予超過 → 施錠する
  /// - 時計巻き戻り（now が開始時刻より前）→ 施錠する
  static bool shouldRelock(
    DateTime? backgroundedAt,
    DateTime now,
    Duration grace,
  ) {
    if (backgroundedAt == null) return true;
    if (grace <= Duration.zero) return true;
    if (now.isBefore(backgroundedAt)) return true;
    return now.difference(backgroundedAt) >= grace;
  }
}
