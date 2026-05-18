// ignore_for_file: depend_on_referenced_packages

import 'package:flart_filters/flart_filters.dart';
import 'package:test/test.dart';

void main() {
  group('CleanFilter', () {
    test('successful run collapses to "ok"', () {
      final r = CleanFilter().filter(
        stdout:
            'Deleting build...\nDeleting .dart_tool...\nDeleting Generated.xcconfig...\n',
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, 'ok');
      expect(r.metadata['failed'], isFalse);
    });

    test('failure surfaces exit code and stderr hint', () {
      final r = CleanFilter().filter(
        stdout: '',
        stderr: 'Error: No pubspec.yaml file found.\nDid you forget to cd?',
        exitCode: 1,
        userArgs: const [],
      );
      expect(r.output, contains('FAILED'));
      expect(r.output, contains('exit 1'));
      expect(r.output, contains('No pubspec.yaml file found'));
      expect(r.metadata['failed'], isTrue);
    });

    test('failure with empty stderr still mentions exit code', () {
      final r = CleanFilter().filter(
        stdout: '',
        stderr: '',
        exitCode: 2,
        userArgs: const [],
      );
      expect(r.output, 'FAILED: flutter clean (exit 2)');
    });

    test('CommandFilter contract', () {
      final f = CleanFilter();
      expect(f.name, 'clean');
      expect(f.flartCommand, 'clean');
      expect(f.baseNativeCommand(const []), ['flutter', 'clean']);
    });
  });
}
