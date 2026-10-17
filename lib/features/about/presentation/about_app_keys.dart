import 'package:flutter/material.dart';

/// 「アプリについて」画面の試練用Key。
///
/// 既存の [KozuchiAppKeys] とは別ファイル・別クラスで管理する
/// （既知の不可視禍津の回避 — 既存Keyへの追記は行わない）。
class AboutAppKeys {
  const AboutAppKeys._();

  static const Key screen = Key('about_screen');
  static const Key versionText = Key('about_versionText');
  static const Key licenseTile = Key('about_licenseTile');
  static const Key privacyTile = Key('about_privacyTile');
  static const Key contactTile = Key('about_contactTile');
  static const Key dialogCopyButton = Key('about_dialogCopyButton');
  static const Key dialogUrlText = Key('about_dialogUrlText');
}
