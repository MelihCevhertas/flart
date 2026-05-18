// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:path/path.dart' as p;

/// Returns the body of a fixture file, stripping the leading comment header
/// (lines starting with `#`) that `tools/generate_fixtures.sh` writes.
///
/// `dart test` runs with the package directory as the cwd, so the fixture
/// path is resolved relative to `test/fixtures/`.
String readFixture(String name) {
  final fixturePath = p.join('test', 'fixtures', name);
  final file = File(fixturePath);
  if (!file.existsSync()) {
    throw StateError(
      'Fixture not found: $fixturePath (cwd=${Directory.current.path}). '
      'Did you run tools/generate_fixtures.sh from the workspace root?',
    );
  }
  final raw = file.readAsStringSync();
  final lines = raw.split('\n');
  final firstBody = lines.indexWhere(
    (l) => !l.startsWith('#') && !l.startsWith('//'),
  );
  if (firstBody < 0) return '';
  return lines.skip(firstBody).join('\n');
}
