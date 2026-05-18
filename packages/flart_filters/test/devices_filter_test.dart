// ignore_for_file: depend_on_referenced_packages

import 'package:flart_filters/flart_filters.dart';
import 'package:test/test.dart';

import 'fixture_helper.dart';

void main() {
  group('DevicesFilter — fixture-driven', () {
    test('typical fixture keeps device rows, drops footer', () {
      final stdout = readFixture('devices_typical.txt');
      final r = DevicesFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('2 devices connected'));
      expect(r.output, contains('macOS (desktop)'));
      expect(r.output, contains('Chrome (web)'));
      // Footer noise must be dropped.
      expect(r.output, isNot(contains('Run "flutter emulators"')));
      expect(r.output, isNot(contains('please run "flutter doctor"')));
      expect(r.metadata['found'], 2);
    });
  });

  group('DevicesFilter — empty', () {
    test('no devices', () {
      const stdout =
          'No supported devices connected.\n\nRun "flutter emulators"...';
      final r = DevicesFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('no devices connected'));
    });
  });
}
