// `test` and `lints` are workspace-level dev dependencies (root pubspec);
// member packages don't re-declare them. The lint below would otherwise
// flag every test file in the workspace.
// ignore_for_file: depend_on_referenced_packages

import 'package:flart_core/flart_core.dart';
import 'package:test/test.dart';

void main() {
  group('FlartEnv', () {
    test('noSavings is false when FLART_NO_SAVINGS is unset', () {
      final env = FlartEnv(const {});
      expect(env.noSavings, isFalse);
    });

    test('noSavings accepts 1, true, yes, on (case-insensitive, trimmed)', () {
      for (final v in ['1', 'true', 'TRUE', '  yes ', 'on', 'Yes']) {
        final env = FlartEnv({'FLART_NO_SAVINGS': v});
        expect(env.noSavings, isTrue, reason: 'value: "$v"');
      }
    });

    test('noSavings rejects 0, false, empty, garbage', () {
      for (final v in ['0', 'false', '', 'maybe', 'no']) {
        final env = FlartEnv({'FLART_NO_SAVINGS': v});
        expect(env.noSavings, isFalse, reason: 'value: "$v"');
      }
    });

    test('dataDir returns null when unset or empty', () {
      expect(FlartEnv(const {}).dataDir, isNull);
      expect(FlartEnv(const {'FLART_DATA_DIR': ''}).dataDir, isNull);
      expect(FlartEnv(const {'FLART_DATA_DIR': '   '}).dataDir, isNull);
    });

    test('dataDir passes through trimmed value', () {
      final env = FlartEnv(const {'FLART_DATA_DIR': '  /tmp/flart-test  '});
      expect(env.dataDir, '/tmp/flart-test');
    });

    test('home falls back to USERPROFILE when HOME is missing', () {
      expect(
        FlartEnv(const {'HOME': '/home/x'}).home,
        '/home/x',
      );
      expect(
        FlartEnv(const {'USERPROFILE': 'C:\\Users\\x'}).home,
        'C:\\Users\\x',
      );
      expect(FlartEnv(const {}).home, isNull);
    });

    test('configPath returns trimmed value or null', () {
      expect(FlartEnv(const {}).configPath, isNull);
      expect(FlartEnv(const {'FLART_CONFIG': ''}).configPath, isNull);
      expect(
        FlartEnv(const {'FLART_CONFIG': ' /etc/flart.yaml '}).configPath,
        '/etc/flart.yaml',
      );
    });
  });
}
