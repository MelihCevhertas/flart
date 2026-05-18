// ignore_for_file: depend_on_referenced_packages

import 'package:flart_filters/flart_filters.dart';
import 'package:test/test.dart';

import 'fixture_helper.dart';

void main() {
  group('PubUpgradeFilter — fixture-driven', () {
    test('no-change run says "no upgrades available"', () {
      final body = readFixture('pub_upgrade_clean.txt');
      final r = PubUpgradeFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, 'no upgrades available');
      expect(r.metadata['none_changed'], isTrue);
      expect(r.metadata['upgraded'], 0);
    });
  });

  group('PubUpgradeFilter — synthetic events', () {
    test('upgrades, additions, removals are bucketed and surfaced', () {
      const stdout = '''
Resolving dependencies...
Downloading packages...
~ foo 1.0.0 → 1.1.0
~ bar 2.0.0 → 2.2.0
+ baz 0.5.0
- qux (was 0.9.0)
> info 1.0.0 (1.5.0 available)
Changed 4 dependencies!
''';
      final r = PubUpgradeFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, startsWith('upgraded 4 dependencies'));
      expect(r.output, contains('~ foo'));
      expect(r.output, contains('~ bar'));
      expect(r.output, contains('+ baz'));
      expect(r.output, contains('- qux'));
      // "> info" is informational and must NOT appear.
      expect(r.output, isNot(contains('available')));
      expect(r.metadata['upgraded'], 2);
      expect(r.metadata['added'], 1);
      expect(r.metadata['removed'], 1);
    });

    test('failure surfaces error block', () {
      const stdout = '''
Resolving dependencies...
Because lab depends on foo ^99.0.0 which doesn't match any versions, version solving failed.
''';
      final r = PubUpgradeFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 1,
        userArgs: const [],
      );
      expect(r.output, startsWith('FAILED'));
      expect(r.output, contains('version solving failed'));
      expect(r.metadata['failed'], isTrue);
    });
  });

  group('PubUpgradeFilter — CommandFilter contract', () {
    test('Flutter vs pure-Dart baseNativeCommand', () {
      expect(
        PubUpgradeFilter().baseNativeCommand(const []),
        ['flutter', 'pub', 'upgrade'],
      );
      expect(
        PubUpgradeFilter(isFlutterProject: false).baseNativeCommand(const []),
        ['dart', 'pub', 'upgrade'],
      );
    });

    test('name/flartCommand', () {
      final f = PubUpgradeFilter();
      expect(f.name, 'pub_upgrade');
      expect(f.flartCommand, 'pub');
    });
  });
}
