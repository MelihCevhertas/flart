// ignore_for_file: depend_on_referenced_packages

import 'package:flart_core/flart_core.dart';
import 'package:test/test.dart';

void main() {
  group('BashFilterThresholds.defaults', () {
    test('passthrough/large split matches v0.3.0 plan', () {
      const t = BashFilterThresholds.defaults;
      expect(t.passthroughLines, 30);
      expect(t.largeLines, 200);
    });

    test('head/tail sizes — medium > large head (more breathing room when '
        'output is moderate)', () {
      const t = BashFilterThresholds.defaults;
      expect(t.mediumHeadLines, greaterThan(t.largeHeadLines));
      expect(t.mediumTailLines, t.largeTailLines,
          reason: 'tail size constant across strategies in v0.3.0');
    });

    test('error preservation caps are generous (stderr 2 KB, stdout tail 20)',
        () {
      const t = BashFilterThresholds.defaults;
      expect(t.errorStderrCapBytes, 2048);
      expect(t.errorStdoutTailLines, 20);
    });

    test('constructor accepts custom overrides for testability', () {
      const t = BashFilterThresholds(passthroughLines: 5, largeLines: 50);
      expect(t.passthroughLines, 5);
      expect(t.largeLines, 50);
      // Untouched fields fall back to declared defaults.
      expect(t.mediumHeadLines, 20);
    });
  });
}
