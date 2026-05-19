// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flart_cli/runner.dart';
import 'package:flart_core/flart_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _CapturingSink implements IOSink {
  final StringBuffer buffer = StringBuffer();
  @override
  Encoding encoding = utf8;
  @override
  void write(Object? o) => buffer.write(o);
  @override
  void writeln([Object? o = '']) => buffer.writeln(o);
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      buffer.writeAll(objects, separator);
  @override
  void writeCharCode(int c) => buffer.write(String.fromCharCode(c));
  @override
  void add(List<int> data) => buffer.write(utf8.decode(data));
  @override
  void addError(Object e, [StackTrace? s]) {}
  @override
  Future<void> addStream(Stream<List<int>> s) async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> flush() async {}
  @override
  Future<void> get done => Future.value();
}

Future<({int code, String stdout, String stderr})> _run({
  required FlartEnv env,
  required Map<String, Object?> input,
}) async {
  final out = _CapturingSink();
  final err = _CapturingSink();
  final stdinStream = Stream.value(utf8.encode(jsonEncode(input)));
  final code = await runFlart(
    const ['bash-post-hook'],
    envOverride: env,
    stdinOverride: stdinStream,
    stdoutOverride: out,
    stderrOverride: err,
  );
  return (
    code: code,
    stdout: out.buffer.toString(),
    stderr: err.buffer.toString(),
  );
}

String _bigOutput(int lines) =>
    List.generate(lines, (i) => 'line ${i + 1}').join('\n');

