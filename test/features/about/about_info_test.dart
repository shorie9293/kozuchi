import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/about/domain/about_info.dart';

void main() {
  group('AboutInfo - 空文字禁止（ArgumentError）', () {
    test('appName が空文字なら ArgumentError', () {
      expect(
        () => AboutInfo(
          appName: '',
          version: '1.0.0',
          contactEmail: 'a@example.com',
          privacyPolicyUrl: 'https://example.com/privacy',
        ),
        throwsArgumentError,
      );
    });

    test('version が空文字なら ArgumentError', () {
      expect(
        () => AboutInfo(
          appName: 'テスト',
          version: '',
          contactEmail: 'a@example.com',
          privacyPolicyUrl: 'https://example.com/privacy',
        ),
        throwsArgumentError,
      );
    });

    test('contactEmail が空文字なら ArgumentError', () {
      expect(
        () => AboutInfo(
          appName: 'テスト',
          version: '1.0.0',
          contactEmail: '',
          privacyPolicyUrl: 'https://example.com/privacy',
        ),
        throwsArgumentError,
      );
    });

    test('privacyPolicyUrl が空文字なら ArgumentError', () {
      expect(
        () => AboutInfo(
          appName: 'テスト',
          version: '1.0.0',
          contactEmail: 'a@example.com',
          privacyPolicyUrl: '',
        ),
        throwsArgumentError,
      );
    });
  });

  group('AboutInfo - 既定値 kAboutInfo', () {
    test('kAboutInfo は検証済みの既定値を持つ', () {
      expect(kAboutInfo.appName, 'コヅチ');
      expect(kAboutInfo.contactEmail, 'horie.shunta@gmail.com');
      expect(kAboutInfo.privacyPolicyUrl, 'https://www.yoppala.in/privacy');
      expect(kAboutInfo.version, isNotEmpty);
    });
  });
}
