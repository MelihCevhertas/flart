// ignore_for_file: depend_on_referenced_packages

import 'package:flart_filters/flart_filters.dart';
import 'package:test/test.dart';

import 'fixture_helper.dart';

void main() {
  group('AnalyzeFilter — fixture-driven', () {
    test('clean fixture → "No issues." with zero metadata', () {
      final body = readFixture('analyze_clean.txt');
      final result = AnalyzeFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(result.output, 'No issues.');
      expect(result.metadata['errors'], 0);
      expect(result.metadata['warnings_total'], 0);
      expect(result.metadata['warnings_unique'], 0);
      expect(result.metadata['infos_suppressed'], 0);
    });

    test('errors fixture → ERRORS section with detail, no WARNINGS', () {
      final body = readFixture('analyze_errors.txt');
      final result = AnalyzeFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 3,
        userArgs: const [],
      );
      expect(result.output, contains('ERRORS (2)'));
      expect(result.output, contains('invalid_assignment'));
      expect(result.output, contains('undefined_method'));
      expect(result.output, contains('lib/errors.dart'));
      // L2:14 and L3:5 from the fixture
      expect(result.output, contains('L2:14'));
      expect(result.output, contains('L3:5'));
      expect(result.output, isNot(contains('WARNINGS')));
      expect(result.metadata['errors'], 2);
      expect(result.metadata['warnings_total'], 0);
    });

    test('warnings fixture → WARNINGS grouped by code, count + files', () {
      final body = readFixture('analyze_warnings.txt');
      final result = AnalyzeFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 2,
        userArgs: const [],
      );
      expect(result.output, contains('WARNINGS (1 unique, 2 total)'));
      expect(result.output, contains('unused_local_variable [2]: in 1 file'));
      expect(result.output, isNot(contains('ERRORS')));
      expect(result.metadata['errors'], 0);
      expect(result.metadata['warnings_total'], 2);
      expect(result.metadata['warnings_unique'], 1);
    });

    test('mixed fixture → both sections render, ERRORS before WARNINGS', () {
      final body = readFixture('analyze_mixed.txt');
      final result = AnalyzeFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 3,
        userArgs: const [],
      );
      final errIdx = result.output.indexOf('ERRORS');
      final warnIdx = result.output.indexOf('WARNINGS');
      expect(errIdx, isNonNegative);
      expect(warnIdx, isNonNegative);
      expect(errIdx, lessThan(warnIdx),
          reason: 'ERRORS must come before WARNINGS');
      expect(result.metadata['errors'], 1);
      expect(result.metadata['warnings_total'], 1);
    });

    test('generated files bucketed separately', () {
      final body = readFixture('analyze_with_generated.txt');
      final result = AnalyzeFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 3,
        userArgs: const [],
      );
      expect(result.output, contains('Generated files:'));
      expect(result.output, contains('.g.dart'));
      // The generated-file row in the fixture is `lib/generated.g.dart` —
      // that file should not appear in the WARNINGS detail.
      expect(result.metadata['generated_suppressed'], greaterThan(0));
    });
  });

  group('AnalyzeFilter — truncate long messages', () {
    test('per-issue message is capped when over the limit', () {
      final longMsg = 'A' * 500;
      final stdout =
          'ERROR|COMPILE_TIME_ERROR|MY_CODE|/lib/x.dart|1|1|1|$longMsg';
      final r = AnalyzeFilter(truncateMessagesAt: 80).filter(
        stdout: stdout,
        stderr: '',
        exitCode: 3,
        userArgs: const [],
      );
      expect(r.output, contains('… (+420 chars)'));
      // Original full message must NOT be in the output anymore.
      expect(r.output, isNot(contains(longMsg)));
    });

    test('truncateMessagesAt=0 disables the cap', () {
      final longMsg = 'A' * 500;
      final stdout =
          'ERROR|COMPILE_TIME_ERROR|MY_CODE|/lib/x.dart|1|1|1|$longMsg';
      final r = AnalyzeFilter(truncateMessagesAt: 0).filter(
        stdout: stdout,
        stderr: '',
        exitCode: 3,
        userArgs: const [],
      );
      expect(r.output, contains(longMsg));
    });
  });

  group('AnalyzeFilter — defensive parsing', () {
    test('skips empty lines and malformed rows', () {
      const stdout = '''
ERROR|COMPILE_TIME_ERROR|INVALID_ASSIGNMENT|/lib/a.dart|1|1|1|Bad assignment.

ERROR|GARBAGE  this line has only 2 segments
not a pipe line at all
ERROR|COMPILE_TIME_ERROR|UNDEFINED_METHOD|/lib/b.dart|5|10|3|No foo().
''';
      final result = AnalyzeFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 3,
        userArgs: const [],
      );
      expect(result.metadata['errors'], 2,
          reason: 'two well-formed ERROR rows, malformed lines ignored');
    });

    test('handles pipe characters inside the message field', () {
      const stdout =
          'ERROR|COMPILE_TIME_ERROR|CUSTOM_RULE|/lib/x.dart|1|1|1|a | b | c';
      final result = AnalyzeFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 3,
        userArgs: const [],
      );
      expect(result.output, contains('a | b | c'));
    });
  });

  group('AnalyzeFilter — CommandFilter contract', () {
    test('exposes correct name and flartCommand', () {
      final f = AnalyzeFilter();
      expect(f.name, 'analyze');
      expect(f.flartCommand, 'analyze');
    });

    test('baseNativeCommand is `dart analyze --format=machine`', () {
      expect(
        AnalyzeFilter().baseNativeCommand(const []),
        ['dart', 'analyze', '--format=machine'],
      );
    });
  });
}
