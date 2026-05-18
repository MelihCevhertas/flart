// ignore_for_file: depend_on_referenced_packages

import 'package:flart_filters/flart_filters.dart';
import 'package:test/test.dart';

void main() {
  group('ErrFilter', () {
    test('keeps error/FAILED lines + immediate stack frames', () {
      const stdout = '''
Starting build...
Compiling foo.dart
ERROR: lib/foo.dart:5:10
The argument type 'int' can't be assigned.
    at package:foo/bar.dart:18:14
    at file:///x.dart:22:1
Some unrelated info line
FAILURE: Build failed with an exception.
BUILD FAILED in 3s
''';
      final r = ErrFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 1,
        userArgs: const [],
      );
      expect(r.output, contains('ERROR: lib/foo.dart:5:10'));
      expect(r.output, contains('FAILURE: Build failed'));
      expect(r.output, contains('FAILED'));
      expect(r.output, contains('package:foo/bar.dart:18:14'));
      // Non-marker info lines must be dropped.
      expect(r.output, isNot(contains('Starting build')));
      expect(r.output, isNot(contains('Some unrelated info')));
      expect(r.metadata['matches'], greaterThan(0));
    });

    test('matches Dart frontend file:line:col format on its own line', () {
      const stderr = '''
lib/x.dart:3:12: Error: bad
String s = 42;
package:foo/bar.dart:7:8: Error: more bad
''';
      final r = ErrFilter().filter(
        stdout: '',
        stderr: stderr,
        exitCode: 1,
        userArgs: const [],
      );
      expect(r.output, contains('lib/x.dart:3:12'));
      expect(r.output, contains('package:foo/bar.dart:7:8'));
    });

    test('success run with no markers returns "no errors detected"', () {
      final r = ErrFilter().filter(
        stdout: 'all good\nproceeding\ndone\n',
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, 'no errors detected');
    });

    test('non-zero exit with no markers still reports exit code', () {
      final r = ErrFilter().filter(
        stdout: 'ok\n',
        stderr: '',
        exitCode: 2,
        userArgs: const [],
      );
      expect(r.output, contains('exit 2'));
    });

    test('baseNativeCommand passes userArgs through verbatim', () {
      expect(
        ErrFilter().baseNativeCommand(const ['git', 'status']),
        ['git', 'status'],
      );
    });
  });
}
