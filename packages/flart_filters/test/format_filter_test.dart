// ignore_for_file: depend_on_referenced_packages

import 'package:flart_filters/flart_filters.dart';
import 'package:test/test.dart';

import 'fixture_helper.dart';

void main() {
  group('FormatFilter — fixture-driven', () {
    test('default mode: "Formatted <path>" rows kept, summary kept', () {
      final body = readFixture('format_default_some_changed.txt');
      final r = FormatFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('changed: lib/needs_format.dart'));
      expect(r.output, contains('Formatted 2 files (1 changed)'));
      expect(r.metadata['files_changed'], 1);
    });

    test('dry-run mode: "Changed <path>" rows kept, "Unchanged" dropped', () {
      final body = readFixture('format_dryrun_some_changed.txt');
      final r = FormatFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('changed: lib/needs_format.dart'));
      // The fixture only contains 'Changed' for needs_format and the summary
      // (already_formatted is omitted when unchanged in default output);
      // dry-run output may print "Unchanged" rows which the filter discards.
      expect(r.output, isNot(contains('Unchanged')));
      expect(r.metadata['files_changed'], 1);
    });

    test('all unchanged collapses to "ok"', () {
      final body = readFixture('format_all_unchanged.txt');
      final r = FormatFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, startsWith('ok'));
      expect(r.metadata['files_changed'], 0);
    });
  });

  group('FormatFilter — defensive parsing', () {
    test('blank and unknown lines are dropped', () {
      const stdout = '''
Formatted lib/a.dart

random vendor message
Formatted lib/b.dart
Formatted 2 files (2 changed) in 0.10 seconds.
''';
      final r = FormatFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('changed: lib/a.dart'));
      expect(r.output, contains('changed: lib/b.dart'));
      expect(r.output, isNot(contains('random vendor message')));
      expect(r.metadata['files_changed'], 2);
    });
  });

  group('FormatFilter — CommandFilter contract', () {
    test('exposes correct name/baseNativeCommand', () {
      final f = FormatFilter();
      expect(f.name, 'format');
      expect(f.flartCommand, 'format');
      expect(f.baseNativeCommand(const []), ['dart', 'format']);
    });
  });
}
