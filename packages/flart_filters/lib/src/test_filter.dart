import 'dart:convert';

import 'filter.dart';
import 'filter_result.dart';
import 'filter_utils.dart';

/// `flart test` — wraps `flutter test --reporter=json` (or `dart test`).
/// Plan 5.4.2.
///
/// Parses the JSON event stream defensively (unknown event types are
/// silently dropped, malformed lines skipped — Plan Section 13.5).
///
/// Output policy:
/// - All-pass run collapses to a single `PASSED N/N tests in Xs` line.
/// - Any failure/error: per-failure block with name, source file, error
///   message, and the first stack frame (if any).
class TestFilter implements CommandFilter {
  /// `true` → `flutter test --reporter=json` (Flutter projects).
  /// `false` → `dart test --reporter=json` (pure-Dart packages).
  /// Detection is the CLI's job; the filter just dispatches.
  final bool isFlutterProject;

  /// Per-failure error message cap. Plan Section 3.2 default 300; pass 0 to
  /// disable. Long `Expected:`/`Actual:` blocks and `boom` exceptions get
  /// trimmed.
  final int truncateMessagesAt;

  TestFilter({this.isFlutterProject = true, this.truncateMessagesAt = 300});

  @override
  String get name => 'test';

  @override
  String get flartCommand => 'test';

  @override
  List<String> baseNativeCommand(List<String> userArgs) => isFlutterProject
      ? const ['flutter', 'test', '--reporter=json']
      : const ['dart', 'test', '--reporter=json'];

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) {
    final tests = <int, _TestState>{};
    final suitesById = <int, String>{};
    final loadingTestIds = <int>{};
    num? doneTimeMs;

    for (final raw in stdout.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || !line.startsWith('{')) continue;
      Object? decoded;
      try {
        decoded = jsonDecode(line);
      } on FormatException {
        continue;
      }
      if (decoded is! Map) continue;
      final type = decoded['type'];
      switch (type) {
        case 'suite':
          final s = decoded['suite'];
          if (s is Map && s['id'] is int) {
            suitesById[s['id'] as int] = (s['path'] as String?) ?? '?';
          }
        case 'testStart':
          final t = decoded['test'];
          if (t is! Map) break;
          final id = t['id'];
          if (id is! int) break;
          final groupIDs = t['groupIDs'];
          // The synthetic "loading test/foo.dart" pseudo-test arrives with
          // an empty groupIDs list. Track it so subsequent testDone/error
          // events for that id can be discarded.
          if (groupIDs is! List || groupIDs.isEmpty) {
            loadingTestIds.add(id);
            break;
          }
          tests[id] = _TestState(
            id: id,
            name: (t['name'] as String?) ?? '<unnamed>',
            suiteId: t['suiteID'] is int ? t['suiteID'] as int : null,
            url: t['url'] as String?,
          );
        case 'testDone':
          final id = decoded['testID'];
          if (id is! int || loadingTestIds.contains(id)) break;
          final st = tests[id];
          if (st != null) {
            st.result = (decoded['result'] as String?) ?? 'success';
            st.skipped = decoded['skipped'] == true;
          }
        case 'error':
          final id = decoded['testID'];
          if (id is! int || loadingTestIds.contains(id)) break;
          final st = tests[id];
          if (st != null) {
            st.errorMessage = decoded['error'] as String?;
            st.stackTrace = decoded['stackTrace'] as String?;
            st.isFailure = decoded['isFailure'] == true;
          }
        case 'print':
          final id = decoded['testID'];
          if (id is! int || loadingTestIds.contains(id)) break;
          final st = tests[id];
          if (st != null) {
            final msg = decoded['message'] as String?;
            if (msg != null) st.prints.add(msg);
          }
        case 'done':
          final t = decoded['time'];
          doneTimeMs = t is num ? t : null;
        // Unknown event types (start, allSuites, group, ...) are ignored.
      }
    }

    final all = tests.values.toList(growable: false);
    final passed = all
        .where((t) => t.result == 'success' && !t.skipped)
        .length;
    final failures = all
        .where((t) => t.result == 'failure')
        .toList(growable: false);
    final errors = all
        .where((t) => t.result == 'error')
        .toList(growable: false);
    final skipped = all.where((t) => t.skipped).length;
    final durationSecs = doneTimeMs != null
        ? (doneTimeMs / 1000).toStringAsFixed(1)
        : '?';

    final metadata = <String, Object?>{
      'tests_total': all.length,
      'passed': passed,
      'failed': failures.length,
      'error': errors.length,
      'skipped': skipped,
      if (doneTimeMs != null) 'duration_ms': doneTimeMs.round(),
    };

    final failedOrError = [...failures, ...errors];
    if (failedOrError.isEmpty) {
      final out = StringBuffer('PASSED ${all.length}/${all.length} tests');
      if (durationSecs != '?') out.write(' in ${durationSecs}s');
      if (skipped > 0) out.write(' ($skipped skipped)');
      return FilterResult(output: out.toString(), metadata: metadata);
    }

    final buf = StringBuffer();
    buf.write(
        'FAILED ${failedOrError.length}/${all.length} tests');
    if (durationSecs != '?') buf.write(' in ${durationSecs}s');
    buf.writeln();

    // Group failures by suite path for readability.
    final bySuite = <String, List<_TestState>>{};
    for (final t in failedOrError) {
      final suite = (t.suiteId != null ? suitesById[t.suiteId!] : null) ??
          t.url ??
          '<unknown suite>';
      bySuite.putIfAbsent(suite, () => []).add(t);
    }

    for (final entry in bySuite.entries) {
      buf.writeln();
      buf.writeln('✗ ${entry.key}');
      for (final t in entry.value) {
        buf.writeln('  - ${t.name}');
        if (t.errorMessage != null) {
          final msg = FilterUtils.truncateMessage(
            t.errorMessage!.trim(),
            truncateMessagesAt,
          );
          for (final line in _indent(msg, '    ')) {
            buf.writeln(line);
          }
        }
        final firstFrame = _firstStackFrame(t.stackTrace);
        if (firstFrame != null) buf.writeln('    Stack: $firstFrame');
        for (final msg in t.prints) {
          for (final line in _indent('print: ${msg.trimRight()}', '    ')) {
            buf.writeln(line);
          }
        }
      }
    }

    buf.writeln();
    buf.write(
      'Passed: $passed  Failed: ${failures.length}  '
      'Error: ${errors.length}  Skipped: $skipped',
    );
    return FilterResult(
      output: buf.toString(),
      metadata: metadata,
      wasTruncated: false,
    );
  }

  static Iterable<String> _indent(String text, String prefix) sync* {
    for (final line in text.split('\n')) {
      yield '$prefix$line';
    }
  }

  static String? _firstStackFrame(String? trace) {
    if (trace == null) return null;
    for (final raw in trace.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      // package:test internals are noise; skip to the first user frame.
      if (line.contains('package:test/') ||
          line.contains('package:matcher/') ||
          line.contains('dart:async') ||
          line.startsWith('<asynchronous suspension>')) {
        continue;
      }
      return line;
    }
    return null;
  }
}

class _TestState {
  final int id;
  final String name;
  final int? suiteId;
  final String? url;
  String? result;
  bool skipped = false;
  String? errorMessage;
  String? stackTrace;
  bool isFailure = false;
  final List<String> prints = [];

  _TestState({
    required this.id,
    required this.name,
    this.suiteId,
    this.url,
  });
}
