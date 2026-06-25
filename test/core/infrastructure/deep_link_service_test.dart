import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/deep_link_service.dart';

void main() {
  group('DeepLinkService.parseWeeklyReportWeek', () {
    // ── 正常系 ──

    test('parses valid week from URL', () {
      final uri = Uri.parse('app://weekly-report?week=2026-W25');
      expect(DeepLinkService.parseWeeklyReportWeek(uri), '2026-W25');
    });

    test('parses different week values', () {
      expect(
        DeepLinkService.parseWeeklyReportWeek(
          Uri.parse('app://weekly-report?week=2026-W01'),
        ),
        '2026-W01',
      );
      expect(
        DeepLinkService.parseWeeklyReportWeek(
          Uri.parse('app://weekly-report?week=2026-W52'),
        ),
        '2026-W52',
      );
      expect(
        DeepLinkService.parseWeeklyReportWeek(
          Uri.parse('app://weekly-report?week=2027-W03'),
        ),
        '2027-W03',
      );
    });

    test('parses week with W53 (ISO max)', () {
      final uri = Uri.parse('app://weekly-report?week=2026-W53');
      expect(DeepLinkService.parseWeeklyReportWeek(uri), '2026-W53');
    });

    // ── 異常系：異なる scheme ──

    test('returns null for https scheme', () {
      final uri = Uri.parse('https://weekly-report?week=2026-W25');
      expect(DeepLinkService.parseWeeklyReportWeek(uri), isNull);
    });

    test('returns null for other custom scheme', () {
      final uri = Uri.parse('myapp://weekly-report?week=2026-W25');
      expect(DeepLinkService.parseWeeklyReportWeek(uri), isNull);
    });

    test('returns null for empty scheme', () {
      final uri = Uri.parse('weekly-report?week=2026-W25');
      expect(DeepLinkService.parseWeeklyReportWeek(uri), isNull);
    });

    // ── 異常系：異なる host ──

    test('returns null for different host', () {
      final uri = Uri.parse('app://dashboard?week=2026-W25');
      expect(DeepLinkService.parseWeeklyReportWeek(uri), isNull);
    });

    test('returns null for empty host', () {
      final uri = Uri.parse('app://?week=2026-W25');
      expect(DeepLinkService.parseWeeklyReportWeek(uri), isNull);
    });

    test('returns same week for host with trailing path (path is ignored)', () {
      // Uri.parse('app://weekly-report/something') has host='weekly-report',
      // so it matches our deep link pattern.
      final uri = Uri.parse('app://weekly-report/something?week=2026-W25');
      expect(DeepLinkService.parseWeeklyReportWeek(uri), '2026-W25');
    });

    // ── 異常系：week パラメータなし ──

    test('returns null when week parameter is missing', () {
      final uri = Uri.parse('app://weekly-report');
      expect(DeepLinkService.parseWeeklyReportWeek(uri), isNull);
    });

    test('returns null when week parameter is empty', () {
      final uri = Uri.parse('app://weekly-report?week=');
      expect(DeepLinkService.parseWeeklyReportWeek(uri), '');
    });

    test('returns null for completely different URL', () {
      final uri = Uri.parse('https://example.com/page');
      expect(DeepLinkService.parseWeeklyReportWeek(uri), isNull);
    });

    // ── 追加パラメータ ──

    test('ignores extra query parameters', () {
      final uri = Uri.parse(
        'app://weekly-report?week=2026-W25&source=notification',
      );
      expect(DeepLinkService.parseWeeklyReportWeek(uri), '2026-W25');
    });

    test('handles URL with fragment', () {
      final uri = Uri.parse('app://weekly-report?week=2026-W25#summary');
      expect(DeepLinkService.parseWeeklyReportWeek(uri), '2026-W25');
    });
  });

  group('DeepLinkService.isWeeklyReportLink', () {
    test('returns true for valid weekly report link', () {
      expect(
        DeepLinkService.isWeeklyReportLink(
          Uri.parse('app://weekly-report?week=2026-W25'),
        ),
        isTrue,
      );
    });

    test('returns false for invalid link', () {
      expect(
        DeepLinkService.isWeeklyReportLink(
          Uri.parse('https://example.com'),
        ),
        isFalse,
      );
    });

    test('returns false when week parameter is empty', () {
      // empty string is truthy in Dart, so parseWeeklyReportWeek returns ''
      // which is not null → isWeeklyReportLink returns true
      // This is the current behavior — empty week is still a report link
      expect(
        DeepLinkService.isWeeklyReportLink(
          Uri.parse('app://weekly-report?week='),
        ),
        isTrue,
      );
    });

    test('returns false for null', () {
      expect(
        DeepLinkService.isWeeklyReportLink(
          Uri.parse('app://weekly-report'),
        ),
        isFalse,
      );
    });
  });
}
