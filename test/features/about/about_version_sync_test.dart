import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/about/domain/about_info.dart';

/// pubspec.yaml の version と kAboutInfo.version の同期を監査する試練。
///
/// 「アプリについて」画面に表示するバージョンが公開バージョンから
/// 遅れる禍津（表示乖離）を未然に防ぐ。
void main() {
  test('kAboutInfo.version は pubspec.yaml の version と一致する', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml に version 行が見つからない');
    final pubspecVersion = match!.group(1)!;
    expect(
      kAboutInfo.version,
      pubspecVersion,
      reason: 'kAboutInfo.version を pubspec.yaml の version に合わせて更新せよ',
    );
  });
}
