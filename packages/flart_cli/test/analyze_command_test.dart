// ignore_for_file: depend_on_referenced_packages

@Tags(['integration'])
library;

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
  void write(Object? object) => buffer.write(object);
  @override
  void writeln([Object? object = '']) => buffer.writeln(object);
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      buffer.writeAll(objects, separator);
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

Future<({int code, String stdout, String stderr})> _runAnalyze(
  List<String> args, {
  required Directory tmp,
}) async {
  final out = _CapturingSink();
  final err = _CapturingSink();
  final env = FlartEnv({
    'FLART_DATA_DIR': tmp.path,
    'HOME': tmp.path,
  });
  final code = await runFlart(
    args,
    envOverride: env,
    stdoutOverride: out,
    stderrOverride: err,
  );
  return (code: code, stdout: out.buffer.toString(), stderr: err.buffer.toString());
}

void main() {
  group('flart analyze (real `dart analyze`)', () {
    late Directory tmp;
    late Directory project;

    setUp(() {
      final originalCwd = Directory.current;
      tmp = Directory.systemTemp.createTempSync('flart_analyze_cli_');
      addTearDown(() {
        // Restore CWD before deleting tmp: macOS getcwd() crashes if the
        // process is left sitting in a removed directory.
        Directory.current = originalCwd;
        tmp.deleteSync(recursive: true);
      });
      project = Directory(p.join(tmp.path, 'project'))..createSync();
      Directory(p.join(project.path, 'lib')).createSync();
      File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('''
name: flart_analyze_lab
publish_to: none
version: 0.0.1
environment:
  sdk: ^3.5.0
''');
      // Work from inside the project so `dart analyze` finds its pubspec.
      Directory.current = project;
    });

    test('clean project reports "No issues." and exit 0', () async {
      File(p.join(project.path, 'lib', 'main.dart'))
          .writeAsStringSync("void main() => print('hi');\n");
      final r = await _runAnalyze(['analyze'], tmp: tmp);
      expect(r.code, 0);
      expect(r.stdout, contains('No issues.'));
    });

    test('error in code → ERRORS section, exit > 0, savings row recorded',
        () async {
      File(p.join(project.path, 'lib', 'main.dart')).writeAsStringSync('''
void main() {
  String s = 42;
  s.missingMethod();
}
''');
      final r = await _runAnalyze(['analyze'], tmp: tmp);
      expect(r.code, isNonZero);
      expect(r.stdout, contains('ERRORS'));
      expect(r.stdout, contains('invalid_assignment'));

      final db = FlartDatabase.open(path: p.join(tmp.path, 'savings.db'));
      addTearDown(db.dispose);
      final rows = InvocationRepo(db).findRange();
      expect(rows.length, 1);
      final row = rows.single;
      expect(row.module, 'filter');
      expect(row.command, 'analyze');
      expect(row.metadata!['errors'], greaterThan(0));
      expect(row.rawBytes, greaterThan(row.filteredBytes),
          reason: 'filter should shrink the raw output');
    });

    test('warning-only code → WARNINGS section, exit > 0', () async {
      File(p.join(project.path, 'lib', 'main.dart')).writeAsStringSync('''
void main() {
  final unused = 'x';
  print('hi');
}
''');
      final r = await _runAnalyze(['analyze'], tmp: tmp);
      expect(r.stdout, contains('WARNINGS'));
      expect(r.stdout, contains('unused_local_variable'));
    });

    test('DB filtered_bytes == captured stdout bytes (1-byte fix)', () async {
      File(p.join(project.path, 'lib', 'main.dart')).writeAsStringSync('''
void main() {
  String s = 42;
  final unused = 'x';
  s.foo();
}
''');
      final r = await _runAnalyze(['analyze'], tmp: tmp);

      final db = FlartDatabase.open(path: p.join(tmp.path, 'savings.db'));
      addTearDown(db.dispose);
      final row = InvocationRepo(db).findRange().single;
      final stdoutBytes = utf8.encode(r.stdout).length;
      expect(row.filteredBytes, stdoutBytes,
          reason:
              'DB filtered_bytes must equal what the agent received on stdout '
              '(no off-by-newline). Tracker stores the same string FilterRunner writes.');
    });
  });
}
