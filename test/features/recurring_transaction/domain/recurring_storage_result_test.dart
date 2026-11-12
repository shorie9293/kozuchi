import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_storage_result.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

/// 保存データの読み取り結果型（純粋層）の試練。
///
/// 破損JSONは日常的に存在する（端末の書込中断・旧版の形式変更・手編集）。
/// 読み取り結果型は「読めなかった」を「0件」と区別し、絶対に例外を投げない。
void main() {
  String defJson({
    String id = 'rent',
    String purpose = '家賃',
    int amount = -85000,
    String frequency = 'monthly',
  }) {
    return '{"id":"$id","purpose":"$purpose","category":"住居費",'
        '"amount":$amount,"frequency":"$frequency","dayOfWeek":1,'
        '"dayOfMonth":5,"startDate":"2026-01-05T00:00:00.000","isActive":true}';
  }

  group('RecurringDefinitionsLoadResult.parse', () {
    test('未保存（null）は「正常な空」として扱う', () {
      final result = RecurringDefinitionsLoadResult.parse(null);

      expect(result.verified, isTrue);
      expect(result.definitions, isEmpty);
      expect(result.errorMessage, isNull);
      expect(result.skippedCount, 0);
    });

    test('正常なJSONは全件復元し verified=true', () {
      final result = RecurringDefinitionsLoadResult.parse(
        '[${defJson()},${defJson(id: 'salary', purpose: '給与', amount: 300000)}]',
      );

      expect(result.verified, isTrue);
      expect(result.definitions, hasLength(2));
      expect(result.definitions[0].id, 'rent');
      expect(result.definitions[1].amount, 300000);
      expect(result.errorMessage, isNull);
    });

    test('空配列は「正常な空」', () {
      final result = RecurringDefinitionsLoadResult.parse('[]');

      expect(result.verified, isTrue);
      expect(result.definitions, isEmpty);
    });

    test('壊れたJSONは例外を投げず verified=false を返す', () {
      late RecurringDefinitionsLoadResult result;
      expect(() {
        result = RecurringDefinitionsLoadResult.parse('{"broken":');
      }, returnsNormally);

      expect(result.verified, isFalse);
      expect(result.definitions, isEmpty);
      expect(result.errorMessage, isNotNull);
      expect(result.errorMessage, contains('壊れ'));
    });

    test('配列でないJSON（Map）は verified=false', () {
      final result = RecurringDefinitionsLoadResult.parse('{"a":1}');

      expect(result.verified, isFalse);
      expect(result.errorMessage, contains('形式'));
    });

    test('文字列JSONも verified=false（例外にしない）', () {
      expect(
        () => RecurringDefinitionsLoadResult.parse('"just a string"'),
        returnsNormally,
      );
      final result = RecurringDefinitionsLoadResult.parse('"just a string"');
      expect(result.verified, isFalse);
    });

    test('要素の一部が壊れていても、読めた分は残し verified=false', () {
      final result = RecurringDefinitionsLoadResult.parse(
        '[${defJson()}, 42, "nope", {"amount":"文字列で型不正"}]',
      );

      expect(result.verified, isFalse);
      expect(result.definitions, hasLength(1));
      expect(result.definitions[0].id, 'rent');
      expect(result.skippedCount, 3);
      expect(result.errorMessage, isNotNull);
    });

    test('壊れた要素だけの配列は definitions 空・verified=false', () {
      final result = RecurringDefinitionsLoadResult.parse('[1,2,3]');

      expect(result.verified, isFalse);
      expect(result.definitions, isEmpty);
      expect(result.skippedCount, 3);
    });

    test('空文字は verified=false（未保存の null とは区別する）', () {
      final result = RecurringDefinitionsLoadResult.parse('');

      expect(result.verified, isFalse);
      expect(result.definitions, isEmpty);
    });

    test('isCorrupt / isEmpty の補助判定', () {
      final corrupt = RecurringDefinitionsLoadResult.parse('{');
      final healthyEmpty = RecurringDefinitionsLoadResult.parse(null);

      expect(corrupt.isCorrupt, isTrue);
      expect(healthyEmpty.isCorrupt, isFalse);
      expect(healthyEmpty.isEmpty, isTrue);
    });

    test('definitions は呼出側で変更できない（不変ビュー）', () {
      final result = RecurringDefinitionsLoadResult.parse('[${defJson()}]');

      expect(
        () => result.definitions.add(
          RecurringTransaction(
            id: 'x',
            purpose: 'x',
            category: 'x',
            amount: 1,
            frequency: RecurringFrequency.daily,
            startDate: DateTime(2026, 1, 1),
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('RecurringLastGeneratedResult.parse', () {
    test('未保存（null）は正常な空', () {
      final result = RecurringLastGeneratedResult.parse(null);

      expect(result.verified, isTrue);
      expect(result.values, isEmpty);
      expect(result.valueFor('rent'), isNull);
    });

    test('正常なMapは復元する', () {
      final result = RecurringLastGeneratedResult.parse(
        '{"rent":"2026-06-10T12:00:00.000","other":"2026-01-01T00:00:00.000"}',
      );

      expect(result.verified, isTrue);
      expect(result.valueFor('rent'), DateTime(2026, 6, 10, 12));
      expect(result.valueFor('other'), DateTime(2026, 1, 1));
    });

    test('壊れたJSONは verified=false・例外なし', () {
      late RecurringLastGeneratedResult result;
      expect(() {
        result = RecurringLastGeneratedResult.parse('not json at all');
      }, returnsNormally);

      expect(result.verified, isFalse);
      expect(result.values, isEmpty);
      expect(result.errorMessage, isNotNull);
    });

    test('MapでないJSONは verified=false', () {
      final result = RecurringLastGeneratedResult.parse('[1,2]');

      expect(result.verified, isFalse);
    });

    test('日付として読めない値は読み飛ばし verified=false・他は残す', () {
      final result = RecurringLastGeneratedResult.parse(
        '{"rent":"2026-06-10T12:00:00.000","other":"壊れた日付"}',
      );

      expect(result.verified, isFalse);
      expect(result.valueFor('rent'), DateTime(2026, 6, 10, 12));
      expect(result.valueFor('other'), isNull);
      expect(result.skippedCount, 1);
    });

    test('値が文字列でない場合も読み飛ばす', () {
      final result = RecurringLastGeneratedResult.parse('{"rent":12345}');

      expect(result.verified, isFalse);
      expect(result.valueFor('rent'), isNull);
    });
  });

  group('RecurringSaveResult', () {
    test('success は ok=true・理由なし', () {
      expect(RecurringSaveResult.success.ok, isTrue);
      expect(RecurringSaveResult.success.errorMessage, isNull);
    });

    test('blocked は ok=false・理由を持つ', () {
      final blocked = RecurringSaveResult.blocked();

      expect(blocked.ok, isFalse);
      expect(blocked.errorMessage, isNotNull);
      expect(blocked.errorMessage, contains('破損'));
    });

    test('blocked は任意の理由を保持する', () {
      final blocked = RecurringSaveResult.blocked('独自の理由');

      expect(blocked.ok, isFalse);
      expect(blocked.errorMessage, '独自の理由');
    });
  });
}
