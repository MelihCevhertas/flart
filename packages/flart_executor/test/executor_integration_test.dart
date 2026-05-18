// ignore_for_file: depend_on_referenced_packages

@Tags(['integration'])
library;

import 'dart:io';

import 'package:flart_executor/flart_executor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('SandboxExecutor happy path (real runtimes)', () {
    test('bash: runs `echo hello` and captures stdout', () async {
      final detector = RuntimeDetector();
      if (await detector.detect(Runtime.bash) == null) {
        fail('bash is a required runtime per Plan; install via your package manager.');
      }
      final exec = SandboxExecutor();
      final result = await exec.execute(
        runtime: Runtime.bash,
        code: 'echo hello',
      );
      expect(result.exitCode, 0);
      expect(result.stdout.trim(), 'hello');
      expect(result.stderr, isEmpty);
      expect(result.timedOut, isFalse);
      expect(result.wasTruncated, isFalse);
    });

    test('bash: stderr is captured separately from stdout', () async {
      final exec = SandboxExecutor();
      final result = await exec.execute(
        runtime: Runtime.bash,
        code: 'echo on-out; echo on-err 1>&2',
      );
      expect(result.exitCode, 0);
      expect(result.stdout.trim(), 'on-out');
      expect(result.stderr.trim(), 'on-err');
    });

    test('bash: non-zero exit code is propagated', () async {
      final exec = SandboxExecutor();
      final result = await exec.execute(
        runtime: Runtime.bash,
        code: 'echo failing; exit 7',
      );
      expect(result.exitCode, 7);
      expect(result.stdout.trim(), 'failing');
    });

    test('bash: stdin is closed — script reading stdin sees EOF', () async {
      final exec = SandboxExecutor();
      final result = await exec.execute(
        runtime: Runtime.bash,
        // `read` returns non-zero on EOF; we print marker after.
        code: 'read x; echo "read-rc=\$?"; echo "value=\$x"',
      );
      expect(result.exitCode, 0);
      expect(result.stdout, contains('read-rc=1'));
      expect(result.stdout, contains('value='));
    });

    test('dart: runs a simple script and captures stdout', () async {
      final detector = RuntimeDetector();
      if (await detector.detect(Runtime.dart) == null) {
        fail('dart is a required runtime per Plan; you should already have it.');
      }
      final exec = SandboxExecutor();
      final result = await exec.execute(
        runtime: Runtime.dart,
        code: "void main() { print('hello from dart'); }",
      );
      expect(result.exitCode, 0);
      expect(result.stdout, contains('hello from dart'));
    });

    test('dart: auto-wraps top-level code (no main needed)', () async {
      final exec = SandboxExecutor();
      final result = await exec.execute(
        runtime: Runtime.dart,
        code: "print('auto-wrapped');",
      );
      expect(result.exitCode, 0);
      expect(result.stdout, contains('auto-wrapped'));
    });

    test('dart: auto-wrap with imports stays compilable', () async {
      final exec = SandboxExecutor();
      final result = await exec.execute(
        runtime: Runtime.dart,
        code: "import 'dart:io';\n"
            "print('pid=\${pid > 0}');",
      );
      expect(result.exitCode, 0);
      expect(result.stdout, contains('pid=true'));
    });

    test('dart: auto-wrap does NOT bypass package: import validation', () {
      final exec = SandboxExecutor();
      expect(
        () => exec.execute(
          runtime: Runtime.dart,
          code: "import 'package:http/http.dart';\nprint('nope');",
        ),
        throwsA(isA<ImportValidationException>()),
      );
    });

    test('python: runs a simple script when available', () async {
      final detector = RuntimeDetector();
      if (await detector.detect(Runtime.python) == null) {
        markTestSkipped('python (python3/python) not on PATH');
        return;
      }
      final exec = SandboxExecutor();
      final result = await exec.execute(
        runtime: Runtime.python,
        code: 'print("hello from python")',
      );
      expect(result.exitCode, 0);
      expect(result.stdout, contains('hello from python'));
    });

    test('node: runs a simple script when available', () async {
      final detector = RuntimeDetector();
      if (await detector.detect(Runtime.node) == null) {
        markTestSkipped('node not on PATH');
        return;
      }
      final exec = SandboxExecutor();
      final result = await exec.execute(
        runtime: Runtime.node,
        code: 'console.log("hello from node")',
      );
      expect(result.exitCode, 0);
      expect(result.stdout, contains('hello from node'));
    });

    test('wasTruncated flips when stdout exceeds maxOutputBytes', () async {
      final exec = SandboxExecutor();
      // 500 lines × ~30 bytes ≈ 15KB. Cap at 1KB.
      final result = await exec.execute(
        runtime: Runtime.bash,
        code:
            'for i in \$(seq 1 500); do echo "line \$i padding padding"; done',
        maxOutputBytes: 1024,
      );
      expect(result.exitCode, 0);
      expect(result.wasTruncated, isTrue);
    });

    test('head+tail buffer keeps both ends, marker between', () async {
      // Proves the buffer is *not* simple first-N-bytes: tail must contain
      // the last line of stream, even though head is from the start.
      final exec = SandboxExecutor();
      final result = await exec.execute(
        runtime: Runtime.bash,
        code:
            'for i in \$(seq 1 500); do echo "line \$i padding padding"; done',
        maxOutputBytes: 1024,
        headRatio: 0.6,
      );
      expect(result.wasTruncated, isTrue);
      // Head: very first line.
      expect(result.stdout, contains('line 1 padding'));
      // Tail: very last line (NOT in a first-N-bytes capture).
      expect(result.stdout, contains('line 500 padding'));
      // Marker between head and tail.
      expect(
        result.stdout,
        contains(RegExp(
            r'\.\.\. \[\d+ bytes / \d+ lines truncated — kept first \d+ \+ last \d+\] \.\.\.')),
      );
    });

    test('tmp script file is cleaned up after run', () async {
      // We can't easily inspect the tmp dir after deletion, so this is a
      // smoke test: rapid back-to-back runs shouldn't leak (no failures).
      final exec = SandboxExecutor();
      for (var i = 0; i < 5; i++) {
        final r = await exec.execute(
          runtime: Runtime.bash,
          code: 'echo "$i"',
        );
        expect(r.exitCode, 0);
      }
    });
  });

  group('SandboxExecutor timeout', () {
    test('SIGTERM+SIGKILL kills runaway process; exitCode=124, timedOut=true',
        () async {
      final exec = SandboxExecutor();
      final sw = Stopwatch()..start();
      final result = await exec.execute(
        runtime: Runtime.bash,
        // Sleep 3s, then echo. bash blocks in waitpid during `sleep`, so
        // SIGTERM is delayed until the child returns; SIGKILL is what
        // actually ends bash. Test uses a 200ms grace to keep total budget
        // tight; production default is 2s.
        code: 'sleep 3; echo done',
        timeout: const Duration(milliseconds: 500),
        sigkillGrace: const Duration(milliseconds: 200),
      );
      sw.stop();
      expect(result.timedOut, isTrue);
      expect(result.exitCode, 124);
      expect(result.stdout, isNot(contains('done')));
      // 500ms timeout + 200ms grace + epsilon. Total budget 2s for CI slack.
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('process that finishes before timeout exits cleanly', () async {
      final exec = SandboxExecutor();
      final result = await exec.execute(
        runtime: Runtime.bash,
        code: 'echo quick',
        timeout: const Duration(seconds: 5),
      );
      expect(result.timedOut, isFalse);
      expect(result.exitCode, 0);
      expect(result.stdout.trim(), 'quick');
    });
  });

  group('SandboxExecutor.executeFile', () {
    test('reads script from disk and runs it', () async {
      final tmp = Directory.systemTemp.createTempSync('flart_execfile_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final scriptPath = p.join(tmp.path, 'script.sh');
      File(scriptPath).writeAsStringSync('echo from-file');

      final exec = SandboxExecutor();
      final result = await exec.executeFile(
        runtime: Runtime.bash,
        filePath: scriptPath,
      );
      expect(result.exitCode, 0);
      expect(result.stdout.trim(), 'from-file');
    });

    test('non-existent file throws ExecException with hint', () async {
      final exec = SandboxExecutor();
      expect(
        () => exec.executeFile(
          runtime: Runtime.bash,
          filePath: '/tmp/flart-definitely-not-here-${DateTime.now().microsecondsSinceEpoch}/script.sh',
        ),
        throwsA(isA<ExecException>().having(
          (e) => e.toString(),
          'message',
          allOf(contains('file not found'), contains('positional argument')),
        )),
      );
    });
  });
}
