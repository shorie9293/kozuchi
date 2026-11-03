/// ヘルプ1章分の不変データ。
///
/// [title] / [body] はチュートリアル（`KozuchiTutorialStep`）の
/// label / description をそのまま流用する。ここで文言を創作しない。
class HelpTopic {
  const HelpTopic({
    required this.id,
    required this.title,
    required this.body,
    this.relatedScreenKey,
  });

  /// 一意な識別子（チュートリアルステップ名）。
  final String id;

  /// 章題。チュートリアルの label。
  final String title;

  /// 本文。チュートリアルの description。
  final String body;

  /// 関連画面への導線を将来張るための任意キー（現状は未使用）。
  final String? relatedScreenKey;

  @override
  String toString() => 'HelpTopic($id)';
}
