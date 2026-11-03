import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// raw な print / debugPrint の検出パターン（tool/print_baseline.txt と同じ規則）。
final _rawPrint = RegExp(r'\b(debugPrint|print)\s*\(');

/// baseline ファイルから閾値を読む（'#' 始まりの行は註釈として読み飛ばす）。
int _readBaseline(File file) {
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final value = int.tryParse(trimmed);
    if (value == null) {
      fail('tool/print_baseline.txt の数値行を解釈できません: "$trimmed"');
    }
    return value;
  }
  fail('tool/print_baseline.txt に閾値の数値行がありません');
}

void main() {
  test('lib 配下の raw print/debugPrint が baseline 以下に保たれている', () {
    final baselineFile = File('tool/print_baseline.txt');
    expect(
      baselineFile.existsSync(),
      isTrue,
      reason: 'tool/print_baseline.txt が見つかりません（パッケージ直下で実行すること）',
    );
    final baseline = _readBaseline(baselineFile);

    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'lib ディレクトリが見つかりません');

    final offenders = <String, int>{};
    var total = 0;
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      var count = 0;
      for (final line in entity.readAsLinesSync()) {
        count += _rawPrint.allMatches(line).length;
      }
      if (count > 0) {
        offenders[entity.path] = count;
        total += count;
      }
    }

    expect(
      total,
      lessThanOrEqualTo(baseline),
      reason: 'raw print/debugPrint が増えています。'
          'lib では AppLogger（lib/core/logging/app_logger.dart）を使うこと。\n'
          '実測値=$total / baseline=$baseline\n'
          '${offenders.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')}',
    );
  });
}
