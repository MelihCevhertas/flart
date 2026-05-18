// ignore_for_file: depend_on_referenced_packages

import 'package:flart_filters/flart_filters.dart';
import 'package:test/test.dart';

import 'fixture_helper.dart';

void main() {
  group('PubOutdatedFilter — JSON fixture', () {
    test('lists only packages whose current != latest', () {
      final stdout = readFixture('pub_outdated.json');
      final r = PubOutdatedFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('4 package(s) outdated'));
      expect(r.output, contains('matcher'));
      expect(r.output, contains('0.12.19'));
      expect(r.output, contains('0.12.20'));
      expect(r.output, contains('1.17.0 → 1.18.2'));
      expect(r.metadata['outdated'], 4);
      // Lines like "version solving" / "Showing outdated" must NOT bleed in.
      expect(r.output, isNot(contains('"package"')));
    });
  });

  group('PubOutdatedFilter — text fallback', () {
    test('parses tabular text when JSON not requested', () {
      final stdout = readFixture('pub_outdated_text.txt');
      final r = PubOutdatedFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const ['--no-json'],
      );
      expect(r.output, contains('package(s) outdated'));
      expect(r.metadata['outdated'], greaterThan(0));
    });
  });

  group('PubOutdatedFilter — synthetic no-outdated', () {
    test('all up to date collapses to "all dependencies are up to date"', () {
      const stdout = '{"packages":[]}';
      final r = PubOutdatedFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, 'all dependencies are up to date');
      expect(r.metadata['outdated'], 0);
    });
  });

  group('PubOutdatedFilter — CommandFilter contract', () {
    test('Flutter vs pure-Dart + --json injection', () {
      expect(
        PubOutdatedFilter().baseNativeCommand(const []),
        ['flutter', 'pub', 'outdated', '--json'],
      );
      expect(
        PubOutdatedFilter(isFlutterProject: false)
            .baseNativeCommand(const ['--no-json']),
        ['dart', 'pub', 'outdated'],
      );
    });
  });
}
