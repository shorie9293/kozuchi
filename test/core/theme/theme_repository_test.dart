import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/core/theme/theme_repository.dart';

void main() {
  group('ThemeRepository', () {
    late ThemeRepository repo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = const ThemeRepository();
    });

    group('loadThemeMode', () {
      test('未保存の場合は null を返す', () async {
        final result = await repo.loadThemeMode();
        expect(result, isNull);
      });

      test('light を保存した後 light を読み込める', () async {
        await repo.saveThemeMode(ThemeMode.light);
        final result = await repo.loadThemeMode();
        expect(result, equals(ThemeMode.light));
      });

      test('dark を保存した後 dark を読み込める', () async {
        await repo.saveThemeMode(ThemeMode.dark);
        final result = await repo.loadThemeMode();
        expect(result, equals(ThemeMode.dark));
      });

      test('system を保存した後 system を読み込める', () async {
        await repo.saveThemeMode(ThemeMode.system);
        final result = await repo.loadThemeMode();
        expect(result, equals(ThemeMode.system));
      });

      test('複数回上書きしても最新の値が読み込める', () async {
        await repo.saveThemeMode(ThemeMode.light);
        await repo.saveThemeMode(ThemeMode.dark);
        await repo.saveThemeMode(ThemeMode.light);
        final result = await repo.loadThemeMode();
        expect(result, equals(ThemeMode.light));
      });
    });

    group('saveThemeMode', () {
      test('保存が完了しても例外を投げない', () async {
        // saveThemeMode は void を返す。例外なく完了すれば成功。
        await repo.saveThemeMode(ThemeMode.dark);
        // load で検証
        final result = await repo.loadThemeMode();
        expect(result, equals(ThemeMode.dark));
      });

      test('全モードを保存できる', () async {
        for (final mode in ThemeMode.values) {
          await repo.saveThemeMode(mode);
          final result = await repo.loadThemeMode();
          expect(result, equals(mode));
        }
      });
    });

    group('永続化', () {
      test('アプリ再起動を模擬しても値が保持される', () async {
        // 保存
        await repo.saveThemeMode(ThemeMode.dark);

        // 同じ SharedPreferences インスタンスで値が永続化されていることを確認
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('kozuchi_theme_mode'), equals('dark'));

        // 新しいリポジトリインスタンスでも同じ値を読み込める（再起動模擬）
        final newRepo = const ThemeRepository();
        final result = await newRepo.loadThemeMode();
        expect(result, equals(ThemeMode.dark));
      });
    });
  });
}
