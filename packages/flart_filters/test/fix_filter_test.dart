// ignore_for_file: depend_on_referenced_packages

import 'package:flart_filters/flart_filters.dart';
import 'package:test/test.dart';

import 'fixture_helper.dart';

void main() {
  group('FixFilter — fixture-driven', () {
    test('"Nothing to fix!" collapses to "no fixes needed"', () {
      final body = readFixture('fix_dry_run_nothing.txt');
      final r = FixFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, 'no fixes needed');
      expect(r.metadata['nothing_to_fix'], isTrue);
      expect(r.metadata['files'], 0);
    });

    test('single-file fix collapses to rule-summary form', () {
      final body = readFixture('fix_dry_run_with_fixes.txt');
      final r = FixFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('1 proposed fix in 1 file.'));
      expect(r.output, contains('unused_import [1 in 1 file]'));
      // Per-file detail should NOT be in the output (rule-summary mode).
      expect(r.output, isNot(contains('lib/main.dart')));
      // Hint block stays dropped.
      expect(r.output, isNot(contains('To fix')));
      expect(r.metadata['mode'], 'dry_run');
      expect(r.metadata['files'], 1);
      expect(r.metadata['rules'], 1);
      expect(r.metadata['fixes'], 1);
    });

    test('many-file fix aggregates by rule, sorted by fix count desc', () {
      final body = readFixture('fix_dry_run_many_files.txt');
      final r = FixFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      // unnecessary_underscores 6 in 5 files; others 1 each.
      expect(r.output, contains('8 proposed fixes in 6 files.'));
      expect(r.output, contains('unnecessary_underscores [6 in 5 files]'));
      expect(r.output, contains('prefer_const_constructors [1 in 1 file]'));
      expect(r.output, contains('unused_import [1 in 1 file]'));
      // Sort order: unnecessary_underscores first (highest count).
      final us = r.output.indexOf('unnecessary_underscores');
      final pc = r.output.indexOf('prefer_const_constructors');
      expect(us, lessThan(pc),
          reason: 'higher fix count must come first');
      // Per-file paths must NOT bleed through.
      expect(r.output, isNot(contains('lib/_tools/')));
      expect(r.output, isNot(contains('lib/ui/common/')));

      expect(r.metadata['rules'], 3);
      expect(r.metadata['files'], 6);
      expect(r.metadata['fixes'], 8);
    });
  });

  group('FixFilter — --apply mode', () {
    test('apply-mode summary recognised + rule-summary collapse', () {
      const stdout = '''
Computing fixes in app...

3 fixes made in 2 files.

lib/main.dart
  unused_import - 1 fix
  prefer_const - 1 fix

lib/util.dart
  prefer_const - 1 fix
''';
      final r = FixFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const ['--apply'],
      );
      expect(r.output, contains('3 fixes made in 2 files.'));
      expect(r.output, contains('prefer_const [2 in 2 files]'));
      expect(r.output, contains('unused_import [1 in 1 file]'));
      expect(r.metadata['mode'], 'apply');
      expect(r.metadata['files'], 2);
      expect(r.metadata['rules'], 2);
      expect(r.metadata['fixes'], 3);
    });
  });

  group('FixFilter — CommandFilter contract', () {
    test('default mode adds --dry-run; --apply passes through', () {
      expect(
        FixFilter().baseNativeCommand(const []),
        ['dart', 'fix', '--dry-run'],
      );
      expect(
        FixFilter().baseNativeCommand(const ['--apply']),
        ['dart', 'fix', '--apply'],
      );
    });

    test('name/flartCommand', () {
      final f = FixFilter();
      expect(f.name, 'fix');
      expect(f.flartCommand, 'fix');
    });
  });
}
