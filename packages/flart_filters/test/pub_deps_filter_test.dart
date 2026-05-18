// ignore_for_file: depend_on_referenced_packages

import 'package:flart_filters/flart_filters.dart';
import 'package:test/test.dart';

import 'fixture_helper.dart';

void main() {
  group('PubDepsFilter — fixture-driven', () {
    test('default mode lists only direct deps', () {
      final stdout = readFixture('pub_deps_tree.txt');
      final r = PubDepsFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('direct dependencies'));
      expect(r.output, contains('cupertino_icons'));
      expect(r.output, contains('flutter'));
      expect(r.output, contains('flutter_lints'));
      expect(r.output, contains('flutter_test'));
      // Transitive deps must NOT appear in the compact view.
      expect(r.output, isNot(contains('material_color_utilities')));
      expect(r.output, isNot(contains('leak_tracker')));
      expect(r.metadata['mode'], 'direct');
    });

    test('--tree mode passes through (anti-bloat in runner)', () {
      final stdout = readFixture('pub_deps_tree.txt');
      final r = PubDepsFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const ['--tree'],
      );
      expect(r.output, contains('material_color_utilities'));
      expect(r.metadata['mode'], 'tree');
    });
  });

  group('PubDepsFilter — CommandFilter contract', () {
    test('Flutter vs pure-Dart base', () {
      expect(
        PubDepsFilter().baseNativeCommand(const []),
        ['flutter', 'pub', 'deps'],
      );
      expect(
        PubDepsFilter(isFlutterProject: false).baseNativeCommand(const []),
        ['dart', 'pub', 'deps'],
      );
    });
  });
}
