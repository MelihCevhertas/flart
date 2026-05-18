// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:flart_core/flart_core.dart';
import 'package:test/test.dart';

void main() {
  group('SafeTruncator.byteSafePrefix', () {
    test('returns input unchanged when within budget', () {
      expect(SafeTruncator.byteSafePrefix('hello', 100), 'hello');
      expect(SafeTruncator.byteSafePrefix('hello', 5), 'hello');
    });

    test('cuts at byte boundary when budget exceeded', () {
      expect(SafeTruncator.byteSafePrefix('abcdefghij', 4), 'abcd');
    });

    test('never splits a UTF-8 code point', () {
      // 'ü' is 2 bytes (0xC3 0xBC). Cutting at byte 3 of 'aüb' (a=1, ü=2..3,
      // b=4) would split ü; truncator must back off to byte 1.
      const input = 'aüb';
      expect(utf8.encode(input).length, 4);
      final result = SafeTruncator.byteSafePrefix(input, 2);
      expect(result, 'a');
      // Cut after ü (3 bytes) keeps "aü".
      expect(SafeTruncator.byteSafePrefix(input, 3), 'aü');
    });

    test('handles empty input and zero budget', () {
      expect(SafeTruncator.byteSafePrefix('', 10), '');
      expect(SafeTruncator.byteSafePrefix('abc', 0), '');
    });
  });

  group('SafeTruncator.headTail', () {
    test('returns input unchanged when within budget', () {
      const input = 'one\ntwo\nthree\n';
      expect(
        SafeTruncator.headTail(input: input, maxBytes: 1000),
        input,
      );
    });

    test('preserves first and last segments and inserts marker', () {
      final lines = List.generate(200, (i) => 'line-$i').join('\n');
      final out = SafeTruncator.headTail(input: lines, maxBytes: 200);
      expect(out, contains('line-0'));
      expect(out, contains('line-199'));
      expect(out, contains('truncated'));
      expect(out, contains('kept first'));
      expect(out, contains('last'));
      expect(utf8.encode(out).length, lessThanOrEqualTo(200));
    });

    test('snaps to line boundaries — no partial lines', () {
      final lines = List.generate(50, (i) => 'L$i-PADDING-PADDING').join('\n');
      final out = SafeTruncator.headTail(input: lines, maxBytes: 250);
      // Every line in output should be a complete line or empty.
      // Split out marker first.
      for (final segment in out.split(RegExp(r'\.\.\..*\.\.\.'))) {
        for (final line in segment.split('\n')) {
          if (line.isEmpty) continue;
          // Original lines look like 'L<n>-PADDING-PADDING'.
          expect(
            RegExp(r'^L\d+-PADDING-PADDING$').hasMatch(line),
            isTrue,
            reason: 'unexpected fragment in output: "$line"',
          );
        }
      }
    });

    test('marker placeholders are substituted with real counts', () {
      final lines = List.generate(100, (i) => 'x' * 30).join('\n');
      final out = SafeTruncator.headTail(input: lines, maxBytes: 300);
      // No raw placeholders left behind.
      expect(out, isNot(contains('{n}')));
      expect(out, isNot(contains('{bytes}')));
      expect(out, isNot(contains('{head}')));
      expect(out, isNot(contains('{tail}')));
    });

    test('UTF-8 char never split across head/tail cuts', () {
      // Many multi-byte chars: 'ü' (2 bytes each).
      final input = ('ü' * 500); // 1000 bytes
      final out = SafeTruncator.headTail(input: input, maxBytes: 200);
      // Decoded successfully — no replacement chars from broken UTF-8.
      expect(out, isNot(contains('�')));
    });

    test('falls back to byteSafePrefix when marker exceeds budget', () {
      final input = 'a' * 1000;
      final out = SafeTruncator.headTail(input: input, maxBytes: 20);
      // With maxBytes=20 and marker overhead > 20, falls back to bare prefix.
      expect(out, 'a' * 20);
    });
  });
}
