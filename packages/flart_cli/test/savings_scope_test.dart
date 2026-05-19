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

Future<({int code, String stdout, String stderr})> _runSavings(
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
    ['savings', ...args],
    envOverride: env,
    stdoutOverride: out,
    stderrOverride: err,
  );
  return (
    code: code,
    stdout: out.buffer.toString(),
    stderr: err.buffer.toString(),
  );
}

void _seed(String dbPath, List<({String project, int tokens})> rows) {
  final db = FlartDatabase.open(path: dbPath);
  try {
    final repo = InvocationRepo(db);
    for (final r in rows) {
      repo.insert(InvocationRecord(
        timestamp: DateTime.utc(2026, 5, 18, 12),
        projectPath: r.project,
        module: 'filter',
        command: 'analyze',
        rawBytes: r.tokens * 4,
        filteredBytes: (r.tokens * 4) ~/ 10,
        rawChars: r.tokens * 4,
        filteredChars: (r.tokens * 4) ~/ 10,
        estRawTokens: r.tokens,
        estFiltTokens: r.tokens ~/ 10,
        durationMs: 100,
        exitCode: 0,
      ));
    }
  } finally {
    db.dispose();
  }
}

void main() {
  group('flart savings scope (v0.2.0)', () {
    late Directory originalCwd;
    late Directory tmp;
    late Directory flutterProject;
    late Directory homeDir;
    late String dbPath;

    setUp(() {
      originalCwd = Directory.current;
      tmp = Directory.systemTemp.createTempSync('flart_savings_scope_');
      addTearDown(() {
        Directory.current = originalCwd;
        tmp.deleteSync(recursive: true);
      });
      homeDir = Directory(p.join(tmp.path, 'home'))..createSync();
      // A real Flutter-like project (has pubspec.yaml) we'll cd into.
      flutterProject = Directory(p.join(tmp.path, 'wonderous'))..createSync();
      File(p.join(flutterProject.path, 'pubspec.yaml'))
          .writeAsStringSync('name: wonderous\n');
      // ProjectContext.detect() resolves symlinks (macOS turns /var/folders
      // into /private/var/folders) — match that canonical form when seeding.
      final canonicalProject = flutterProject.resolveSymbolicLinksSync();
      dbPath = p.join(homeDir.path, 'savings.db');
      _seed(dbPath, [
        (project: canonicalProject, tokens: 1000),
        (project: canonicalProject, tokens: 2000),
        (project: '/some/other/project', tokens: 500),
        (project: '/yet/another', tokens: 300),
      ]);
    });

    test('--all reports across every project (legacy behaviour)', () async {
      Directory.current = flutterProject;
      final r = await _runSavings(
        ['--all'],
        tmp: homeDir,
      );
      expect(r.code, 0);
      // Cumulative invocation count = 4 (all rows).
      expect(r.stdout, contains('Invocations:        4'));
    });

    test('default (CWD inside Flutter project) scopes to that project root',
        () async {
      Directory.current = flutterProject;
      final r = await _runSavings(const [], tmp: homeDir);
      expect(r.code, 0);
      // Only the 2 rows for `wonderous` should be counted.
      expect(r.stdout, contains('Invocations:        2'));
      // No deprecation noise.
      expect(r.stderr, isNot(contains('deprecated')));
    });

    test('default (CWD outside any Flutter project) falls back to --all',
        () async {
      Directory.current = homeDir; // no pubspec.yaml here
      final r = await _runSavings(const [], tmp: homeDir);
      expect(r.code, 0);
      expect(r.stdout, contains('Invocations:        4'));
      expect(r.stderr, contains('not inside a Flutter/Dart project'));
    });

    test('--project-path scopes to the given path exactly', () async {
      Directory.current = homeDir;
      final r = await _runSavings(
        ['--project-path=/some/other/project'],
        tmp: homeDir,
      );
      expect(r.code, 0);
      expect(r.stdout, contains('Invocations:        1'));
    });

    test('--project (deprecated) still scopes to CWD and warns', () async {
      Directory.current = flutterProject;
      final r = await _runSavings(['--project'], tmp: homeDir);
      expect(r.code, 0);
      expect(r.stdout, contains('Invocations:        2'));
      expect(r.stderr, contains('--project is deprecated'));
    });

    test('--all and --project-path together → usage error', () async {
      Directory.current = flutterProject;
      final r = await _runSavings(
        ['--all', '--project-path=/x'],
        tmp: homeDir,
      );
      expect(r.code, 100);
      expect(r.stderr, contains('mutually exclusive'));
    });

    test('--all and --project together → usage error', () async {
      Directory.current = flutterProject;
      final r = await _runSavings(['--all', '--project'], tmp: homeDir);
      expect(r.code, 100);
      expect(r.stderr, contains('mutually exclusive'));
    });
  });
}
