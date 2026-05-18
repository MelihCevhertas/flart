// ignore_for_file: depend_on_referenced_packages

import 'package:flart_filters/flart_filters.dart';
import 'package:test/test.dart';

import 'fixture_helper.dart';

void main() {
  group('BuildFilter — apk success', () {
    test('extracts "✓ Built <path>" + total time', () {
      final stdout = readFixture('build_apk_success.txt');
      final r = BuildFilter(target: 'apk').filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('✓ Built'));
      expect(r.output, contains('build/app/outputs/flutter-apk/app-debug.apk'));
      expect(r.output, contains('38,4s'));
      expect(r.metadata['success'], isTrue);
      expect(r.metadata['target'], 'apk');
      expect(r.metadata['output_path'],
          'build/app/outputs/flutter-apk/app-debug.apk');
    });
  });

  group('BuildFilter — web success', () {
    test('extracts "✓ Built build/web" + Compile timing', () {
      final stdout = readFixture('build_web_success.stdout.txt');
      final stderr = readFixture('build_web_success.stderr.txt');
      final r = BuildFilter(target: 'web').filter(
        stdout: stdout,
        stderr: stderr,
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('✓ Built build/web'));
      expect(r.output, contains('11,6s'));
      // Wasm dry-run noise on stderr must NOT bleed into the filtered output.
      expect(r.output, isNot(contains('Wasm dry run')));
      expect(r.metadata['target'], 'web');
      expect(r.metadata['output_path'], 'build/web');
    });
  });

  group('BuildFilter — apk failure', () {
    test('keeps compile error file:line:col + message, summary line', () {
      final stdout = readFixture('build_apk_failure.stdout.txt');
      final stderr = readFixture('build_apk_failure.stderr.txt');
      final r = BuildFilter(target: 'apk').filter(
        stdout: stdout,
        stderr: stderr,
        exitCode: 1,
        userArgs: const [],
      );
      expect(r.output, startsWith('✗ Build failed (apk'));
      expect(r.output, contains('BUILD FAILED'));
      expect(r.output, contains('ERROR: lib/main.dart:3:12'));
      expect(r.output, contains("can't be assigned"));
      // Gradle daemon spam must NOT be present (tee carries the full log).
      expect(r.output, isNot(contains('* Try:')));
      expect(r.output, isNot(contains('--stacktrace')));
      expect(r.metadata['success'], isFalse);
      expect(r.metadata['errors'], 1);
    });
  });

  group('BuildFilter — truncate long error messages', () {
    test('per-error message respects truncateMessagesAt', () {
      final longMsg = 'A' * 500;
      final stderr = 'lib/foo.dart:1:1: Error: $longMsg';
      final r = BuildFilter(target: 'apk', truncateMessagesAt: 80).filter(
        stdout: '',
        stderr: stderr,
        exitCode: 1,
        userArgs: const [],
      );
      expect(r.output, contains('… (+420 chars)'));
      expect(r.output, isNot(contains(longMsg)));
    });
  });

  group('BuildFilter — CommandFilter contract', () {
    test('exposes correct name and baseNativeCommand per target', () {
      expect(BuildFilter(target: 'apk').name, 'build_apk');
      expect(BuildFilter(target: 'apk').flartCommand, 'build');
      expect(
        BuildFilter(target: 'apk').baseNativeCommand(const []),
        ['flutter', 'build', 'apk'],
      );
      expect(
        BuildFilter(target: 'web').baseNativeCommand(const []),
        ['flutter', 'build', 'web'],
      );
      expect(
        BuildFilter(target: 'ipa').baseNativeCommand(const []),
        ['flutter', 'build', 'ipa'],
      );
    });
  });

  group('BuildFilter — defensive parsing', () {
    test('unknown failure (no error block, no FAILED line) still summarises',
        () {
      final r = BuildFilter(target: 'apk').filter(
        stdout: '',
        stderr: 'some unrecognised gradle noise',
        exitCode: 7,
        userArgs: const [],
      );
      expect(r.output, contains('✗ Build failed (apk, exit 7)'));
      expect(r.metadata['errors'], 0);
    });
  });
}
