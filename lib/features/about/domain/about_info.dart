/// 「アプリについて」画面の表示情報。
///
/// 全フィールドは空文字禁止（[ArgumentError]）。検証は非constコンストラクタ
/// 本体で行い、既定値は同ファイル末尾の `const kAboutInfo` を用いる。
class AboutInfo {
  const AboutInfo._(
    this.appName,
    this.version,
    this.contactEmail,
    this.privacyPolicyUrl,
    this.tagline,
  );

  /// 空文字検証つきの通常コンストラクタ（試練からも使用する）。
  factory AboutInfo({
    required String appName,
    required String version,
    required String contactEmail,
    required String privacyPolicyUrl,
    String tagline = '',
  }) {
    if (appName.isEmpty) {
      throw ArgumentError.value(appName, 'appName', '空文字は禁止');
    }
    if (version.isEmpty) {
      throw ArgumentError.value(version, 'version', '空文字は禁止');
    }
    if (contactEmail.isEmpty) {
      throw ArgumentError.value(contactEmail, 'contactEmail', '空文字は禁止');
    }
    if (privacyPolicyUrl.isEmpty) {
      throw ArgumentError.value(
        privacyPolicyUrl,
        'privacyPolicyUrl',
        '空文字は禁止',
      );
    }
    return AboutInfo._(
      appName,
      version,
      contactEmail,
      privacyPolicyUrl,
      tagline,
    );
  }

  final String appName;
  final String version;
  final String contactEmail;
  final String privacyPolicyUrl;
  final String tagline;
}

/// 「アプリについて」の既定表示情報。
///
/// version は pubspec.yaml の version と同期して保守すること
/// （test/features/about/about_version_sync_test.dart が監査する）。
const kAboutInfo = AboutInfo._(
  'コヅチ',
  '1.3.35',
  'horie.shunta@gmail.com',
  'https://yoppala.in/privacy',
  '打ち出の小槌 — 家計を守る神経済アプリ',
);
