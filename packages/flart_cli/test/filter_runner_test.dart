// ignore_for_file: depend_on_referenced_packages

@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flart_cli/filter_runner.dart';
import 'package:flart_core/flart_core.dart';
import 'package:flart_filters/flart_filters.dart';
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

/// A filter whose native command is a fixed shell script and whose
/// transformation is whatever the test injects.
class _ScriptFilter implements CommandFilter {
  @override
  final String name;
  @override
  final String flartCommand;
  final List<String> _native;
  final FilterResult Function(String stdout, String stderr, int exit) _xform;

  _ScriptFilter({
    required this.name,
    required this.flartCommand,
    required List<String> native,
    required FilterResult Function(String stdout, String stderr, int exit)
        xform,
  })  : _native = native,
        _xform = xform;

  @override
  List<String> baseNativeCommand(List<String> userArgs) => _native;

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) =>
      _xform(stdout, stderr, exitCode);
}

void main() {
  late Directory tmp;
  late FlartDatabase db;
  late InvocationTracker tracker;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flart_runner_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    db = FlartDatabase.open();
    addTearDown(db.dispose);
    tracker = InvocationTracker(
      repo: InvocationRepo(db),
      estimator: const TokenEstimator(),
      project: const ProjectContext(
        root: '/proj',
        hasFlutterProject: true,
      ),
      env: const FlartEnv({}),
    );
  });

  group('FilterRunner anti-bloat', () {
    test('filter output bigger than raw → raw is written instead', () async {
      final out = _CapturingSink();
      final runner = FilterRunner(
        filter: _ScriptFilter(
          name: 'echo_bloat',
          flartCommand: 'echo',
          native: const ['bash', '-c', "printf 'short raw'"],
          xform: (s, e, c) => FilterResult(
            output:
                'this filtered output is intentionally much longer than the raw and should be discarded by the runner',
          ),
        ),
        tracker: tracker,
        stdoutSink: out,
      );
      final code = await runner.run(const []);
      expect(code, 0);
      // The agent must see the raw (smaller) output, not the bloated filter.
      expect(out.buffer.toString(), 'short raw\n');
      // DB must agree.
      final row = InvocationRepo(db).findRange().single;
      expect(row.filteredBytes, utf8.encode(out.buffer.toString()).length);
    });

    test('filter output smaller than raw → filter wins', () async {
      final out = _CapturingSink();
      final runner = FilterRunner(
        filter: _ScriptFilter(
          name: 'echo_filter',
          flartCommand: 'echo',
          native: const [
            'bash',
            '-c',
            "printf 'long raw line a\\nlong raw line b\\nlong raw line c'",
          ],
          xform: (s, e, c) => const FilterResult(output: 'ok'),
        ),
        tracker: tracker,
        stdoutSink: out,
      );
      await runner.run(const []);
      expect(out.buffer.toString(), 'ok\n');
      final row = InvocationRepo(db).findRange().single;
      expect(row.filteredBytes, 3); // "ok\n"
      expect(row.rawBytes, greaterThan(row.filteredBytes));
    });

    test('filter output equal to raw → raw wins (no negative-savings)',
        () async {
      final out = _CapturingSink();
      final runner = FilterRunner(
        filter: _ScriptFilter(
          name: 'echo_equal',
          flartCommand: 'echo',
          native: const ['bash', '-c', "printf 'same\\n'"],
          // Length 5 ("same\n") — exactly equal once we add the wrapper newline.
          xform: (s, e, c) => const FilterResult(output: 'samex'),
        ),
        tracker: tracker,
        stdoutSink: out,
      );
      await runner.run(const []);
      // "samex\n" = 6 vs raw "same\n" = 5. Filter is bigger; raw should win.
      expect(out.buffer.toString(), 'same\n');
    });

    test('empty raw → filter wins (preserves friendly "no output" message)',
        () async {
      final out = _CapturingSink();
      final runner = FilterRunner(
        filter: _ScriptFilter(
          name: 'echo_empty',
          flartCommand: 'echo',
          native: const ['bash', '-c', 'true'],
          xform: (s, e, c) => const FilterResult(output: 'No issues.'),
        ),
        tracker: tracker,
        stdoutSink: out,
      );
      await runner.run(const []);
      // Even though "No issues.\n" (11) > raw "" (0), the agent should see
      // the helpful message rather than blank output.
      expect(out.buffer.toString(), 'No issues.\n');
    });
  });

  group('FilterRunner tee integration', () {
    late Directory teeDir;
    late TeeManager tee;

    setUp(() {
      teeDir = Directory.systemTemp.createTempSync('flart_tee_test_');
      addTearDown(() => teeDir.deleteSync(recursive: true));
      tee = TeeManager(
        config: TeeConfig(
          enabled: true,
          mode: TeeMode.failures,
          directory: teeDir.path,
          maxFiles: 30,
          maxFileSizeMb: 5,
          // Force tee to fire on small fixtures.
          minSizeBytes: 0,
        ),
        teeDirectory: teeDir.path,
      );
    });

    test('failure writes a tee file and appends a hint to the agent output',
        () async {
      final out = _CapturingSink();
      final runner = FilterRunner(
        filter: _ScriptFilter(
          name: 'echo_fail',
          flartCommand: 'echo',
          native: const [
            'bash',
            '-c',
            "printf 'noisy\\nraw\\nfailure\\noutput'; exit 2",
          ],
          xform: (s, e, c) =>
              const FilterResult(output: 'FAILED: 1/1 (exit 2)'),
        ),
        tracker: tracker,
        tee: tee,
        stdoutSink: out,
      );
      final code = await runner.run(const []);
      expect(code, 2);
      expect(out.buffer.toString(), contains('FAILED: 1/1 (exit 2)'));
      expect(out.buffer.toString(), contains('[full output: '));

      final logs = teeDir
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).endsWith('.log'))
          .toList();
      expect(logs.length, 1);
      final teeContent = logs.single.readAsStringSync();
      expect(teeContent, contains('noisy'));
      expect(teeContent, contains('---STDERR---'));

      final row = InvocationRepo(db).findRange().single;
      expect(row.teePath, isNotNull);
      expect(p.basename(row.teePath!), p.basename(logs.single.path));
      // DB filtered_bytes must include the tee-hint line (single source of
      // truth: what the agent saw on stdout).
      expect(row.filteredBytes,
          utf8.encode(out.buffer.toString()).length);
    });

    test('success path does not tee in mode=failures', () async {
      final out = _CapturingSink();
      final runner = FilterRunner(
        filter: _ScriptFilter(
          name: 'echo_pass',
          flartCommand: 'echo',
          native: const ['bash', '-c', "printf 'ok'"],
          xform: (s, e, c) => const FilterResult(output: 'ok'),
        ),
        tracker: tracker,
        tee: tee,
        stdoutSink: out,
      );
      await runner.run(const []);
      expect(out.buffer.toString(), isNot(contains('[full output:')));
      final logs = teeDir
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).endsWith('.log'))
          .toList();
      expect(logs, isEmpty);
    });
  });
}
