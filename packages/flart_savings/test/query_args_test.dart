// ignore_for_file: depend_on_referenced_packages

import 'package:flart_savings/flart_savings.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 5, 18, 12, 0, 0);
  DateTime fixedNow() => now;

  group('parseSince — relative', () {
    test('hours/days/weeks/months', () {
      expect(parseSince('24h', now: fixedNow), now.subtract(const Duration(hours: 24)));
      expect(parseSince('7d', now: fixedNow), now.subtract(const Duration(days: 7)));
      expect(parseSince('2w', now: fixedNow), now.subtract(const Duration(days: 14)));
      expect(parseSince('3m', now: fixedNow), now.subtract(const Duration(days: 90)));
    });

    test('absolute ISO date', () {
      expect(parseSince('2026-01-15', now: fixedNow),
          DateTime.utc(2026, 1, 15));
    });

    test('absolute ISO datetime', () {
      expect(parseSince('2026-01-15T12:00:00Z', now: fixedNow),
          DateTime.utc(2026, 1, 15, 12, 0, 0));
    });

    test('null/empty returns null', () {
      expect(parseSince(null, now: fixedNow), isNull);
      expect(parseSince('', now: fixedNow), isNull);
      expect(parseSince('   ', now: fixedNow), isNull);
    });

    test('garbage throws FormatException', () {
      expect(() => parseSince('not-a-date', now: fixedNow),
          throwsFormatException);
      expect(() => parseSince('7x', now: fixedNow), throwsFormatException);
    });
  });
}
