// ignore_for_file: depend_on_referenced_packages

import 'package:flart_core/flart_core.dart';
import 'package:flart_hooks/flart_hooks.dart';
import 'package:test/test.dart';

String _lines(int n, [String prefix = 'line ']) => List.generate(
      n,
      (i) => '$prefix${i + 1}',
    ).join('\n');

void main() {
  const teeDir = '/data/flart/tee';
  final filter = BashPostFilter(teeDirectory: teeDir);

  group('bypass rules', () {
    test('empty output → bypass(empty-output)', () {
      final r = filter.filter(
        stdout: '',
        stderr: '',
        exitCode: 0,
        command: 'echo hi',
      );
      expect(r.bypass, isTrue);
      expect(r.bypassReason, 'empty-output');
    });

    test('flart-prefixed command → bypass(flart-prefix)', () {
      final r = filter.filter(
        stdout: _lines(100),
        stderr: '',
        exitCode: 0,
        command: 'flart analyze',
      );
      expect(r.bypass, isTrue);
      expect(r.bypassReason, 'flart-prefix');
      expect(r.commandLabel, 'flart');
    });

    test('cd ... && flart ... also passthroughs', () {
      final r = filter.filter(
        stdout: _lines(100),
        stderr: '',
        exitCode: 0,
        command: 'cd /tmp/proj && flart test',
      );
      expect(r.bypass, isTrue);
      expect(r.bypassReason, 'flart-prefix');
    });

    test('FLART_FULL_OUTPUT=1 prefix → bypass(explicit-env)', () {
      final r = filter.filter(
        stdout: _lines(500),
        stderr: '',
        exitCode: 0,
        command: 'FLART_FULL_OUTPUT=1 find lib -name "*.dart"',
      );
      expect(r.bypass, isTrue);
      expect(r.bypassReason, 'explicit-env');
    });

    test('cat <tee>/<file> → bypass(tee-read)', () {
      final r = filter.filter(
        stdout: _lines(500),
        stderr: '',
        exitCode: 0,
        command: 'cat $teeDir/12345_bash.log',
      );
      expect(r.bypass, isTrue);
      expect(r.bypassReason, 'tee-read');
    });

    test('grep "TODO" <tee path> → bypass(tee-read)', () {
      final r = filter.filter(
        stdout: _lines(500),
        stderr: '',
        exitCode: 0,
        command: 'grep TODO $teeDir/12345_grep.log',
      );
      expect(r.bypass, isTrue);
      expect(r.bypassReason, 'tee-read');
    });

    test('cat without tee path argument is NOT bypassed', () {
      final r = filter.filter(
        stdout: _lines(100),
        stderr: '',
        exitCode: 0,
        command: 'cat /tmp/random.txt',
      );
      expect(r.bypass, isFalse,
          reason: '`cat` against an unrelated path should still be filtered '
              'so unbounded file reads pay for themselves.');
    });

    test('small output + exit 0 → bypass(small-output)', () {
      final r = filter.filter(
        stdout: _lines(10),
        stderr: '',
        exitCode: 0,
        command: 'ls',
      );
      expect(r.bypass, isTrue);
      expect(r.bypassReason, 'small-output');
    });

    test('exit != 0 with substantial output → framed error format', () {
      // Long stderr + stdout so the "Command failed (exit N)" frame
      // genuinely compresses rather than inflating tiny errors.
      final stderr = List.generate(
              30, (i) => 'gcc: error[E$i]: undeclared symbol at line ${i * 7}')
          .join('\n');
      final r = filter.filter(
        stdout: _lines(60),
        stderr: stderr,
        exitCode: 1,
        command: 'make all',
      );
      expect(r.bypass, isFalse);
      expect(r.updatedOutput, contains('Command failed (exit 1)'));
      expect(r.updatedOutput, contains('undeclared symbol'));
      expect(r.updatedOutput, contains('stdout (last 20 lines of 60):'));
    });

    test('tiny error → bypass(bloat-fallback) — framing would inflate', () {
      // ~58-byte stderr; any framing would more than double the byte count,
      // so the anti-bloat rule trips and we let Claude Code render the raw
      // tool_response as-is.
      final r = filter.filter(
        stdout: '',
        stderr: 'ls: cannot access /nope: No such file or directory',
        exitCode: 1,
        command: 'ls /nope',
      );
      expect(r.bypass, isTrue);
      expect(r.bypassReason, 'bloat-fallback');
    });
  });

  group('filter strategies', () {
    test('medium output: 50 lines → head 20 + tail 5 (+ elision marker)', () {
      final r = filter.filter(
        stdout: _lines(50),
        stderr: '',
        exitCode: 0,
        command: 'grep -rn TODO lib/',
        teePath: '$teeDir/12345_grep.log',
      );
      expect(r.bypass, isFalse);
      expect(r.updatedOutput, contains('first 20 + last 5 of 50'));
      expect(r.updatedOutput, contains('line 1\n'));
      expect(r.updatedOutput, contains('line 20\n'));
      expect(r.updatedOutput, contains('line 46\n')); // last 5 = 46..50
      expect(r.updatedOutput, contains('line 50'));
      expect(r.updatedOutput, isNot(contains('line 21\n')),
          reason: 'elided body should not contain middle lines');
      expect(r.updatedOutput, contains('Full log: $teeDir/12345_grep.log'));
    });

    test('large output: 500 lines → head 15 + tail 5 + error grep', () {
      final body = <String>[
        ...List.generate(15, (i) => 'header ${i + 1}'),
        ...List.generate(480, (i) {
          if (i == 100) return 'WARNING: package outdated';
          if (i == 200) return 'Error: missing dependency';
          if (i == 300) return 'fatal: unreachable host';
          return 'mid ${i + 1}';
        }),
        ...List.generate(5, (i) => 'footer ${i + 1}'),
      ];
      final r = filter.filter(
        stdout: body.join('\n'),
        stderr: '',
        exitCode: 0,
        command: 'find lib -name "*.dart" -exec wc -l {} +',
      );
      expect(r.bypass, isFalse);
      expect(r.updatedOutput, contains('first 15 + last 5 of 500'));
      expect(r.updatedOutput, contains('header 1'));
      expect(r.updatedOutput, contains('header 15'));
      expect(r.updatedOutput, contains('footer 5'));
      expect(r.updatedOutput, contains('Error-flavoured lines from the elided body'));
      expect(r.updatedOutput, contains('Error: missing dependency'));
      expect(r.updatedOutput, contains('WARNING: package outdated'));
    });

    test('error output: format per plan v1.15', () {
      // Substantial stderr + stdout so the frame compresses (anti-bloat).
      final stderr = List.generate(
              25, (i) => 'compile: error[E$i] at file_$i.dart:${i * 3}: bad ref')
          .join('\n');
      final r = filter.filter(
        stdout: _lines(60),
        stderr: stderr,
        exitCode: 2,
        command: 'make build',
        teePath: '$teeDir/12345_make.log',
      );
      expect(r.bypass, isFalse);
      expect(r.updatedOutput, startsWith('Command failed (exit 2).'));
      expect(r.updatedOutput, contains('stderr ('));
      expect(r.updatedOutput, contains('bad ref'));
      // Plan v1.15: stdout last 20 lines for context.
      expect(r.updatedOutput, contains('stdout (last 20 lines of 60):'));
      expect(r.updatedOutput, contains('line 60'));
      expect(r.updatedOutput, contains('Full log: $teeDir/12345_make.log'));
    });

    test('error output: stderr capped at 2 KB with explicit marker', () {
      final largeStderr = 'X' * 4096; // > 2 KB cap
      final r = filter.filter(
        stdout: '',
        stderr: largeStderr,
        exitCode: 1,
        command: 'some-flaky-tool',
      );
      expect(r.updatedOutput, contains('stderr truncated at 2048 B'));
      // Most of the 4 KB stays out of the agent's view.
      expect(r.filteredBytes, lessThan(r.rawBytes));
    });

    test('additionalContext mentions escape mechanisms', () {
      final r = filter.filter(
        stdout: _lines(100),
        stderr: '',
        exitCode: 0,
        command: 'grep -rn FIXME lib/',
        teePath: '$teeDir/12345_grep.log',
      );
      expect(r.additionalContext, contains('FLART_FULL_OUTPUT=1'));
      expect(r.additionalContext, contains(teeDir));
    });
  });

  group('command label extraction', () {
    test('first token', () {
      final r = filter.filter(
        stdout: _lines(40),
        stderr: '',
        exitCode: 0,
        command: 'grep -rn TODO lib/',
      );
      expect(r.commandLabel, 'grep');
    });

    test('python -c special case', () {
      final r = filter.filter(
        stdout: _lines(40),
        stderr: '',
        exitCode: 0,
        command: "python3 -c 'print(42)'",
      );
      expect(r.commandLabel, 'python3 -c');
    });

    test('shell builtin', () {
      final r = filter.filter(
        stdout: _lines(40),
        stderr: '',
        exitCode: 0,
        command: 'export FOO=bar',
      );
      expect(r.commandLabel, 'shell');
    });

    test('absolute path → basename', () {
      final r = filter.filter(
        stdout: _lines(40),
        stderr: '',
        exitCode: 0,
        command: '/usr/local/bin/customtool arg1 arg2',
      );
      expect(r.commandLabel, 'customtool');
    });

    test('cd && ... uses the post-cd command', () {
      final r = filter.filter(
        stdout: _lines(40),
        stderr: '',
        exitCode: 0,
        command: 'cd /tmp/proj && find . -name "*.log"',
      );
      expect(r.commandLabel, 'find');
    });
  });

  group('without tee directory (config disabled)', () {
    final noTee = const BashPostFilter(teeDirectory: null);

    test('tee-read rule never fires when teeDirectory is null', () {
      final r = noTee.filter(
        stdout: _lines(100),
        stderr: '',
        exitCode: 0,
        command: 'cat /tmp/anything.log',
      );
      expect(r.bypass, isFalse,
          reason: 'no tee dir → no tee-read bypass; cat falls through to '
              'medium-output filter');
    });

    test('threshold customisation propagates (large-tier with tight limits)',
        () {
      // Tight thresholds — also shrink head/tail so 50 lines isn't almost
      // entirely preserved verbatim. Lines are long so anti-bloat doesn't
      // trip on metadata overhead.
      const tight = BashPostFilter(
        thresholds: BashFilterThresholds(
          passthroughLines: 5,
          largeLines: 20,
          largeHeadLines: 5,
          largeTailLines: 2,
        ),
      );
      final body = List.generate(
        50,
        (i) => 'lib/feature_$i.dart:${i * 11}:8: warning[W$i]: '
            'long descriptive message that pushes per-line bytes well past '
            'the framing overhead so the filter actually saves bytes',
      ).join('\n');
      final r = tight.filter(
        stdout: body,
        stderr: '',
        exitCode: 0,
        command: 'echo many',
      );
      expect(r.bypass, isFalse,
          reason: '50 lines > custom largeLines of 20 → large-tier mediation.');
      expect(r.updatedOutput, contains('first 5 + last 2 of 50'));
    });
  });

  group('byte accounting', () {
    test('filteredBytes == rawBytes on bypass', () {
      final r = filter.filter(
        stdout: _lines(5),
        stderr: '',
        exitCode: 0,
        command: 'ls',
      );
      expect(r.bypass, isTrue);
      expect(r.filteredBytes, r.rawBytes);
    });

    test('filteredBytes < rawBytes when a large output is mutated', () {
      final r = filter.filter(
        stdout: _lines(500),
        stderr: '',
        exitCode: 0,
        command: 'grep -rn anything lib/',
      );
      expect(r.bypass, isFalse);
      expect(r.filteredBytes, lessThan(r.rawBytes));
    });
  });
}
