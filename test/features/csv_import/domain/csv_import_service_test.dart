import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/csv_import/domain/csv_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CsvImportService', () {
    test('CSVをパースしてリポジトリに永続化する', () async {
      const service = CsvImportService();

      final csv = 'date,desc,amount\n'
          '2026-06-01,給与,+300000\n'
          '2026-06-02,食費,-1200\n';

      final result = await service.importCsv(csv);

      expect(result.importedCount, 2);
      expect(result.skippedCount, 0);
      expect(result.errorMessages, isEmpty);

      final repo = const LocalTransactionRepository();
      final saved = await repo.loadAll();
      expect(saved, hasLength(2));
      expect(saved[0].amount, 300000);
      expect(saved[1].amount, -1200);
    });

    test('不正行はスキップされ skippedCount に反映される', () async {
      const service = CsvImportService();

      final csv = 'date,desc,amount\n'
          '2026-06-01,有効,100\n'
          '完全に不正な行\n';

      final result = await service.importCsv(csv);

      expect(result.importedCount, 1);
      expect(result.skippedCount, 1);
      expect(result.errorMessages, isNotEmpty);
    });

    test('空CSVは何もインポートしない', () async {
      const service = CsvImportService();
      final result = await service.importCsv('');

      expect(result.importedCount, 0);
      expect(result.skippedCount, 0);
    });

    test('複数回インポートすると取引が蓄積される', () async {
      const service = CsvImportService();
      await service.importCsv('date,desc,amount\n2026-06-01,A,+100\n');
      await service.importCsv('date,desc,amount\n2026-06-02,B,-50\n');

      final repo = const LocalTransactionRepository();
      final saved = await repo.loadAll();
      expect(saved, hasLength(2));
    });
  });
}
