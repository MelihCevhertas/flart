// ignore_for_file: depend_on_referenced_packages

import 'package:flart_filters/flart_filters.dart';
import 'package:test/test.dart';

import 'fixture_helper.dart';

void main() {
  group('CompileFilter — fixture-driven', () {
    test('exe success extracts path', () {
      final stdout = readFixture('compile_exe_success.txt');
      final r = CompileFilter(target: 'exe').filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('✓ Compiled exe'));
      expect(r.output, contains('/tmp/dummy_compile'));
      expect(r.metadata['success'], isTrue);
      expect(r.metadata['target'], 'exe');
    });
  });

  group('CompileFilter — failure', () {
    test('non-zero exit surfaces stderr block', () {
      final r = CompileFilter(target: 'aot-snapshot').filter(
        stdout: '',
        stderr:
            'lib/main.dart:5:10: Error: Method not found: foo\nCompilation failed.',
        exitCode: 1,
        userArgs: const [],
      );
      expect(r.output, startsWith('✗ Compile failed (aot-snapshot'));
      expect(r.output, contains('Method not found'));
      expect(r.metadata['success'], isFalse);
    });
  });

  group('CompileFilter — CommandFilter contract', () {
    test('targets switch baseNativeCommand', () {
      expect(
        CompileFilter(target: 'exe').baseNativeCommand(const []),
        ['dart', 'compile', 'exe'],
      );
      expect(
        CompileFilter(target: 'js').baseNativeCommand(const []),
        ['dart', 'compile', 'js'],
      );
    });
  });
}
