// ignore_for_file: depend_on_referenced_packages

import 'package:flart_hooks/flart_hooks.dart';
import 'package:test/test.dart';

void main() {
  group('parseClaudeVersion', () {
    test('plain semver triple parses', () {
      expect(parseClaudeVersion('2.1.144'),
          const ClaudeCodeVersion(2, 1, 144));
    });

    test('"Claude Code v<X>.<Y>.<Z> (...)" preamble + suffix tolerated', () {
      expect(parseClaudeVersion('Claude Code v2.1.144 (Claude Code)'),
          const ClaudeCodeVersion(2, 1, 144));
    });

    test('newline-terminated stdout parses', () {
      expect(parseClaudeVersion('  2.0.10\n'),
          const ClaudeCodeVersion(2, 0, 10));
    });

    test('no triple → null', () {
      expect(parseClaudeVersion('claude: command not found'), isNull);
    });

    test('null input → null', () {
      expect(parseClaudeVersion(null), isNull);
    });

    test('first triple wins (defensive against build SHAs)', () {
      // "build 1.2.3" appears after the version; we still want the version.
      expect(parseClaudeVersion('Claude Code v2.1.144 build 9.9.9'),
          const ClaudeCodeVersion(2, 1, 144));
    });
  });

  group('ClaudeCodeVersion ordering', () {
    test('compareTo across all three fields', () {
      const a = ClaudeCodeVersion(2, 1, 120);
      const b = ClaudeCodeVersion(2, 1, 121);
      const c = ClaudeCodeVersion(2, 2, 0);
      const d = ClaudeCodeVersion(3, 0, 0);
      expect(a.compareTo(b), isNegative);
      expect(b.compareTo(c), isNegative);
      expect(c.compareTo(d), isNegative);
      expect(b.compareTo(b), 0);
    });

    test('supportsOutputMutation threshold is v2.1.121', () {
      expect(const ClaudeCodeVersion(2, 1, 120).supportsOutputMutation, isFalse);
      expect(const ClaudeCodeVersion(2, 1, 121).supportsOutputMutation, isTrue);
      expect(const ClaudeCodeVersion(2, 1, 144).supportsOutputMutation, isTrue);
      expect(const ClaudeCodeVersion(3, 0, 0).supportsOutputMutation, isTrue);
    });

    test('== and hashCode by structural equality', () {
      const v1 = ClaudeCodeVersion(2, 1, 144);
      const v2 = ClaudeCodeVersion(2, 1, 144);
      expect(v1 == v2, isTrue);
      expect(v1.hashCode, v2.hashCode);
    });
  });

  group('detectClaudeVersion (injected runner)', () {
    test('parses fake "claude --version" output', () async {
      final v = await detectClaudeVersion(
          runVersion: () async => '2.1.144 (Claude Code)');
      expect(v, const ClaudeCodeVersion(2, 1, 144));
    });

    test('claude missing → null', () async {
      final v = await detectClaudeVersion(runVersion: () async => null);
      expect(v, isNull);
    });

    test('claude prints unparseable output → null', () async {
      final v = await detectClaudeVersion(
          runVersion: () async => 'no version info available');
      expect(v, isNull);
    });
  });
}
