import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';

/// 取引日時の往復契約の試練。
///
/// クラウド同期は `date.toUtc().toIso8601String()`（Z 付き）で送り、
/// ローカル保存は `date.toIso8601String()`（Z 無し）で書く。
/// 復元側が `DateTime.parse` の戻り値をそのまま保持すると UTC 種別のまま
/// 残り、`.year/.month/.day` の直読みが1日ずれる。
/// 契約: [ExpenseEntry.fromJson] は**必ずローカル瞬間**を返す。
void main() {
  group('ExpenseEntry.fromJson の日時契約', () {
    test('Z 付き（クラウド由来）はローカル瞬間へ正規化される', () {
      final cloudIso = DateTime(2026, 11, 13, 8, 30).toUtc().toIso8601String();
      final entry = ExpenseEntry.fromJson({
        'id': 'e1',
        'amount': 500,
        'category': '食費',
        'date': cloudIso,
      });
      expect(entry.date.isUtc, isFalse,
          reason: 'UTC 種別のまま保持すると .day 直読みが前日になる');
      expect(entry.date.isAtSameMomentAs(DateTime.parse(cloudIso)), isTrue);
      expect(entry.date.day, 13);
      expect(entry.date.hour, 8);
    });

    test('Z 無し（既存ローカル保存）は壁時計を変えない', () {
      final entry = ExpenseEntry.fromJson({
        'id': 'e1',
        'amount': 500,
        'category': '食費',
        'date': '2026-06-22T14:30:00.000',
      });
      expect(entry.date, DateTime(2026, 6, 22, 14, 30));
      expect(entry.date.isUtc, isFalse);
    });

    test('ローカル往復は不変（既存データを壊さない）', () {
      final original = ExpenseEntry(
        id: 'e1',
        amount: 2500,
        category: '交通費',
        date: DateTime(2026, 6, 22, 14, 30),
        note: '電車',
      );
      final restored = ExpenseEntry.fromJson(original.toJson());
      expect(restored.date, original.date);
      expect(restored.date.isUtc, isFalse);
      expect(restored.toJson()['date'], original.toJson()['date']);
    });

    test('クラウド往復（ローカル→UTC→復元）でローカル暦の日付が動かない', () {
      for (final local in [
        DateTime(2026, 11, 1, 0, 5), // 月初 00:05
        DateTime(2026, 11, 13, 8, 59), // 早朝 08:59
        DateTime(2026, 12, 31, 23, 59), // 年末
      ]) {
        final cloudIso = local.toUtc().toIso8601String();
        final restored = ExpenseEntry.fromJson({
          'id': 'e1',
          'amount': 100,
          'category': 'その他',
          'date': cloudIso,
        });
        expect(restored.date.year, local.year, reason: '$local の年');
        expect(restored.date.month, local.month, reason: '$local の月');
        expect(restored.date.day, local.day, reason: '$local の日');
      }
    });
  });

  group('ExpenseEntry.tryFromJson', () {
    test('壊れた日付文字列では throw せず null を返す', () {
      expect(
        ExpenseEntry.tryFromJson({
          'id': 'e1',
          'amount': 100,
          'category': '食費',
          'date': 'not-a-date',
        }),
        isNull,
      );
      expect(
        ExpenseEntry.tryFromJson({
          'id': 'e1',
          'amount': 100,
          'category': '食費',
          'date': null,
        }),
        isNull,
      );
    });

    test('壊れた amount でも throw しない', () {
      expect(
        ExpenseEntry.tryFromJson({
          'id': 'e1',
          'amount': '500',
          'category': '食費',
          'date': '2026-11-13T08:30:00.000',
        }),
        isNull,
      );
    });

    test('健全な行は fromJson と同じ値を返す', () {
      final json = {
        'id': 'e9',
        'amount': 800,
        'category': '娯楽',
        'date': DateTime(2026, 11, 13, 8, 30).toUtc().toIso8601String(),
      };
      final viaTry = ExpenseEntry.tryFromJson(json);
      final viaFrom = ExpenseEntry.fromJson(json);
      expect(viaTry, isNotNull);
      expect(viaTry!.date, viaFrom.date);
      expect(viaTry.date.isUtc, isFalse);
    });

    test('fromJson は壊れた日付で FormatException（理由が読める）', () {
      expect(
        () => ExpenseEntry.fromJson({
          'id': 'e1',
          'amount': 100,
          'category': '食費',
          'date': 'not-a-date',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
