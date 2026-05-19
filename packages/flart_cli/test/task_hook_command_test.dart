// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flart_cli/runner.dart';
import 'package:flart_core/flart_core.dart';
import 'package:flart_hooks/flart_hooks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _CapturingSink implements IOSink {
  final StringBuffer buffer = StringBuffer();

  @override
  Encoding encoding = utf8;

  @override
  void write(Object? object) => buffer.write(object);

  @override
  void writeln([Object? object = '']) => buffer.writeln(object);

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    buffer.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) =>
      buffer.write(String.fromCharCode(charCode));

  @override
  void add(List<int> data) => buffer.write(utf8.decode(data));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> get done => Future.value();
}

Future<({int code, String stdout, String stderr})> _run({
  required FlartEnv env,
  required Stream<List<int>> stdinStream,
}) async {
  final outSink = _CapturingSink();
  final errSink = _CapturingSink();
  final code = await runFlart(
    const ['task-hook'],
    envOverride: env,
    stdinOverride: stdinStream,
    stdoutOverride: outSink,
    stderrOverride: errSink,
  );
  return (
    code: code,
    stdout: outSink.buffer.toString(),
    stderr: errSink.buffer.toString(),
  );
}

Stream<List<int>> _payload(Map<String, Object?> obj) =>
    Stream.value(utf8.encode(jsonEncode(obj)));

void main() {
  late Directory tmp;
  late FlartEnv env;
  late String dbPath;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flart_task_hook_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    env = FlartEnv({
      'FLART_DATA_DIR': tmp.path,
      'HOME': tmp.path,
    });
    dbPath = p.join(tmp.path, 'savings.db');
  });

  group('flart task-hook', () {
    test('emits hookSpecificOutput JSON with flart routing context', () async {
      final result = await _run(
        env: env,
        stdinStream: _payload({
          'session_id': 'sess-xyz',
          'cwd': '/some/project',
          'tool_name': 'Task',
        }),
      );
      expect(result.code, 0);
      final decoded = jsonDecode(result.stdout.trim()) as Map<String, Object?>;
      final spec = decoded['hookSpecificOutput'] as Map<String, Object?>;
      expect(spec['hookEventName'], 'PreToolUse');
      expect(spec['additionalContext'], taskAdditionalContext);
    });

    test('records activation in subagent_activations with session + cwd',
        () async {
      await _run(
        env: env,
        stdinStream: _payload({
          'session_id': 'sess-abc',
          'cwd': '/proj/x',
          'tool_name': 'Task',
        }),
      );
      final db = FlartDatabase.open(path: dbPath);
      addTearDown(db.dispose);
      final rows = SubagentActivationRepo(db).recent();
      expect(rows.length, 1);
      expect(rows.first.projectPath, '/proj/x');
      expect(rows.first.parentSessionId, 'sess-abc');
    });

    test('still emits context when stdin JSON is missing/garbage', () async {
      final result = await _run(
        env: env,
        stdinStream: Stream.value(utf8.encode('not-valid-json')),
      );
      expect(result.code, 0);
      final decoded = jsonDecode(result.stdout.trim()) as Map<String, Object?>;
      expect((decoded['hookSpecificOutput'] as Map)['additionalContext'],
          isNotEmpty);
      // No activation row recorded (no fields → falls back to cwd, but the
      // activation is still inserted with detected project_path).
      // Best-effort behaviour: a row may or may not be inserted depending
      // on whether the DB is writable; what matters is `code == 0`.
    });

    test('FLART_NO_SAVINGS=1 skips DB write but still emits context',
        () async {
      final noSavingsEnv = FlartEnv({
        'FLART_DATA_DIR': tmp.path,
        'HOME': tmp.path,
        'FLART_NO_SAVINGS': '1',
      });
      final result = await _run(
        env: noSavingsEnv,
        stdinStream: _payload({
          'session_id': 'sess-no-rec',
          'cwd': '/proj/y',
        }),
      );
      expect(result.code, 0);
      // DB file should not exist because the recording branch was skipped.
      expect(File(dbPath).existsSync(), isFalse);
      // But the response is still well-formed.
      final decoded = jsonDecode(result.stdout.trim()) as Map<String, Object?>;
      expect((decoded['hookSpecificOutput'] as Map)['additionalContext'],
          taskAdditionalContext);
    });

    test('multiple invocations append rows (counter behaviour)', () async {
      for (var i = 0; i < 3; i++) {
        await _run(
          env: env,
          stdinStream: _payload({
            'session_id': 'sess-$i',
            'cwd': '/proj/multi',
          }),
        );
      }
      final db = FlartDatabase.open(path: dbPath);
      addTearDown(db.dispose);
      expect(SubagentActivationRepo(db).count(), 3);
    });
  });
}
