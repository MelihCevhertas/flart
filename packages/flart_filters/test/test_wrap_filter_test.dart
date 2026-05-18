// ignore_for_file: depend_on_referenced_packages

import 'package:flart_filters/flart_filters.dart';
import 'package:test/test.dart';

void main() {
  group('TestWrapFilter', () {
    test('all-pass jest-style summary collapses', () {
      const stdout = '''
> test
Test Suites: 3 passed, 3 total
Tests:       12 passed, 12 total
Snapshots:   0 total
Time:        2.3s
Ran all test suites.
''';
      final r = TestWrapFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, startsWith('PASSED 12/12 tests'));
      expect(r.metadata['passed'], 12);
      expect(r.metadata['failed'], 0);
    });

    test('failures surface FAIL/✗ lines and counts', () {
      const stdout = '''
FAIL test/login_test.dart
  ✗ rejects invalid email
  ✓ accepts valid email
FAIL test/cart_test.dart
  ✗ totals correctly

Tests:       2 failed, 5 passed, 7 total
''';
      final r = TestWrapFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 1,
        userArgs: const [],
      );
      expect(r.output, startsWith('FAILED 2/7 tests'));
      expect(r.output, contains('FAIL test/login_test.dart'));
      expect(r.output, contains('✗ rejects invalid email'));
      expect(r.output, contains('Passed: 5'));
      expect(r.output, contains('Failed: 2'));
      expect(r.metadata['failed'], 2);
    });

    test('baseNativeCommand passes userArgs through', () {
      expect(
        TestWrapFilter().baseNativeCommand(const ['npm', 'test']),
        ['npm', 'test'],
      );
    });
  });
}