void main() {
  late Directory tmp;
  late FlartEnv env;
  late String dbPath;
  late String teeDir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flart_bash_post_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    env = FlartEnv({
      'FLART_DATA_DIR': tmp.path,
      'HOME': tmp.path,
    });
    dbPath = p.join(tmp.path, 'savings.db');
    teeDir = p.join(tmp.path, 'tee');
  });

  group('flart bash-post-hook — bypass branches', () {
    test('small output → empty body, no DB row, no tee', () async {
      final r = await _run(env: env, input: {
        'tool_input': {'command': 'echo hi'},
        'tool_response': {'stdout': _bigOutput(5), 'stderr': '', 'exit_code': 0},
        'cwd': '/proj',
      });
      expect(r.code, 0);
      // Empty stdout body — Claude Code keeps the raw output.
      expect(r.stdout.trim(), isEmpty);
      // No DB written.
      expect(File(dbPath).existsSync(), isFalse);
    });

    test('flart-prefixed command → bypass', () async {
      final r = await _run(env: env, input: {
        'tool_input': {'command': 'flart analyze'},
        'tool_response': {'stdout': _bigOutput(100), 'stderr': '', 'exit_code': 0},
        'cwd': '/proj',
      });
      expect(r.code, 0);
      expect(r.stdout.trim(), isEmpty);
    });

    test('FLART_FULL_OUTPUT=1 prefix → bypass', () async {
      final r = await _run(env: env, input: {
        'tool_input': {'command': 'FLART_FULL_OUTPUT=1 find lib -name "*.dart"'},
        'tool_response': {'stdout': _bigOutput(300), 'stderr': '', 'exit_code': 0},
        'cwd': '/proj',
      });
      expect(r.code, 0);
      expect(r.stdout.trim(), isEmpty);
    });
  });

  group('flart bash-post-hook — mutation branches', () {
    test('medium output (longer lines): emits updatedToolOutput + DB row',
        () async {
      // Use longer lines so the head/tail savings actually exceed the
      // intro/elision metadata overhead. Short test lines tripped the
      // anti-bloat fallback (raw < filtered+metadata).
      final body = List.generate(
        50,
        (i) => 'lib/src/feature_${i.toString().padLeft(3, '0')}.dart: TODO(team): '
            'flesh out the case for ${i + 1} variants — see issue #$i',
      ).join('\n');
      final r = await _run(env: env, input: {
        'tool_input': {'command': 'grep -rn TODO lib/'},
        'tool_response': {'stdout': body, 'stderr': '', 'exit_code': 0},
        'cwd': '/proj',
      });
      expect(r.code, 0);
      final decoded = jsonDecode(r.stdout.trim()) as Map<String, Object?>;
      final spec = decoded['hookSpecificOutput'] as Map<String, Object?>;
      expect(spec['hookEventName'], 'PostToolUse');
      expect(spec['updatedToolOutput'],
          contains('first 20 + last 5 of 50'));
      expect(spec['additionalContext'], contains('FLART_FULL_OUTPUT=1'));

      final db = FlartDatabase.open(path: dbPath);
      addTearDown(db.dispose);
      final rows = InvocationRepo(db)
          .findRange(projectPath: '/proj', module: 'bash_post');
      expect(rows.length, 1);
      expect(rows.first.command, 'grep');
      expect(rows.first.rawBytes, greaterThan(rows.first.filteredBytes));
    });

    test('anti-bloat fallback: short lines + filter overhead → bypass',
        () async {
      // 50 lines of "line N" (7-byte avg) — head/tail metadata exceeds the
      // body savings. Filter must bypass instead of inflating the output.
      final r = await _run(env: env, input: {
        'tool_input': {'command': 'echo many'},
        'tool_response': {'stdout': _bigOutput(50), 'stderr': '', 'exit_code': 0},
        'cwd': '/proj',
      });
      expect(r.code, 0);
      expect(r.stdout.trim(), isEmpty,
          reason: 'bypass produces empty body — agent sees raw output');
      expect(File(dbPath).existsSync(), isFalse,
          reason: 'no mutation → no DB row');
    });

    test('large output (300 lines) → head/tail + error grep', () async {
      final body = [
        ...List.generate(15, (i) => 'header $i'),
        'Error: simulated failure midway',
        ...List.generate(280, (i) => 'mid $i'),
        ...List.generate(5, (i) => 'footer $i'),
      ].join('\n');
      final r = await _run(env: env, input: {
        'tool_input': {'command': 'find lib -name "*.dart" -exec wc -l {} +'},
        'tool_response': {'stdout': body, 'stderr': '', 'exit_code': 0},
        'cwd': '/proj',
      });
      expect(r.code, 0);
      final decoded = jsonDecode(r.stdout.trim()) as Map<String, Object?>;
      final spec = decoded['hookSpecificOutput'] as Map<String, Object?>;
      expect(spec['updatedToolOutput'], contains('first 15 + last 5 of 301'));
      expect(spec['updatedToolOutput'],
          contains('Error: simulated failure midway'));
    });

    test('error preservation: exit != 0 with substantial output', () async {
      // A longer stderr + non-trivial stdout so the framed error format
      // genuinely compresses (anti-bloat fallback would catch tiny errors).
      final stderr = List.generate(
        25,
        (i) => 'gcc: error[E${i.toString().padLeft(4, '0')}]: '
            'symbol "var_$i" undeclared in this scope (line ${i * 7})',
      ).join('\n');
      final stdoutText = List.generate(
        80,
        (i) => 'compiling: src/feature_$i.c — 0.${i}s elapsed',
      ).join('\n');
      final r = await _run(env: env, input: {
        'tool_input': {'command': 'make build'},
        'tool_response': {
          'stdout': stdoutText,
          'stderr': stderr,
          'exit_code': 2,
        },
        'cwd': '/proj',
      });
      expect(r.code, 0);
      final decoded = jsonDecode(r.stdout.trim()) as Map<String, Object?>;
      final spec = decoded['hookSpecificOutput'] as Map<String, Object?>;
      expect(spec['updatedToolOutput'], startsWith('Command failed (exit 2).'));
      expect(spec['updatedToolOutput'], contains('undeclared in this scope'));
      // Plan v1.15: stdout last 20 lines kept for trace context.
      expect(spec['updatedToolOutput'], contains('stdout (last 20 lines of 80):'));
    });

    test('tiny error → bypass (anti-bloat: framing would inflate)', () async {
      final r = await _run(env: env, input: {
        'tool_input': {'command': 'ls /nonexistent'},
        'tool_response': {
          'stdout': '',
          'stderr': 'ls: cannot access /nonexistent: No such file or directory',
          'exit_code': 2,
        },
        'cwd': '/proj',
      });
      expect(r.code, 0);
      // Bypass: agent sees Claude Code's default formatting of the original
      // tool_response, which is shorter than our framed message would be.
      expect(r.stdout.trim(), isEmpty);
    });

    test('tee log is written under <dataDir>/tee/', () async {
      await _run(env: env, input: {
        'tool_input': {'command': 'grep -rn TODO lib/'},
        'tool_response': {'stdout': _bigOutput(80), 'stderr': '', 'exit_code': 0},
        'cwd': '/proj',
      });
      final teeFiles = Directory(teeDir)
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .where((n) => n.endsWith('_bash.log'))
          .toList();
      expect(teeFiles, isNotEmpty);
      expect(teeFiles.first, contains('_grep_bash.log'));
    });
  });

  group('flart bash-post-hook — safety', () {
    test('garbage stdin: exit 0 + empty body (graceful degrade)', () async {
      final out = _CapturingSink();
      final err = _CapturingSink();
      final code = await runFlart(
        const ['bash-post-hook'],
        envOverride: env,
        stdinOverride: Stream.value(utf8.encode('not-json')),
        stdoutOverride: out,
        stderrOverride: err,
      );
      expect(code, 0);
      // empty stdout = no mutation
      expect(out.buffer.toString().trim(), isEmpty);
    });

    test('FLART_NO_SAVINGS=1 skips DB write but still mutates output',
        () async {
      final noSavingsEnv = FlartEnv({
        'FLART_DATA_DIR': tmp.path,
        'HOME': tmp.path,
        'FLART_NO_SAVINGS': '1',
      });
      final r = await _run(env: noSavingsEnv, input: {
        'tool_input': {'command': 'grep -rn TODO lib/'},
        'tool_response': {'stdout': _bigOutput(80), 'stderr': '', 'exit_code': 0},
        'cwd': '/proj',
      });
      expect(r.code, 0);
      final decoded = jsonDecode(r.stdout.trim()) as Map<String, Object?>;
      expect((decoded['hookSpecificOutput'] as Map)['updatedToolOutput'],
          isNotNull);
      // No DB created.
      expect(File(dbPath).existsSync(), isFalse);
    });
  });
}
