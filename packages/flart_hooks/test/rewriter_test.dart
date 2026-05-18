// ignore_for_file: depend_on_referenced_packages

import 'package:flart_hooks/flart_hooks.dart';
import 'package:test/test.dart';

void main() {
  final r = CommandRewriter();

  group('CommandRewriter — basic substitutions', () {
    test('flutter analyze → flart analyze', () {
      expect(r.rewrite('flutter analyze'), 'flart analyze');
    });

    test('dart analyze → flart analyze', () {
      expect(r.rewrite('dart analyze'), 'flart analyze');
    });

    test('flutter test → flart test', () {
      expect(r.rewrite('flutter test'), 'flart test');
    });

    test('flutter build apk preserves args', () {
      expect(
        r.rewrite('flutter build apk --release --no-shrink'),
        'flart build apk --release --no-shrink',
      );
    });

    test('flutter pub get with workspace flag', () {
      expect(
        r.rewrite('flutter pub get --offline'),
        'flart pub get --offline',
      );
    });

    test('dart format with paths', () {
      expect(
        r.rewrite('dart format lib/ test/'),
        'flart format lib/ test/',
      );
    });

    test('dart fix --apply distinct from dart fix', () {
      expect(r.rewrite('dart fix --apply'), 'flart fix --apply');
      expect(r.rewrite('dart fix'), 'flart fix');
    });

    test('dart fix --dry-run passes the flag through unchanged', () {
      // `flart fix` already defaults to dry-run; user-supplied --dry-run is
      // a no-op for the underlying tool but must round-trip cleanly.
      expect(r.rewrite('dart fix --dry-run'), 'flart fix --dry-run');
    });

    test('dart fix with code filter', () {
      expect(
        r.rewrite('dart fix --apply --code=unused_import'),
        'flart fix --apply --code=unused_import',
      );
    });

    test('dart compile exe with output path', () {
      expect(
        r.rewrite('dart compile exe bin/main.dart -o /tmp/x'),
        'flart compile exe bin/main.dart -o /tmp/x',
      );
    });
  });

  group('CommandRewriter — cd preservation', () {
    test('leading cd is preserved before rewritten command', () {
      expect(
        r.rewrite('cd /tmp/wonderous && flutter test'),
        'cd /tmp/wonderous && flart test',
      );
    });

    test('cd with quoted path', () {
      expect(
        r.rewrite('cd "/my dir/proj" && flutter analyze'),
        'cd "/my dir/proj" && flart analyze',
      );
    });

    test('cd whose target command has no rule → unchanged', () {
      const input = 'cd /tmp && git status';
      expect(r.rewrite(input), input);
    });
  });

  group('CommandRewriter — shell features bail out', () {
    test('pipe to tee → not rewritten', () {
      const input = 'flutter analyze | tee output.txt';
      expect(r.rewrite(input), input);
    });

    test('stdout redirect → not rewritten', () {
      const input = 'flutter test > out.log';
      expect(r.rewrite(input), input);
    });

    test('stdout/stderr redirect → not rewritten', () {
      const input = 'flutter build apk 2> err.log';
      expect(r.rewrite(input), input);
    });

    test('background & → not rewritten', () {
      const input = 'flutter test &';
      expect(r.rewrite(input), input);
    });

    test('background-only after flutter analyze (no other flags)', () {
      const input = 'flutter analyze &';
      expect(r.rewrite(input), input);
    });

    test('background within cd-chain is also rejected', () {
      const input = 'cd /tmp && flutter test &';
      expect(r.rewrite(input), input);
    });

    test('semicolon chain → not rewritten', () {
      const input = 'flutter analyze; flutter test';
      expect(r.rewrite(input), input);
    });
  });

  group('CommandRewriter — passthrough', () {
    test('non-flart-mapped command unchanged', () {
      const input = 'git status';
      expect(r.rewrite(input), input);
    });

    test('empty input returned as-is', () {
      expect(r.rewrite(''), '');
      expect(r.rewrite('   '), '   ');
    });

    test('fvm-wrapped command is NOT rewritten (v1.0 limitation)', () {
      const input = 'fvm flutter analyze';
      expect(r.rewrite(input), input);
    });

    test('flutter run (out of scope) unchanged', () {
      const input = 'flutter run';
      expect(r.rewrite(input), input);
    });
  });
}
