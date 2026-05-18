// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flart_filters/flart_filters.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fixture_helper.dart';

void main() {
  group('PubGetFilter — fixture-driven', () {
    test('clean re-run collapses to ok with 0 changed', () {
      final body = readFixture('pub_get_clean.txt');
      final r = PubGetFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('ok'));
      expect(r.output, contains('0 changed'));
      expect(r.metadata['changes'], 0);
      expect(r.metadata['failed'], isFalse);
    });

    test('fresh resolve lists 6 added packages with markers', () {
      final body = readFixture('pub_get_with_changes.txt');
      final r = PubGetFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('6 changed'));
      expect(r.output, contains('+ collection'));
      expect(r.output, contains('+ yaml'));
      // Noise lines must be gone.
      expect(r.output, isNot(contains('Resolving dependencies')));
      expect(r.output, isNot(contains('Downloading packages')));
      expect(r.metadata['changes'], 6);
      expect(r.metadata['changed_summary'], isTrue);
    });

    test('conflict preserves the full error block, exit > 0', () {
      final body = readFixture('pub_get_conflict.txt');
      final r = PubGetFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 1,
        userArgs: const [],
      );
      expect(r.output, contains('FAILED'));
      expect(r.output, contains('version solving failed'));
      expect(r.metadata['failed'], isTrue);
    });
  });

  group('PubGetFilter — dependency count from pubspec.lock', () {
    test('reads packages map length and includes it in header', () {
      final tmp = Directory.systemTemp.createTempSync('flart_pub_lock_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      File(p.join(tmp.path, 'pubspec.lock')).writeAsStringSync('''
packages:
  a:
    dependency: "direct main"
    version: "1.0.0"
  b:
    dependency: "transitive"
    version: "2.0.0"
  c:
    dependency: "direct dev"
    version: "0.5.0"
sdks:
  dart: ">=3.5.0 <4.0.0"
''');
      final r = PubGetFilter(projectRoot: tmp.path).filter(
        stdout: 'Resolving dependencies...\nGot dependencies!\n',
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('3 deps'));
      expect(r.metadata['deps_total'], 3);
    });

    test('missing pubspec.lock degrades gracefully (no deps count)', () {
      final tmp = Directory.systemTemp.createTempSync('flart_pub_nolock_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final r = PubGetFilter(projectRoot: tmp.path).filter(
        stdout: 'Resolving dependencies...\nGot dependencies!\n',
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.metadata.containsKey('deps_total'), isFalse);
      expect(r.output, isNot(contains('deps')));
    });
  });

  group('PubGetFilter — CommandFilter contract', () {
    test('default (Flutter) baseNativeCommand', () {
      expect(
        PubGetFilter().baseNativeCommand(const []),
        ['flutter', 'pub', 'get'],
      );
    });

    test('pure-Dart baseNativeCommand uses `dart pub get`', () {
      expect(
        PubGetFilter(isFlutterProject: false).baseNativeCommand(const []),
        ['dart', 'pub', 'get'],
      );
    });

    test('name/flartCommand', () {
      final f = PubGetFilter();
      expect(f.name, 'pub_get');
      expect(f.flartCommand, 'pub');
    });
  });
}
