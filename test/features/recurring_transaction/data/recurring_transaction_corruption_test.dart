import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/recurring_transaction/data/recurring_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

/// 破損した保存データを「0件」と混同せず、上書きで恒久破壊しないことの試練。
///
/// 旧実装は `loadDefinitions()` が破損を無音で `[]` に落とし、
/// `addDefinition()` がその空リストをそのまま保存していた＝
/// **1件追加した瞬間に既存の全定義が消える**。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const defsKey = 'kozuchi_recurring_defs';
  const lastGenKey = 'kozuchi_recurring_last_generated';

  late RecurringTransactionRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = const RecurringTransactionRepository();
  });

  RecurringTransaction makeDef({String id = 'rent', int amount = -85000}) {
    return RecurringTransaction(
      id: id,
      purpose: '家賃',
      category: '住居費',
      amount: amount,
      frequency: RecurringFrequency.monthly,
      dayOfMonth: 5,
      startDate: DateTime(2026, 1, 5),
    );
  }

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  group('破損した定義一覧', () {
    test('壊れたJSONでも loadDefinitions は例外を投げず空を返す（後方互換）', () async {
      SharedPreferences.setMockInitialValues({defsKey: '{"broken":'});

      final defs = await repository.loadDefinitions();

      expect(defs, isEmpty);
    });

    test('壊れたJSONは loadDefinitionsResult で verified=false と理由を返す', () async {
      SharedPreferences.setMockInitialValues({defsKey: '{"broken":'});

      final result = await repository.loadDefinitionsResult();

      expect(result.verified, isFalse);
      expect(result.definitions, isEmpty);
      expect(result.errorMessage, isNotNull);
    });

    test('未保存は verified=true の空（破損と区別する）', () async {
      final result = await repository.loadDefinitionsResult();

      expect(result.verified, isTrue);
      expect(result.definitions, isEmpty);
    });

    test('破損状態の addDefinition は上書きせず ok=false を返す', () async {
      const corrupt = '[{"id":"rent","amount":"文字列"}]';
      SharedPreferences.setMockInitialValues({defsKey: corrupt});

      final result = await repository.addDefinition(makeDef(id: 'new'));

      expect(result.ok, isFalse);
      expect(result.errorMessage, isNotNull);
      // 元の文字列が1バイトも変わっていないこと（恒久破壊の防止）
      expect((await prefs()).getString(defsKey), corrupt);
      // 壊れたJSONは依然として読めない（＝静かに消えていない）
      expect((await repository.loadDefinitionsResult()).verified, isFalse);
    });

    test('破損状態の removeDefinition も上書きしない', () async {
      const corrupt = 'not json';
      SharedPreferences.setMockInitialValues({defsKey: corrupt});

      final result = await repository.removeDefinition('rent');

      expect(result.ok, isFalse);
      expect((await prefs()).getString(defsKey), corrupt);
    });

    test('正常時は addDefinition が ok=true・往復する（既存挙動の維持）', () async {
      final result = await repository.addDefinition(makeDef());

      expect(result.ok, isTrue);
      final defs = await repository.loadDefinitions();
      expect(defs, hasLength(1));
      expect(defs[0].id, 'rent');
    });

    test('正常時は removeDefinition が ok=true・削除される', () async {
      await repository.addDefinition(makeDef());
      await repository.addDefinition(makeDef(id: 'other'));

      final result = await repository.removeDefinition('rent');

      expect(result.ok, isTrue);
      final defs = await repository.loadDefinitions();
      expect(defs, hasLength(1));
      expect(defs[0].id, 'other');
    });

    test('要素の一部破損でも読めた分は返し、保存は止める', () async {
      SharedPreferences.setMockInitialValues({
        defsKey: '[{"id":"rent","purpose":"家賃","category":"住居費",'
            '"amount":-85000,"frequency":"monthly","dayOfMonth":5,'
            '"startDate":"2026-01-05T00:00:00.000"}, "壊れた要素"]',
      });

      final result = await repository.loadDefinitionsResult();

      expect(result.verified, isFalse);
      expect(result.definitions, hasLength(1));
      expect(result.skippedCount, 1);

      final save = await repository.addDefinition(makeDef(id: 'new'));
      expect(save.ok, isFalse);
    });
  });

  group('破損データの退避（archiveCorruptData）', () {
    test('破損した定義を退避し、以後は新規保存できる', () async {
      const corrupt = '{"broken":';
      SharedPreferences.setMockInitialValues({defsKey: corrupt});

      final archived = await repository.archiveCorruptData();

      expect(archived, isTrue);
      final p = await prefs();
      expect(p.getString(defsKey), isNull);
      // 元の文字列が退避キーに残っている（復旧の余地を消さない）
      final backupKeys =
          p.getKeys().where((k) => k.startsWith('kozuchi_recurring_backup_'));
      expect(backupKeys, isNotEmpty);
      expect(
        backupKeys.map((k) => p.getString(k)),
        contains(corrupt),
      );
      // 退避後は保存が通る
      final save = await repository.addDefinition(makeDef(id: 'new'));
      expect(save.ok, isTrue);
      final defs = await repository.loadDefinitions();
      expect(defs, hasLength(1));
      expect(defs[0].id, 'new');
    });

    test('正常データでは退避しない（何も壊さない）', () async {
      await repository.addDefinition(makeDef());

      final archived = await repository.archiveCorruptData();

      expect(archived, isFalse);
      final defs = await repository.loadDefinitions();
      expect(defs, hasLength(1));
      expect(defs[0].id, 'rent');
    });

    test('破損した最終生成日時も同時に退避する', () async {
      SharedPreferences.setMockInitialValues({
        defsKey: '{"broken":',
        lastGenKey: 'also broken',
      });

      final archived = await repository.archiveCorruptData();

      expect(archived, isTrue);
      final p = await prefs();
      expect(p.getString(defsKey), isNull);
      expect(p.getString(lastGenKey), isNull);
      expect(
        p.getKeys().where((k) => k.startsWith('kozuchi_recurring_backup_')),
        hasLength(2),
      );
    });
  });

  group('破損した最終生成日時', () {
    test('壊れたMapでも loadLastGenerated は null を返す（後方互換）', () async {
      SharedPreferences.setMockInitialValues({lastGenKey: 'oops'});

      expect(await repository.loadLastGenerated('rent'), isNull);
    });

    test('壊れたMapは loadLastGeneratedResult で verified=false', () async {
      SharedPreferences.setMockInitialValues({lastGenKey: 'oops'});

      final result = await repository.loadLastGeneratedResult();

      expect(result.verified, isFalse);
      expect(result.values, isEmpty);
    });

    test('破損状態の saveLastGenerated は他定義の記録を消さず保存を止める', () async {
      const corrupt = '{"rent":"壊れた日付"}';
      SharedPreferences.setMockInitialValues({lastGenKey: corrupt});

      final result = await repository.saveLastGenerated('new', DateTime(2026, 6, 1));

      expect(result.ok, isFalse);
      expect((await prefs()).getString(lastGenKey), corrupt);
    });

    test('正常時は saveLastGenerated が ok=true・既存の他定義を保つ', () async {
      await repository.saveLastGenerated('rent', DateTime(2026, 6, 10));

      final result = await repository.saveLastGenerated('other', DateTime(2026, 1, 1));

      expect(result.ok, isTrue);
      expect(await repository.loadLastGenerated('rent'), DateTime(2026, 6, 10));
      expect(await repository.loadLastGenerated('other'), DateTime(2026, 1, 1));
    });
  });
}
