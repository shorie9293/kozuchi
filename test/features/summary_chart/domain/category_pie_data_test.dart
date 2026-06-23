import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/summary_chart/domain/category_pie_data.dart';

void main() {
  group('CategoryPieData', () {
    test('正しく生成できる', () {
      const data = CategoryPieData(
        categoryName: '食費',
        amount: 30000,
        percentage: 40.0,
      );
      expect(data.categoryName, '食費');
      expect(data.amount, 30000);
      expect(data.percentage, 40.0);
    });

    test('等価比較が正しく動作する', () {
      const a = CategoryPieData(categoryName: '食費', amount: 1000, percentage: 25);
      const b = CategoryPieData(categoryName: '食費', amount: 1000, percentage: 25);
      expect(a, equals(b));
    });

    test('異なる値は等価でない', () {
      const a = CategoryPieData(categoryName: '食費', amount: 1000, percentage: 25);
      const b = CategoryPieData(categoryName: '交通費', amount: 500, percentage: 12.5);
      expect(a, isNot(equals(b)));
    });

    test('hashCode が等価なオブジェクトで一致する', () {
      const a = CategoryPieData(categoryName: '食費', amount: 1000, percentage: 25);
      const b = CategoryPieData(categoryName: '食費', amount: 1000, percentage: 25);
      expect(a.hashCode, equals(b.hashCode));
    });

    group('normalize', () {
      test('合計100の場合はそのまま返す', () {
        final items = [
          const CategoryPieData(categoryName: 'A', amount: 500, percentage: 60),
          const CategoryPieData(categoryName: 'B', amount: 500, percentage: 40),
        ];
        final normalized = CategoryPieData.normalize(items);
        expect(normalized[0].percentage, 60);
        expect(normalized[1].percentage, 40);
      });

      test('合計が100でない場合は正規化する', () {
        final items = [
          const CategoryPieData(categoryName: 'A', amount: 300, percentage: 30),
          const CategoryPieData(categoryName: 'B', amount: 200, percentage: 20),
        ];
        final normalized = CategoryPieData.normalize(items);
        // 30+20=50 → A:30/50*100=60, B:20/50*100=40
        expect(normalized[0].percentage, 60);
        expect(normalized[1].percentage, 40);
      });

      test('合計が0の場合はそのまま返す', () {
        final items = [
          const CategoryPieData(categoryName: 'A', amount: 0, percentage: 0),
          const CategoryPieData(categoryName: 'B', amount: 0, percentage: 0),
        ];
        final normalized = CategoryPieData.normalize(items);
        expect(normalized[0].percentage, 0);
        expect(normalized[1].percentage, 0);
      });

      test('単一項目でも正しく動作する', () {
        final items = [
          const CategoryPieData(categoryName: 'A', amount: 1000, percentage: 100),
        ];
        final normalized = CategoryPieData.normalize(items);
        expect(normalized[0].percentage, 100);
      });
    });

    test('toString が情報を含む', () {
      const data = CategoryPieData(categoryName: '食費', amount: 30000, percentage: 40.0);
      expect(data.toString(), contains('食費'));
      expect(data.toString(), contains('30000'));
      expect(data.toString(), contains('40'));
    });
  });
}
