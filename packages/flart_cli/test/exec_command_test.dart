// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flart_cli/commands/exec_command.dart';
import 'package:flart_cli/runner.dart';
import 'package:flart_core/flart_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Minimal IOSink stand-in that records every write into a [StringBuffer].
/// Used for capturing what the CLI would print to stdout/stderr.
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

Future<({int code, String stdout, String stderr})> _run(
  List<String> args, {
  FlartEnv? env,
  Stream<List<int>>? stdinStream,
}) async {
  final outSink = _CapturingSink();
  final errSink = _CapturingSink();
  final code = await runFlart(
    args,
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

FlartEnv _isolatedEnv(Directory tmp) => FlartEnv({
      // Both data and home at tmp so no real user files are touched.
      'FLART_DATA_DIR': tmp.path,
      'HOME': tmp.path,
    });

void main() {
  group('parseSize', () {
    test('plain integer', () {
      expect(parseSize('1024'), 1024);
      expect(parseSize('65536'), 65536);
    });

    test('k suffix multiplies by 1024', () {
      expect(parseSize('32k'), 32 * 1024);
      expect(parseSize('1K'), 1024);
    });

    test('m suffix multiplies by 1024 * 1024', () {
      expect(parseSize('1m'), 1024 * 1024);
      expect(parseSize('2M'), 2 * 1024 * 1024);
    });

    test('whitespace tolerated', () {
      expect(parseSize('  16k  '), 16 * 1024);
    });

    test('empty / zero / negative / garbage throws', () {
      expect(() => parseSize(''), throwsFormatException);
      expect(() => parseSize('0'), throwsFormatException);
      expect(() => parseSize('-5'), throwsFormatException);
      expect(() => parseSize('abc'), throwsFormatException);
      expect(() => parseSize('5g'), throwsFormatException);
    });
  });

  group('exec command — usage errors', () {
    test('missing runtime → exit 100 (usage)', () async {
      final r = await _run(['exec']);
      expect(r.code, 100);
    });

    test('unknown runtime → exit 100 (usage)', () async {
      final r = await _run(['exec', 'ruby', "puts 'hi'"]);
      expect(r.code, 100);
    });

    test('no input mode → exit 100 (usage)', () async {
      final r = await _run(['exec', 'bash']);
      expect(r.code, 100);
    });

    test('--file + positional code → exit 100 (mutually exclusive)', () async {
      final r = await _run(
        ['exec', 'bash', "echo hi", '--file', '/tmp/foo.sh'],
      );
      expect(r.code, 100);
    });
  });

  group('exec command — runtime + savings integration', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('flart_exec_cli_');
      addTearDown(() => tmp.deleteSync(recursive: true));
    });

    test('positional code runs and records to savings DB', () async {
      final env = _isolatedEnv(tmp);
      final r = await _run(
        ['exec', 'bash', 'echo hello-from-cli'],
        env: env,
      );
      expect(r.code, 0);
      expect(r.stdout, contains('hello-from-cli'));

      final db = FlartDatabase.open(path: p.join(tmp.path, 'savings.db'));
      addTearDown(db.dispose);
      final rows = InvocationRepo(db).findRange();
      expect(rows.length, 1);
      final row = rows.single;
      expect(row.module, 'executor');
      expect(row.command, 'exec');
      expect(row.args, 'bash');
      expect(row.exitCode, 0);
      expect(row.metadata, isNotNull);
      expect(row.metadata!['runtime'], 'bash');
      expect(row.metadata!['timed_out'], isFalse);
      expect(row.estFiltTokens, greaterThan(0));
    }, tags: 'integration');

    test('--file mode reads script from disk and records', () async {
      final env = _isolatedEnv(tmp);
      final scriptPath = p.join(tmp.path, 'script.sh');
      File(scriptPath).writeAsStringSync('echo via-file');

      final r = await _run(
        ['exec', 'bash', '--file', scriptPath],
        env: env,
      );
      expect(r.code, 0);
      expect(r.stdout, contains('via-file'));
    }, tags: 'integration');

    test('--stdin mode reads script from stdin and records', () async {
      final env = _isolatedEnv(tmp);
      final stdinData = Stream<List<int>>.fromIterable([
        'echo via-stdin'.codeUnits,
      ]);
      final r = await _run(
        ['exec', 'bash', '--stdin'],
        env: env,
        stdinStream: stdinData,
      );
      expect(r.code, 0);
      expect(r.stdout, contains('via-stdin'));
    }, tags: 'integration');

    test('FLART_NO_SAVINGS=1 means no row written but exit still 0', () async {
      final env = FlartEnv({
        'FLART_DATA_DIR': tmp.path,
        'HOME': tmp.path,
        'FLART_NO_SAVINGS': '1',
      });
      final r = await _run(
        ['exec', 'bash', 'echo silent'],
        env: env,
      );
      expect(r.code, 0);
      expect(r.stdout, contains('silent'));

      final db = FlartDatabase.open(path: p.join(tmp.path, 'savings.db'));
      addTearDown(db.dispose);
      expect(InvocationRepo(db).count(), 0);
    }, tags: 'integration');

    test('non-zero exit code is passed through', () async {
      final env = _isolatedEnv(tmp);
      final r = await _run(
        ['exec', 'bash', 'exit 3'],
        env: env,
      );
      expect(r.code, 3);
    }, tags: 'integration');

    test('missing --file path → exit 101', () async {
      final env = _isolatedEnv(tmp);
      final r = await _run(
        [
          'exec',
          'bash',
          '--file',
          '/tmp/flart-not-real-${DateTime.now().microsecondsSinceEpoch}.sh',
        ],
        env: env,
      );
      expect(r.code, 101);
    });
  });
}
